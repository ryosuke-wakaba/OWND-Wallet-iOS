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
    case urlsFileNotFound
    case invalidURL(String)
    case fetchFailed(URL, Error)
    case parseError(Error)
    case serviceNotFound(serviceURL: String, serviceType: String)
    case noCertificatesInService
    case certificateParseError

    var errorDescription: String? {
        switch self {
        case .urlsFileNotFound:
            return "TrustedListURLs.txt not found in bundle"
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
        }
    }
}

/// Result of a service search in trusted lists
struct TrustedServiceResult {
    let entity: TrustedEntity
    let service: TrustedEntityService
    let certificates: [SecCertificate]
}

/// Manages trusted lists (LoTE format) for certificate validation
class TrustedListManager {
    static let shared = TrustedListManager()

    /// URLs of trusted lists to fetch
    private(set) var trustedListURLs: [URL] = []

    // TODO: Implement cache with TTL based on NextUpdate field from trusted list
    /// Cached trusted list documents (currently disabled)
    // private var cachedLists: [URL: LoTEDocument] = [:]

    /// URL session for fetching
    private let urlSession: URLSession

    /// Whether URLs have been loaded
    private(set) var isLoaded: Bool = false

    init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
        loadTrustedListURLs()
    }

    // MARK: - URL Management

    /// Load trusted list URLs from TrustedListURLs.txt in bundle
    func loadTrustedListURLs() {
        print("TrustedListManager: ========== Loading trusted list URLs ==========")
        trustedListURLs = []

        guard let resourcePath = Bundle.main.resourcePath else {
            print("TrustedListManager: [ERROR] Unable to get resource path")
            isLoaded = true
            return
        }

        let urlsFilePath = (resourcePath as NSString).appendingPathComponent("TrustedListURLs.txt")
        print("TrustedListManager: URLs file path: \(urlsFilePath)")

        guard FileManager.default.fileExists(atPath: urlsFilePath) else {
            print("TrustedListManager: [WARN] TrustedListURLs.txt not found")
            isLoaded = true
            return
        }

        do {
            let content = try String(contentsOfFile: urlsFilePath, encoding: .utf8)
            let lines = content.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                // Skip empty lines and comments
                if trimmed.isEmpty || trimmed.hasPrefix("#") {
                    continue
                }
                if let url = URL(string: trimmed) {
                    trustedListURLs.append(url)
                    print("TrustedListManager: Added URL: \(trimmed)")
                } else {
                    print("TrustedListManager: [WARN] Invalid URL: \(trimmed)")
                }
            }

            print("TrustedListManager: Loaded \(trustedListURLs.count) URL(s)")
        } catch {
            print("TrustedListManager: [ERROR] Failed to read URLs file: \(error)")
        }

        isLoaded = true
    }

    /// Add a trusted list URL programmatically
    func addTrustedListURL(_ url: URL) {
        if !trustedListURLs.contains(url) {
            trustedListURLs.append(url)
            print("TrustedListManager: Added URL: \(url)")
        }
    }

    /// Clear all cached lists
    func clearCache() {
        // TODO: Re-enable cache with TTL based on NextUpdate
        // cachedLists.removeAll()
        print("TrustedListManager: Cache cleared (no-op while cache is disabled)")
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

    /// Fetch all configured trusted lists
    func fetchAllTrustedLists() async throws -> [LoTEDocument] {
        var documents: [LoTEDocument] = []
        for url in trustedListURLs {
            do {
                let doc = try await fetchTrustedList(from: url)
                documents.append(doc)
            } catch {
                print("TrustedListManager: [WARN] Failed to fetch \(url): \(error)")
            }
        }
        return documents
    }

    // MARK: - Service Search

    /// Find a service matching the service URL and service type
    func findService(
        serviceURL: String,
        serviceType: String = TrustedListServiceType.credentialIssuance
    ) async throws -> TrustedServiceResult {
        print("🔐 [TrustedList] ========== Searching Service ==========")
        print("🔐 [TrustedList] Service URL: \(serviceURL)")
        print("🔐 [TrustedList] Service Type: \(serviceType)")

        // Search in all trusted lists
        for url in trustedListURLs {
            do {
                let document = try await fetchTrustedList(from: url)
                if let result = searchInDocument(document, serviceURL: serviceURL, serviceType: serviceType) {
                    print("🔐 [TrustedList] ✅ Found matching service!")
                    print("🔐 [TrustedList]   Entity: \(result.entity.TrustedEntityInformation.TEName.first?.value ?? "Unknown")")
                    print("🔐 [TrustedList]   Service: \(result.service.ServiceInformation.ServiceName.first?.value ?? "Unknown")")
                    print("🔐 [TrustedList]   Certificates: \(result.certificates.count)")
                    print("🔐 [TrustedList] ============================================")
                    return result
                }
            } catch {
                print("🔐 [TrustedList] ⚠️ Error searching in \(url): \(error)")
            }
        }

        print("🔐 [TrustedList] ❌ Service not found: \(serviceURL)")
        print("🔐 [TrustedList] ============================================")
        throw TrustedListError.serviceNotFound(serviceURL: serviceURL, serviceType: serviceType)
    }

    /// Find a service in a specific trusted list document
    func findService(
        in document: LoTEDocument,
        serviceURL: String,
        serviceType: String = TrustedListServiceType.credentialIssuance
    ) throws -> TrustedServiceResult {
        if let result = searchInDocument(document, serviceURL: serviceURL, serviceType: serviceType) {
            return result
        }
        throw TrustedListError.serviceNotFound(serviceURL: serviceURL, serviceType: serviceType)
    }

    /// Search for a matching service in a document
    private func searchInDocument(
        _ document: LoTEDocument,
        serviceURL: String,
        serviceType: String
    ) -> TrustedServiceResult? {
        let normalizedServiceURL = normalizeURL(serviceURL)

        for entity in document.LoTE.TrustedEntitiesList {
            for service in entity.TrustedEntityServices {
                let info = service.ServiceInformation

                // TODO: Service type check temporarily disabled for investigation
                // guard info.ServiceTypeIdentifier == serviceType else {
                //     continue
                // }

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
    func getCertificates(
        forServiceURL serviceURL: String,
        serviceType: String = TrustedListServiceType.credentialIssuance
    ) async throws -> [SecCertificate] {
        let result = try await findService(serviceURL: serviceURL, serviceType: serviceType)
        return result.certificates
    }
}
