//
//  TrustAnchorManager.swift
//  tw2023_wallet
//
//  Manages custom trust anchor certificates for X.509 chain validation.
//  Certificates are loaded from the app bundle's Resources/Certificates directory.
//

import Foundation
import Security

/// Manages custom trust anchor certificates for certificate chain validation.
/// Loads intermediate and root certificates from the app bundle to validate
/// certificate chains where x5c contains only the leaf certificate.
class TrustAnchorManager {
    static let shared = TrustAnchorManager()

    /// Custom anchor certificates (root CAs)
    private(set) var anchorCertificates: [SecCertificate] = []

    /// Intermediate certificates for chain building
    private(set) var intermediateCertificates: [SecCertificate] = []

    /// All certificates (intermediates + anchors) for chain building
    var allCertificates: [SecCertificate] {
        return intermediateCertificates + anchorCertificates
    }

    /// Whether custom certificates have been loaded
    private(set) var isLoaded: Bool = false

    /// Whether this is a disposable instance (not singleton)
    private let isDisposableInstance: Bool

    private init() {
        self.isDisposableInstance = false
        loadBuiltInCertificates()
    }

    /// Private initializer for creating disposable instances
    private init(skipAutoLoad: Bool) {
        self.isDisposableInstance = skipAutoLoad
        if !skipAutoLoad {
            loadBuiltInCertificates()
        }
        isLoaded = true
    }

    // MARK: - Factory Methods for Disposable Instances

    /// Create a disposable instance with additional certificates from trusted list.
    /// The instance inherits all certificates from the singleton plus the provided certificates.
    ///
    /// - Parameter additionalCertificates: Certificates from trusted list to add
    /// - Returns: A new TrustAnchorManager instance with combined certificates
    static func createInstance(withAdditionalCertificates additionalCertificates: [SecCertificate]) -> TrustAnchorManager {
        let instance = TrustAnchorManager(skipAutoLoad: true)

        // Copy certificates from singleton
        for cert in shared.anchorCertificates {
            instance.anchorCertificates.append(cert)
        }
        for cert in shared.intermediateCertificates {
            instance.intermediateCertificates.append(cert)
        }

        // Add additional certificates (auto-classify by self-signed check)
        for cert in additionalCertificates {
            if instance.isSelfSignedCertificate(cert) {
                instance.anchorCertificates.append(cert)
            } else {
                instance.intermediateCertificates.append(cert)
            }
        }

        let sharedAnchors = shared.anchorCertificates.count
        let sharedIntermediates = shared.intermediateCertificates.count
        let additionalAnchors = instance.anchorCertificates.count - sharedAnchors
        let additionalIntermediates = instance.intermediateCertificates.count - sharedIntermediates

        print("🔐 [TrustAnchor] ========== Created Disposable Instance ==========")
        print("🔐 [TrustAnchor] Inherited from singleton:")
        print("🔐 [TrustAnchor]   Anchors: \(sharedAnchors), Intermediates: \(sharedIntermediates)")
        print("🔐 [TrustAnchor] Added from TrustedList:")
        print("🔐 [TrustAnchor]   Anchors: \(additionalAnchors), Intermediates: \(additionalIntermediates)")
        print("🔐 [TrustAnchor] Total:")
        print("🔐 [TrustAnchor]   Anchors: \(instance.anchorCertificates.count), Intermediates: \(instance.intermediateCertificates.count)")
        print("🔐 [TrustAnchor] ====================================================")

        return instance
    }

    /// Create a disposable instance with certificates fetched from trusted list for a specific issuer.
    ///
    /// - Parameters:
    ///   - issuerURL: The issuer URL to search for in trusted lists
    ///   - serviceType: The service type to match (default: CredentialIssuance)
    /// - Returns: A new TrustAnchorManager instance with certificates for the issuer
    /// - Throws: TrustedListError if service not found or certificates unavailable
    static func createInstance(
        forIssuerURL issuerURL: String,
        serviceType: String = TrustedListServiceType.credentialIssuance
    ) async throws -> TrustAnchorManager {
        let certificates = try await TrustedListManager.shared.getCertificates(
            forIssuerURL: issuerURL,
            serviceType: serviceType
        )
        return createInstance(withAdditionalCertificates: certificates)
    }

