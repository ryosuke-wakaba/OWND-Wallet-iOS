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

/// Result of certificate-based issuer search
struct IssuerCertificateResult {
    let entity: TrustedEntity
    let service: TrustedEntityService
    let issuerCertificates: [Certificate]
    let issuerSecCertificates: [SecCertificate]
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

    // MARK: - Certificate-Based Search

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
                    print("🔐 [TrustedList] ✅ Found issuer certificate(s)!")
                    print("🔐 [TrustedList]   Entity: \(result.entity.TrustedEntityInformation.TEName.first?.value ?? "Unknown")")
                    print("🔐 [TrustedList]   Service: \(result.service.ServiceInformation.ServiceName.first?.value ?? "Unknown")")
                    print("🔐 [TrustedList]   Certificates: \(result.issuerSecCertificates.count)")
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
        print("🔐 [TrustedList]   Condition: serviceTypeIdentifier=\(condition.serviceTypeIdentifier ?? "(any)"), status=\(condition.status ?? "(any)")")

        for entity in document.LoTE.TrustedEntitiesList {
            let entityName = entity.TrustedEntityInformation.TEName.first?.value ?? "Unknown"
            for service in entity.TrustedEntityServices {
                let info = service.ServiceInformation
                let serviceName = info.ServiceName.first?.value ?? "Unknown"

                // Check serviceTypeIdentifier condition
                if let requiredType = condition.serviceTypeIdentifier {
                    guard info.ServiceTypeIdentifier == requiredType else {
                        print("🔐 [TrustedList]   ⚠️ ServiceType mismatch for \(entityName)/\(serviceName): expected \(requiredType), got \(info.ServiceTypeIdentifier)")
                        continue
                    }
                    print("🔐 [TrustedList]   ✓ ServiceType matched: \(requiredType)")
                }

                // Check status condition
                if let requiredStatus = condition.status {
                    guard info.ServiceStatus == requiredStatus else {
                        print("🔐 [TrustedList]   ⚠️ Status mismatch for \(entityName)/\(serviceName): expected \(requiredStatus), got \(info.ServiceStatus)")
                        continue
                    }
                    print("🔐 [TrustedList]   ✓ Status matched: \(requiredStatus)")
                }

                // Get certificates from service
                guard let pemCertificates = info.ServiceDigitalIdentity.X509Certificates,
                      !pemCertificates.isEmpty else {
                    print("🔐 [TrustedList]   ⚠️ No certificates in service \(entityName)/\(serviceName)")
                    continue
                }

                print("🔐 [TrustedList]   Checking \(pemCertificates.count) certificate(s) in \(entityName)/\(serviceName)")

                // First, parse all certificates in this service
                var allX509Certs: [Certificate] = []
                var allSecCerts: [SecCertificate] = []
                for (index, pem) in pemCertificates.enumerated() {
                    if let x509Cert = convertPEMToX509Certificate(pem),
                       let secCert = createCertificate(from: pem) {
                        allX509Certs.append(x509Cert)
                        allSecCerts.append(secCert)
                    } else {
                        print("🔐 [TrustedList]   ⚠️ Failed to parse certificate[\(index)]")
                    }
                }

                // Try to find matching issuer certificate
                var foundMatch = false
                for (index, x509Cert) in allX509Certs.enumerated() {
                    let certSubject = X509CertificateOperations.extractSubjectDN(from: x509Cert)
                    let certSKI = X509CertificateOperations.extractSubjectKeyIdentifier(from: x509Cert)
                    print("🔐 [TrustedList]   Certificate[\(index)] Subject: \(certSubject)")
                    print("🔐 [TrustedList]   Certificate[\(index)] SKI: \(certSKI ?? "(none)")")

                    // Try AKI/SKI matching first
                    if let aki = leafAKI {
                        if let ski = certSKI, ski == aki {
                            print("🔐 [TrustedList]   ✓ Found by AKI/SKI match at index \(index)")
                            foundMatch = true
                            break
                        } else {
                            print("🔐 [TrustedList]   ⚠️ AKI/SKI mismatch: leaf AKI=\(aki), cert SKI=\(certSKI ?? "(none)")")
                        }
                    }

                    // Fallback: DN matching
                    let leafIssuerDN = X509CertificateOperations.extractIssuerDN(from: leafCertificate)
                    if X509CertificateOperations.doesIssuerMatchSubject(
                        leafCertificate: leafCertificate,
                        issuerCertificate: x509Cert
                    ) {
                        print("🔐 [TrustedList]   ✓ Found by DN match at index \(index)")
                        foundMatch = true
                        break
                    } else {
                        print("🔐 [TrustedList]   ⚠️ DN mismatch: leaf issuer=\(leafIssuerDN), cert subject=\(certSubject)")
                    }
                }

                // If a match was found, return ALL certificates from this service
                if foundMatch {
                    print("🔐 [TrustedList]   Returning all \(allSecCerts.count) certificate(s) from this service")
                    return IssuerCertificateResult(
                        entity: entity,
                        service: service,
                        issuerCertificates: allX509Certs,
                        issuerSecCertificates: allSecCerts
                    )
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
        return result.issuerSecCertificates
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
        return result.issuerSecCertificates
    }
}

