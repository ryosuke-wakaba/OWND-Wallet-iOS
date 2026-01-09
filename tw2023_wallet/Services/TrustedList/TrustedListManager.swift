//
//  TrustedListManager.swift
//  tw2023_wallet
//
//  Manages trusted lists (LoTE format) for certificate validation.
//  Fetches, caches, and searches trusted lists by service URL and service type.
//

import Foundation
import Security

/// Errors that can occur during trusted list operations
enum TrustedListError: Error, LocalizedError {
    case invalidURL(String)
    case fetchFailed(URL, Error)
    case parseError(Error)
    case serviceNotFound(serviceURL: String, serviceType: String)
    case noCertificatesInService
    case certificateParseError
    case noLoTEConfigured

    var errorDescription: String? {
        switch self {
        case .invalidURL(let url):
            return "Invalid URL: \(url)"
        case .fetchFailed(let url, let error):
            return "Failed to fetch trusted list from \(url): \(error.localizedDescription)"
        case .parseError(let error):
            return "Failed to parse trusted list: \(error.localizedDescription)"
        case .serviceNotFound(let serviceURL, let serviceType):
            return "Service not found for \(serviceURL) with type \(serviceType)"
        case .noCertificatesInService:
            return "No certificates found in service digital identity"
        case .certificateParseError:
            return "Failed to parse certificate from trusted list"
        case .noLoTEConfigured:
            return "No LoTE configured for search"
        }
    }
}

/// Result of a service search in trusted lists
struct TrustedServiceResult {
    let entity: TrustedEntity
    let service: TrustedEntityService
    let certificates: [SecCertificate]
}

/// Manages trusted lists (LoTE format) for certificate validation.
/// This class is responsible for fetching and searching LoTE documents.
/// The LoTE configuration (which LoTEs to use and their service types) should be
/// determined by the ViewModel layer using TrustedListConfigLoader.
class TrustedListManager {
    static let shared = TrustedListManager()

    // TODO: Implement cache with TTL based on NextUpdate field from trusted list
    /// Cached trusted list documents (currently disabled)
    // private var cachedLists: [URL: LoTEDocument] = [:]

    /// URL session for fetching
    private let urlSession: URLSession

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    // MARK: - Fetching

    /// Fetch a trusted list from URL
    /// Supports both JSON and JWT (signed) formats
    func fetchTrustedList(from url: URL) async throws -> LoTEDocument {
        // TODO: Re-enable cache with TTL based on NextUpdate
        // if let cached = cachedLists[url] {
        //     print("🔐 [TrustedList] Using cached list for \(url)")
        //     return cached
        // }

        print("🔐 [TrustedList] ========== Fetching Trusted List ==========")
        print("🔐 [TrustedList] URL: \(url)")

        let (data, response) = try await urlSession.data(from: url)

        if let httpResponse = response as? HTTPURLResponse {
            guard (200...299).contains(httpResponse.statusCode) else {
                throw TrustedListError.fetchFailed(url, NSError(
                    domain: "HTTP",
                    code: httpResponse.statusCode,
                    userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"]
                ))
            }
        }

        // Check if response is JWT format (starts with "eyJ" which is base64 for '{"')
        let jsonData: Data
        if let responseString = String(data: data, encoding: .utf8),
           responseString.hasPrefix("eyJ") {
            print("🔐 [TrustedList] Detected JWT format, extracting payload...")
            jsonData = try extractPayloadFromJWT(responseString)
        } else {
            jsonData = data
        }

        do {
            let document = try JSONDecoder().decode(LoTEDocument.self, from: jsonData)
            // TODO: Re-enable cache with TTL based on NextUpdate
            // cachedLists[url] = document
            print("🔐 [TrustedList] ✅ Successfully parsed trusted list")
            print("🔐 [TrustedList]   Scheme: \(document.LoTE.ListAndSchemeInformation.SchemeOperatorName.first?.value ?? "Unknown")")
            print("🔐 [TrustedList]   Entities: \(document.LoTE.TrustedEntitiesList.count)")
            print("🔐 [TrustedList] ==============================================")
            return document
        } catch {
            print("🔐 [TrustedList] ❌ Failed to parse: \(error)")
            throw TrustedListError.parseError(error)
        }
    }

    /// Extract payload data from a JWT string
    private func extractPayloadFromJWT(_ jwt: String) throws -> Data {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else {
            throw TrustedListError.parseError(NSError(
                domain: "TrustedList",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid JWT format"]
            ))
        }

        // JWT payload is the second part (index 1)
        var base64Payload = String(parts[1])

        // Add padding if needed for base64 decoding
        let remainder = base64Payload.count % 4
        if remainder > 0 {
            base64Payload += String(repeating: "=", count: 4 - remainder)
        }

        // Convert from base64url to base64
        base64Payload = base64Payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let payloadData = Data(base64Encoded: base64Payload) else {
            throw TrustedListError.parseError(NSError(
                domain: "TrustedList",
                code: -1,
                userInfo: [NSLocalizedDescriptionKey: "Failed to decode JWT payload"]
            ))
        }

        print("🔐 [TrustedList] ✓ JWT payload extracted successfully")
        return payloadData
    }

    // MARK: - Service Search

