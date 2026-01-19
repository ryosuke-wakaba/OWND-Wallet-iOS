//
//  TrustedListManager.swift
//  tw2023_wallet
//
//  Manages trusted lists (LoTE format) for certificate validation.
//  Fetches, caches, and searches trusted lists by service URL and service type.
//

import Foundation
import Security
import X509

/// Errors that can occur during trusted list operations
enum TrustedListError: Error, LocalizedError {
    case invalidURL(String)
    case fetchFailed(URL, Error)
    case parseError(Error)
    case serviceNotFound(serviceURL: String, serviceType: String)
    case issuerCertificateNotFound(leafSubject: String)
    case noCertificatesInService
    case certificateParseError
    case noLoTEConfigured
    case signatureVerificationFailed(JAdESSignatureVerifier.JAdESVerificationError)
    case conditionNotMatched(context: String)

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
        case .issuerCertificateNotFound(let leafSubject):
            return "Issuer certificate not found for leaf: \(leafSubject)"
        case .noCertificatesInService:
            return "No certificates found in service digital identity"
        case .certificateParseError:
            return "Failed to parse certificate from trusted list"
        case .noLoTEConfigured:
            return "No LoTE configured for search"
        case .signatureVerificationFailed(let jadesError):
            return "Trusted list signature verification failed: \(jadesError.localizedDescription)"
        case .conditionNotMatched(let context):
            return "No service matched condition for context: \(context)"
        }
    }
}

/// Result of a service search in trusted lists
struct TrustedServiceResult {
    let entity: TrustedEntity
    let service: TrustedEntityService
    let certificates: [SecCertificate]
}

/// Result of certificate-based issuer search
struct IssuerCertificateResult {
    let entity: TrustedEntity
    let service: TrustedEntityService
    let issuerCertificate: Certificate
    let issuerSecCertificate: SecCertificate
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
            print("🔐 [TrustedList] Detected JWT format, verifying JAdES signature...")

            // Verify JAdES signature
            let verificationResult = JAdESSignatureVerifier.verifyJAdES(
                jwt: responseString,
                options: .default
            )