    /// Load certificates from the app bundle's Resources/Certificates directory.
    /// Certificates are categorized by content analysis:
    /// - Self-signed certificates (Issuer == Subject) -> anchor certificates (root CAs)
    /// - Other certificates -> intermediate certificates
    func loadBuiltInCertificates() {
        print("TrustAnchorManager: ========== Loading certificates ==========")
        anchorCertificates = []
        intermediateCertificates = []

        guard let resourcePath = Bundle.main.resourcePath else {
            print("TrustAnchorManager: [ERROR] Unable to get resource path")
            isLoaded = true
            return
        }
        print("TrustAnchorManager: Resource path: \(resourcePath)")

        let certificatesPath = (resourcePath as NSString).appendingPathComponent("Certificates")
        print("TrustAnchorManager: Certificates path: \(certificatesPath)")

        let fileManager = FileManager.default

        guard fileManager.fileExists(atPath: certificatesPath) else {
            print("TrustAnchorManager: [WARN] Certificates directory not found")
            isLoaded = true
            return
        }
        print("TrustAnchorManager: Certificates directory exists")

        do {
            let files = try fileManager.contentsOfDirectory(atPath: certificatesPath)
            print("TrustAnchorManager: Found \(files.count) file(s) in directory")

            let certFiles = files.filter { $0.hasSuffix(".cer") || $0.hasSuffix(".pem") || $0.hasSuffix(".crt") }
            print("TrustAnchorManager: Found \(certFiles.count) certificate file(s): \(certFiles)")

            for file in certFiles {
                print("TrustAnchorManager: --- Processing: \(file) ---")
                let filePath = (certificatesPath as NSString).appendingPathComponent(file)

                guard let certData = fileManager.contents(atPath: filePath) else {
                    print("TrustAnchorManager:   [ERROR] Unable to read file")
                    continue
                }
                print("TrustAnchorManager:   File size: \(certData.count) bytes")

                if let certificate = createCertificate(from: certData) {
                    // Get certificate subject name for logging
                    let subjectName = SecCertificateCopySubjectSummary(certificate) as String? ?? "Unknown"
                    print("TrustAnchorManager:   Subject: \(subjectName)")

                    // Categorize by certificate content (self-signed = root CA)
                    if isSelfSignedCertificate(certificate) {
                        anchorCertificates.append(certificate)
                        print("TrustAnchorManager:   Type: ROOT CA (self-signed)")
                    } else {
                        intermediateCertificates.append(certificate)
                        print("TrustAnchorManager:   Type: INTERMEDIATE")
                    }
                } else {
                    print("TrustAnchorManager:   [ERROR] Failed to parse certificate")
                }
            }

            print("TrustAnchorManager: ========== Summary ==========")
            print("TrustAnchorManager: Root CAs (anchors): \(anchorCertificates.count)")
            for (index, cert) in anchorCertificates.enumerated() {
                let name = SecCertificateCopySubjectSummary(cert) as String? ?? "Unknown"
                print("TrustAnchorManager:   [\(index)] \(name)")
            }
            print("TrustAnchorManager: Intermediates: \(intermediateCertificates.count)")
            for (index, cert) in intermediateCertificates.enumerated() {
                let name = SecCertificateCopySubjectSummary(cert) as String? ?? "Unknown"
                print("TrustAnchorManager:   [\(index)] \(name)")
            }
            print("TrustAnchorManager: ==============================")
        } catch {
            print("TrustAnchorManager: [ERROR] Error reading certificates directory: \(error)")
        }

        isLoaded = true
    }

    /// Check if a certificate is self-signed (Issuer == Subject)
    /// Self-signed certificates are considered root CAs
    private func isSelfSignedCertificate(_ certificate: SecCertificate) -> Bool {
        guard let issuer = SecCertificateCopyNormalizedIssuerSequence(certificate),
              let subject = SecCertificateCopyNormalizedSubjectSequence(certificate) else {
            return false
        }
        return (issuer as Data) == (subject as Data)
    }

    /// Create a SecCertificate from data (supports DER and PEM formats)
    private func createCertificate(from data: Data) -> SecCertificate? {
        // Try DER format first
        if let cert = SecCertificateCreateWithData(nil, data as CFData) {
            return cert
        }

        // Try PEM format
        if let pemString = String(data: data, encoding: .utf8),
           let derData = SignatureUtil.extractDERFromPEM(pemString) {
            return SecCertificateCreateWithData(nil, derData as CFData)
        }

        return nil
    }

    /// Check if custom trust anchors are available
    var hasCustomAnchors: Bool {
        return !anchorCertificates.isEmpty
    }

    /// Reload certificates (useful for testing or dynamic updates)
    func reload() {
        isLoaded = false
        loadBuiltInCertificates()
    }

    /// Clear all loaded certificates (useful for testing)
    func clear() {
        print("TrustAnchorManager: Clearing all certificates (anchors: \(anchorCertificates.count), intermediates: \(intermediateCertificates.count))")
        anchorCertificates = []
        intermediateCertificates = []
        isLoaded = false
    }

    /// Add certificates programmatically (useful for testing)
    func addAnchorCertificate(_ certificate: SecCertificate) {
        anchorCertificates.append(certificate)
    }

    func addIntermediateCertificate(_ certificate: SecCertificate) {
        intermediateCertificates.append(certificate)
    }

    /// Add certificate from DER data (useful for testing)
    func addAnchorCertificate(derData: Data) -> Bool {
        guard let cert = SecCertificateCreateWithData(nil, derData as CFData) else {
            return false
        }
        anchorCertificates.append(cert)
        return true
    }

    func addIntermediateCertificate(derData: Data) -> Bool {
        guard let cert = SecCertificateCreateWithData(nil, derData as CFData) else {
            return false
        }
        intermediateCertificates.append(cert)
        return true
    }
}