    /// Find a service matching the service URL using specified LoTE search infos
    /// - Parameters:
    ///   - serviceURL: The service URL to search for
    ///   - loteInfos: Array of LoTE search infos specifying which LoTEs to search and optional service type filter
    /// - Returns: TrustedServiceResult if found
    /// - Throws: TrustedListError.noLoTEConfigured if loteInfos is empty
    func findService(
        serviceURL: String,
        loteInfos: [LoTESearchInfo]
    ) async throws -> TrustedServiceResult {
        guard !loteInfos.isEmpty else {
            print("🔐 [TrustedList] ❌ No LoTE configured for search")
            throw TrustedListError.noLoTEConfigured
        }

        print("🔐 [TrustedList] ========== Searching Service ==========")
        print("🔐 [TrustedList] Service URL: \(serviceURL)")
        print("🔐 [TrustedList] LoTE count: \(loteInfos.count)")

        for loteInfo in loteInfos {
            print("🔐 [TrustedList] Searching in: \(loteInfo.url)")
            if let serviceType = loteInfo.serviceType {
                print("🔐 [TrustedList]   Service Type filter: \(serviceType)")
            } else {
                print("🔐 [TrustedList]   Service Type filter: (none)")
            }

            do {
                let document = try await fetchTrustedList(from: loteInfo.url)
                if let result = searchInDocument(
                    document,
                    serviceURL: serviceURL,
                    serviceType: loteInfo.serviceType
                ) {
                    print("🔐 [TrustedList] ✅ Found matching service!")
                    print("🔐 [TrustedList]   Entity: \(result.entity.TrustedEntityInformation.TEName.first?.value ?? "Unknown")")
                    print("🔐 [TrustedList]   Service: \(result.service.ServiceInformation.ServiceName.first?.value ?? "Unknown")")
                    print("🔐 [TrustedList]   Certificates: \(result.certificates.count)")
                    print("🔐 [TrustedList] ============================================")
                    return result
                }
            } catch {
                print("🔐 [TrustedList] ⚠️ Error searching in \(loteInfo.url): \(error)")
            }
        }

        let serviceTypeDesc = loteInfos.first?.serviceType ?? "(any)"
        print("🔐 [TrustedList] ❌ Service not found: \(serviceURL)")
        print("🔐 [TrustedList] ============================================")
        throw TrustedListError.serviceNotFound(serviceURL: serviceURL, serviceType: serviceTypeDesc)
    }

    /// Find a service in a specific trusted list document
    func findService(
        in document: LoTEDocument,
        serviceURL: String,
        serviceType: String? = nil
    ) throws -> TrustedServiceResult {
        if let result = searchInDocument(document, serviceURL: serviceURL, serviceType: serviceType) {
            return result
        }
        throw TrustedListError.serviceNotFound(serviceURL: serviceURL, serviceType: serviceType ?? "(any)")
    }

    /// Search for a matching service in a document
    /// - Parameters:
    ///   - document: The LoTE document to search in
    ///   - serviceURL: The service URL to find
    ///   - serviceType: Optional service type filter. If nil, matches any service type.
    private func searchInDocument(
        _ document: LoTEDocument,
        serviceURL: String,
        serviceType: String?
    ) -> TrustedServiceResult? {
        let normalizedServiceURL = normalizeURL(serviceURL)

        for entity in document.LoTE.TrustedEntitiesList {
            for service in entity.TrustedEntityServices {
                let info = service.ServiceInformation

                // Filter by service type if specified
                if let requiredType = serviceType {
                    guard info.ServiceTypeIdentifier == requiredType else {
                        continue
                    }
                }

                // Check service status (must be granted)
                guard info.ServiceStatus == TrustedListServiceStatus.granted else {
                    continue
                }

                // Check ServiceSupplyPoints contains the service URL
                if let supplyPoints = info.ServiceSupplyPoints {
                    for point in supplyPoints {
                        let normalizedPoint = normalizeURL(point.uriValue)
                        if normalizedPoint == normalizedServiceURL {
                            // Found matching service, extract certificates
                            if let certificates = extractCertificates(from: info.ServiceDigitalIdentity) {
                                return TrustedServiceResult(
                                    entity: entity,
                                    service: service,
                                    certificates: certificates
                                )
                            }
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Normalize URL for comparison (remove trailing slash)
    private func normalizeURL(_ url: String) -> String {
        var normalized = url.trimmingCharacters(in: .whitespaces)
        if normalized.hasSuffix("/") {
            normalized = String(normalized.dropLast())
        }
        return normalized.lowercased()
    }

    // MARK: - Certificate Extraction

    /// Extract SecCertificate array from ServiceDigitalIdentity
    private func extractCertificates(from identity: ServiceDigitalIdentity) -> [SecCertificate]? {
        guard let pemCertificates = identity.X509Certificates, !pemCertificates.isEmpty else {
            return nil
        }

        var certificates: [SecCertificate] = []

        for pem in pemCertificates {
            if let cert = createCertificate(from: pem) {
                certificates.append(cert)
            } else {
                print("TrustedListManager: [WARN] Failed to parse certificate")
            }
        }

        return certificates.isEmpty ? nil : certificates
    }

    /// Create SecCertificate from PEM string
    private func createCertificate(from pem: String) -> SecCertificate? {
        guard let derData = SignatureUtil.extractDERFromPEM(pem) else {
            return nil
        }
        return SecCertificateCreateWithData(nil, derData as CFData)
    }

    // MARK: - Convenience Methods

    /// Get certificates for a service URL from trusted lists
    /// - Parameters:
    ///   - serviceURL: The service URL to get certificates for
    ///   - loteInfos: Array of LoTE search infos specifying which LoTEs to search
    func getCertificates(
        forServiceURL serviceURL: String,
        loteInfos: [LoTESearchInfo]
    ) async throws -> [SecCertificate] {
        let result = try await findService(serviceURL: serviceURL, loteInfos: loteInfos)
        return result.certificates
    }
}