            switch verificationResult {
            case .success(let result):
                print("🔐 [TrustedList] ✓ JAdES signature verified")
                print("🔐 [TrustedList]   Signing time: \(result.signingTime)")
                print("🔐 [TrustedList]   Certificate thumbprint: \(result.certificateThumbprint)")
                jsonData = result.payload

            case .failure(let error):
                print("🔐 [TrustedList] ❌ JAdES verification failed: \(error.localizedDescription)")
                throw TrustedListError.signatureVerificationFailed(error)
            }
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
        guard let derData = X509CertificateOperations.extractDERFromPEM(pem) else {
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

    // MARK: - Certificate-Based Search (New API)

    /// Find issuer certificate for a leaf certificate using AKI/SKI or DN matching
    /// - Parameters:
    ///   - leafCertificate: The leaf certificate to find issuer for
    ///   - searchInfos: Array of context-based search infos
    /// - Returns: IssuerCertificateResult if found
    /// - Throws: TrustedListError if not found or error occurs
    func findIssuerCertificate(
        for leafCertificate: Certificate,
        searchInfos: [LoTEContextSearchInfo]
    ) async throws -> IssuerCertificateResult {
        guard !searchInfos.isEmpty else {
            print("🔐 [TrustedList] ❌ No LoTE context configured for search")
            throw TrustedListError.noLoTEConfigured
        }

        let leafSubject = X509CertificateOperations.extractSubjectDN(from: leafCertificate)
        let leafAKI = X509CertificateOperations.extractAuthorityKeyIdentifier(from: leafCertificate)
        let leafIssuerDN = X509CertificateOperations.extractIssuerDN(from: leafCertificate)

        print("🔐 [TrustedList] ========== Finding Issuer Certificate ==========")
        print("🔐 [TrustedList] Leaf Subject: \(leafSubject)")
        print("🔐 [TrustedList] Leaf AKI: \(leafAKI ?? "(none)")")
        print("🔐 [TrustedList] Leaf Issuer DN: \(leafIssuerDN)")
        print("🔐 [TrustedList] Search contexts: \(searchInfos.count)")

        for searchInfo in searchInfos {
            print("🔐 [TrustedList] Searching in: \(searchInfo.url)")
            print("🔐 [TrustedList]   Context: \(searchInfo.contextName)")

            do {
                let document = try await fetchTrustedList(from: searchInfo.url)

                // Check LoTEType condition
                if let requiredLoTEType = searchInfo.condition.loteType {
                    let actualLoTEType = document.LoTE.ListAndSchemeInformation.LoTEType
                    if actualLoTEType != requiredLoTEType {
                        print("🔐 [TrustedList]   ⚠️ LoTEType mismatch: expected \(requiredLoTEType), got \(actualLoTEType ?? "(none)")")
                        continue
                    }
                    print("🔐 [TrustedList]   ✓ LoTEType matched: \(requiredLoTEType)")
                }

                // Search for issuer certificate
                if let result = searchForIssuerInDocument(
                    document,
                    leafCertificate: leafCertificate,
                    leafAKI: leafAKI,
                    condition: searchInfo.condition
                ) {
                    print("🔐 [TrustedList] ✅ Found issuer certificate!")
                    print("🔐 [TrustedList]   Entity: \(result.entity.TrustedEntityInformation.TEName.first?.value ?? "Unknown")")
                    print("🔐 [TrustedList]   Service: \(result.service.ServiceInformation.ServiceName.first?.value ?? "Unknown")")
                    print("🔐 [TrustedList] ================================================")
                    return result
                }
            } catch {
                print("🔐 [TrustedList] ⚠️ Error searching in \(searchInfo.url): \(error)")
            }
        }

        print("🔐 [TrustedList] ❌ Issuer certificate not found")
        print("🔐 [TrustedList] ================================================")
        throw TrustedListError.issuerCertificateNotFound(leafSubject: leafSubject)
    }

    /// Search for issuer certificate in a document using AKI/SKI or DN matching
    private func searchForIssuerInDocument(
        _ document: LoTEDocument,
        leafCertificate: Certificate,
        leafAKI: String?,
        condition: LoTEContextSearchInfo.SearchCondition
    ) -> IssuerCertificateResult? {
        for entity in document.LoTE.TrustedEntitiesList {
            for service in entity.TrustedEntityServices {
                let info = service.ServiceInformation

                // Check serviceTypeIdentifier condition
                if let requiredType = condition.serviceTypeIdentifier {
                    guard info.ServiceTypeIdentifier == requiredType else {
                        continue
                    }
                }

                // Check status condition
                if let requiredStatus = condition.status {
                    guard info.ServiceStatus == requiredStatus else {
                        continue
                    }
                }

                // Get certificates from service
                guard let pemCertificates = info.ServiceDigitalIdentity.X509Certificates,
                      !pemCertificates.isEmpty else {
                    continue
                }

                // Try to find matching issuer certificate
                for pem in pemCertificates {
                    // Convert to X509.Certificate for AKI/SKI comparison
                    guard let x509Cert = convertPEMToX509Certificate(pem) else {
                        continue
                    }

                    // Try AKI/SKI matching first
                    if let aki = leafAKI {
                        let ski = X509CertificateOperations.extractSubjectKeyIdentifier(from: x509Cert)
                        if let ski = ski, ski == aki {
                            if let secCert = createCertificate(from: pem) {
                                print("🔐 [TrustedList]   ✓ Found by AKI/SKI match")
                                return IssuerCertificateResult(
                                    entity: entity,
                                    service: service,
                                    issuerCertificate: x509Cert,
                                    issuerSecCertificate: secCert
                                )
                            }
                        }
                    }

                    // Fallback: DN matching
                    if X509CertificateOperations.doesIssuerMatchSubject(
                        leafCertificate: leafCertificate,
                        issuerCertificate: x509Cert
                    ) {
                        if let secCert = createCertificate(from: pem) {
                            print("🔐 [TrustedList]   ✓ Found by DN match")
                            return IssuerCertificateResult(
                                entity: entity,
                                service: service,
                                issuerCertificate: x509Cert,
                                issuerSecCertificate: secCert
                            )
                        }
                    }
                }
            }
        }

        return nil
    }

    /// Convert PEM string to X509.Certificate
    private func convertPEMToX509Certificate(_ pem: String) -> Certificate? {
        // Check if PEM has delimiters
        if pem.contains("-----BEGIN CERTIFICATE-----") {
            return try? Certificate(pemEncoded: pem)
        } else {
            // Assume base64-encoded DER
            guard let derData = Data(base64Encoded: pem, options: .ignoreUnknownCharacters) else {
                return nil
            }
            return try? Certificate(derEncoded: Array(derData))
        }
    }

    // MARK: - Convenience Methods for Certificate-Based Search

    /// Get issuer certificates for a leaf certificate from trusted lists
    /// - Parameters:
    ///   - leafCertificate: The leaf certificate to find issuers for
    ///   - searchInfos: Array of context-based search infos
    /// - Returns: Array of issuer SecCertificates
    func getIssuerCertificates(
        for leafCertificate: Certificate,
        searchInfos: [LoTEContextSearchInfo]
    ) async throws -> [SecCertificate] {
        let result = try await findIssuerCertificate(for: leafCertificate, searchInfos: searchInfos)
        return [result.issuerSecCertificate]
    }

    /// Get issuer certificates for certificates in x5c chain from trusted lists
    /// Uses AKI/SKI or DN matching to find issuer certificates
    /// - Parameters:
    ///   - x5cCertificates: Certificate chain from JWT x5c header
    ///   - searchInfos: Array of context-based search infos
    /// - Returns: Array of issuer SecCertificates to append to chain
    func getIssuerCertificatesForChain(
        x5cCertificates: [Certificate],
        searchInfos: [LoTEContextSearchInfo]
    ) async throws -> [SecCertificate] {
        guard let leafCertificate = x5cCertificates.first else {
            throw TrustedListError.noCertificatesInService
        }

        // If x5c has multiple certificates, use the last one (end of provided chain)
        // Otherwise use the leaf certificate
        let certificateToMatch = x5cCertificates.last ?? leafCertificate

        let result = try await findIssuerCertificate(for: certificateToMatch, searchInfos: searchInfos)
        return [result.issuerSecCertificate]
    }
}
