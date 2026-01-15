//
//  X509CertificateOperations.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2023/12/28.
//

import ASN1Decoder
import CommonCrypto
import Crypto
import CryptoKit  // for P-256 not secp256k1
import Foundation
import SwiftASN1
import Web3Core
import X509

struct ECPrivateJwk {
    let kty: String
    let crv: String
    let x: String
    let y: String
    let d: String
}

extension String {
    func base64UrlDecoded() -> Data? {
        var base64 = replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Paddingが必要な場合、追加
        let length = Double(base64.lengthOfBytes(using: .utf8))
        let requiredLength = 4 * ceil(length / 4.0)
        let paddingLength = requiredLength - length
        if paddingLength > 0 {
            let padding = "".padding(toLength: Int(paddingLength), withPad: "=", startingAt: 0)
            base64 += padding
        }

        return Data(base64Encoded: base64)
    }
}

enum X509CertificateError: LocalizedError, Equatable {
    case KeyConversionError
    case X509CertificateConversionError
    case invalidX5cFormat

    var errorDescription: String? {
        switch self {
        case .KeyConversionError:
            return "Failed to convert key"
        case .X509CertificateConversionError:
            return "Failed to convert X.509 certificate"
        case .invalidX5cFormat:
            return "Invalid x5c format in JWT: certificates must be separate array elements, not comma-separated. Please contact the service provider."
        }
    }
}

/// 証明書チェーン検証エラー
enum CertificateValidationError: LocalizedError {
    case trustCreationFailed
    case anchorSettingFailed
    case untrustedRoot(certificateName: String)
    case certificateExpired(certificateName: String)
    case certificateRevoked(certificateName: String)
    case certificateNotYetValid(certificateName: String)
    case invalidCertificate(certificateName: String, reason: String)
    case chainIncomplete
    case unknownError(description: String)

    var errorDescription: String? {
        switch self {
        case .trustCreationFailed:
            return "証明書の検証準備に失敗しました"
        case .anchorSettingFailed:
            return "信頼アンカーの設定に失敗しました"
        case .untrustedRoot(let name):
            return "証明書「\(name)」のルートCAは信頼されていません"
        case .certificateExpired(let name):
            return "証明書「\(name)」の有効期限が切れています"
        case .certificateRevoked(let name):
            return "証明書「\(name)」は失効しています"
        case .certificateNotYetValid(let name):
            return "証明書「\(name)」はまだ有効ではありません"
        case .invalidCertificate(let name, let reason):
            return "証明書「\(name)」が無効です: \(reason)"
        case .chainIncomplete:
            return "証明書チェーンが不完全です"
        case .unknownError(let description):
            return "証明書検証エラー: \(description)"
        }
    }
}

let x509CertPreamble = "-----BEGIN CERTIFICATE-----\n"
let x509CertPostamble = "\n-----END CERTIFICATE-----"

enum X509CertificateOperations {
    static func addPrePostAmble(base64str: String) -> String {
        return x509CertPreamble + base64str + x509CertPostamble
    }

    static func toJwkThumbprint(jwk: ECPublicJwk) -> String? {
        let objectMapper = JSONEncoder()
        objectMapper.outputFormatting = .sortedKeys
        guard let jsonData = try? objectMapper.encode(jwk) else {
            return nil
        }

        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }

        guard let sortedData = jsonString.data(using: .utf8) else {
            return nil
        }

        var hashedBytes = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        sortedData.withUnsafeBytes { (buffer: UnsafeRawBufferPointer) in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hashedBytes)
        }

        let hashedData = Data(bytes: hashedBytes, count: Int(CC_SHA256_DIGEST_LENGTH))
        return hashedData.base64URLEncodedString()
    }

    static func generateECKeyPair(jwk: ECPrivateJwk) throws -> (Data, Data) {
        // ------------------------------------------------------
        // jwk は　crvがsecp256k1 であることを前提としている.
        // HD walletで生成されたid_token使用目的の鍵のみが入力される想定であるため
        // TODO: 別のcrvにも対応する
        assert(jwk.crv == "secp256k1")
        // -------------------------------------------------------

        guard let d = jwk.d.base64UrlDecoded(),
            let publicKey = SECP256K1.privateToPublic(privateKey: d)
        else {
            throw X509CertificateError.KeyConversionError
        }
        return (d, publicKey)
    }

    static func certificateToPem(certificate: Certificate, withDelimiters: Bool = true) -> String {
        var serializer = DER.Serializer()
        try! serializer.serialize(certificate)

        let certInBase64 = Data(serializer.serializedBytes).base64EncodedString()
        if withDelimiters {
            return addPrePostAmble(base64str: certInBase64)
        }
        else {
            return certInBase64
        }
    }

    static func generateCertificate(
        subjectPublicKey: P256.Signing.PublicKey, issuerPrivateKey: P256.Signing.PrivateKey,
        isCa: Bool
    ) -> Certificate {
        // subjectは VC のIssuerであることを想定している。
        // そのためHAIPに則り、P-256の鍵であることを想定する。
        // TODO: `CertificateUtil` に移動するのが適当
        // TODO: subject dn と　issuer dn を一致させるならば、鍵も一致していないとおかしい

        let publicKey = Certificate.PublicKey(subjectPublicKey)
        let privateKey = Certificate.PrivateKey(issuerPrivateKey)

        let subjectName = try! DistinguishedName {
            CommonName("Common Name")
            OrganizationName("Organization Name")
            LocalityName("Locality Name")
            StateOrProvinceName("State or Province Name")
            CountryName("JP")
        }
        let issuerName = subjectName
        let now = Date()

        let extensions = try! Certificate.Extensions {
            Critical(
                isCa
                    ? BasicConstraints.isCertificateAuthority(maxPathLength: nil)
                    : BasicConstraints.notCertificateAuthority
            )
            Critical(
                KeyUsage(keyCertSign: true)
            )
            SubjectAlternativeNames([.dnsName("localhost")])
        }

        let certificate = try! Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: publicKey,
            notValidBefore: now,
            notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365),
            issuer: issuerName,
            subject: subjectName,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions,
            issuerPrivateKey: privateKey
        )

        return certificate
    }

    static func generateSelfSignedCertificate(issuerPrivateKey: P256.Signing.PrivateKey)
        -> Certificate
    {
        return generateCertificate(
            subjectPublicKey: issuerPrivateKey.publicKey, issuerPrivateKey: issuerPrivateKey,
            isCa: true)
    }

    static func base64strToPem(base64str: String) -> String? {
        // RFC 7515: x5c certificates are standard base64-encoded (not base64url)
        // Use ignoreUnknownCharacters to handle whitespace, newlines, and padding issues
        guard let raw = Data(base64Encoded: base64str, options: .ignoreUnknownCharacters) else {
            return nil
        }
        let encoded = raw.base64EncodedString()

        var content = ""
        for (i, char) in encoded.enumerated() {
            if i % 64 == 0, i != 0 {
                content += "\n"
            }
            content.append(char)
        }

        let pem = addPrePostAmble(base64str: content)
        return pem
    }

    /// Extract DER data from PEM-encoded certificate string.
    /// This function parses PEM format and extracts the base64-encoded DER data.
    ///
    /// - Parameter pem: PEM-encoded certificate string with BEGIN/END markers
    /// - Returns: DER-encoded certificate data, or nil if parsing fails
    static func extractDERFromPEM(_ pem: String) -> Data? {
        let beginMarker = "-----BEGIN CERTIFICATE-----"
        let endMarker = "-----END CERTIFICATE-----"

        guard let beginRange = pem.range(of: beginMarker),
              let endRange = pem.range(of: endMarker) else {
            return nil
        }

        let base64String = pem[beginRange.upperBound..<endRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")

        return Data(base64Encoded: base64String)
    }

    static func decodeBase64ToX509Certificate(base64str: String) throws -> Certificate {
        // RFC 7515: x5c certificates are standard base64-encoded (not base64url)
        // Use ignoreUnknownCharacters to handle whitespace and newlines
        guard let derData = Data(base64Encoded: base64str, options: .ignoreUnknownCharacters) else {
            throw X509CertificateError.X509CertificateConversionError
        }

        do {
            return try Certificate(derEncoded: Array(derData))
        } catch {
            // Try PEM format as fallback
            guard let pem = base64strToPem(base64str: base64str) else {
                throw X509CertificateError.X509CertificateConversionError
            }
            do {
                return try Certificate(pemEncoded: pem)
            } catch {
                throw X509CertificateError.X509CertificateConversionError
            }
        }
    }

    static func convertPemWithDelimitersToX509Certificates(pemChain: String) throws -> [Certificate]
    {
        let certWithGarbage =
            pemChain
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: x509CertPostamble, omittingEmptySubsequences: true)
            .filter {
                $0.trimmingCharacters(in: .whitespacesAndNewlines) != ""
            }

        let cleaned =
            certWithGarbage
            .map {
                $0.replacingOccurrences(of: x509CertPreamble, with: "")
                    .replacingOccurrences(
                        of: #"\s+"#,
                        with: "",
                        options: .regularExpression
                    )
            }

        return try convertPemToX509Certificates(pemChain: cleaned)
    }

    static func convertPemToX509Certificates(pemChain: [String]) throws -> [Certificate] {
        return try pemChain.map { certString in
            // Check for invalid x5c format: certificates should be separate array elements,
            // not comma-separated within a single string (RFC 7515)
            if certString.contains(",") {
                throw X509CertificateError.invalidX5cFormat
            }
            return try decodeBase64ToX509Certificate(base64str: certString)
        }
    }

    static func getX509CertificatesFromUrl(url: String, session: URLSession = URLSession.shared)
        -> [Certificate]?
    {
        var result: [Certificate]?
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        X509CertificateOperations.getX509CertificatesFromUrl_(url: url, session: session) {
            certificates, error in
            defer {
                dispatchGroup.leave()
            }
            if let error = error {
                print(error)
            }
            else if let certificates = certificates {
                result = certificates
            }
        }
        dispatchGroup.wait()
        return result
    }

    static func getX509CertificatesFromUrl_(
        url: String, session: URLSession = URLSession.shared,
        completion: @escaping ([Certificate]?, Error?) -> Void
    ) {
        guard let requestURL = URL(string: url) else {
            completion(nil, NSError(domain: "Invalid URL", code: 0, userInfo: nil))
            return
        }

        let task = session.dataTask(with: requestURL) { data, response, error in
            if let error = error {
                completion(nil, error)
                return
            }

            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200
            else {
                completion(nil, NSError(domain: "Failed to download file", code: 0, userInfo: nil))
                return
            }

            if let data = data, let responseBody = String(data: data, encoding: .utf8) {
                do {
                    let certificates = try convertPemWithDelimitersToX509Certificates(
                        pemChain: responseBody)
                    completion(certificates, nil)
                }
                catch {
                    completion(nil, error)
                }
            }
            else {
                completion(nil, NSError(domain: "No data received", code: 0, userInfo: nil))
            }
        }

        task.resume()
    }

    // MARK: - Certificate Conversion Helpers

    /// Convert DER data array to SecCertificate array
    /// - Parameter derData: Array of DER-encoded certificate data
    /// - Returns: Array of SecCertificate, or nil if any conversion fails
    static func derDataToSecCertificates(_ derData: [Data]) -> [SecCertificate]? {
        let certs: [SecCertificate] = derData.compactMap {
            SecCertificateCreateWithData(nil, $0 as CFData)
        }

        // Ensure all certificates were converted successfully
        guard certs.count == derData.count else { return nil }
        return certs
    }

    /// Convert optional DER data array to SecCertificate array
    /// - Parameter derData: Array of optional DER-encoded certificate data (nil elements will cause failure)
    /// - Returns: Array of SecCertificate, or nil if any conversion fails or any element is nil
    static func derDataToSecCertificates(_ derData: [Data?]) -> [SecCertificate]? {
        // Check if any of the certificates in the array is nil
        if derData.contains(where: { $0 == nil }) {
            return nil
        }

        let certs: [SecCertificate] = derData.compactMap { $0 }.compactMap {
            SecCertificateCreateWithData(nil, $0 as CFData)
        }

        // Ensure all certificates were converted successfully
        guard certs.count == derData.count else { return nil }
        return certs
    }

    /// Convert X509.Certificate array to SecCertificate array
    /// - Parameter certificates: Array of X509.Certificate objects
    /// - Returns: Array of SecCertificate, or nil if any conversion fails
    static func certificatesToSecCertificates(_ certificates: [Certificate]) -> [SecCertificate]? {
        let certs: [SecCertificate] = certificates.compactMap { cert in
            guard let pem = try? cert.serializeAsPEM() else { return nil }
            return SecCertificateCreateWithData(nil, Data(pem.derBytes) as CFData)
        }

        // Ensure all certificates were converted successfully
        guard certs.count == certificates.count else { return nil }
        return certs
    }

    // MARK: - Certificate Chain Validation

    /// Validate certificate chain using custom trust anchors from TrustAnchorManager.
    /// This method builds the chain by combining the leaf certificate (from x5c) with
    /// built-in intermediate certificates.
    ///
    /// When x5c contains multiple certificates (leaf + intermediates), the provided chain is used as-is.
    /// When x5c contains only the leaf certificate, TrustAnchorManager's intermediate certificates are appended.
    ///
    /// - Parameters:
    ///   - certificates: Certificates from x5c header (leaf, or leaf + intermediates)
    ///   - useCustomAnchorsOnly: If true, only use custom anchors; if false, use custom anchors + system CA
    /// - Returns: Result with success or detailed validation error
    static func validateCertificateChainWithCustomAnchors(
        certificates: [SecCertificate],
        useCustomAnchorsOnly: Bool = false
    ) -> Result<Void, CertificateValidationError> {
        return validateCertificateChainWithCustomAnchors(
            certificates: certificates,
            trustAnchorManager: TrustAnchorManager.shared,
            useCustomAnchorsOnly: useCustomAnchorsOnly
        )
    }

    /// Validate certificate chain using a specific TrustAnchorManager instance.
    /// This overload allows using disposable TrustAnchorManager instances created from trusted lists.
    ///
    /// - Parameters:
    ///   - certificates: Certificates from x5c header (leaf, or leaf + intermediates)
    ///   - trustAnchorManager: The TrustAnchorManager instance to use for validation
    ///   - useCustomAnchorsOnly: If true, only use custom anchors; if false, use custom anchors + system CA
    /// - Returns: Result with success or detailed validation error
    static func validateCertificateChainWithCustomAnchors(
        certificates: [SecCertificate],
        trustAnchorManager: TrustAnchorManager,
        useCustomAnchorsOnly: Bool = false
    ) -> Result<Void, CertificateValidationError> {
        print("🔐 [CertValidation] ========== Certificate Chain Validation ==========")
        print("🔐 [CertValidation] Input certificates: \(certificates.count)")
        for (index, cert) in certificates.enumerated() {
            let name = SecCertificateCopySubjectSummary(cert) as String? ?? "Unknown"
            print("🔐 [CertValidation]   [\(index)] \(name)")
        }
        print("🔐 [CertValidation] Custom anchors available: \(trustAnchorManager.hasCustomAnchors)")
        print("🔐 [CertValidation]   Anchors: \(trustAnchorManager.anchorCertificates.count)")
        print("🔐 [CertValidation]   Intermediates: \(trustAnchorManager.intermediateCertificates.count)")

        // If no custom anchors available, fall back to system CA validation
        guard trustAnchorManager.hasCustomAnchors else {
            print("🔐 [CertValidation] ⚠️ No custom anchors, falling back to system CA")
            let result = validateTrust(
                certificates,
                customAnchors: nil,
                useCustomAnchorsOnly: false
            )
            logValidationResult(result)
            return result
        }

        // Build certificate chain based on x5c content:
        // - If x5c has only leaf (count == 1): supplement with TrustAnchorManager's intermediates
        // - If x5c has chain (count > 1): use x5c chain as-is (it already contains intermediates)
        var fullChain = certificates
        if certificates.count == 1 {
            fullChain.append(contentsOf: trustAnchorManager.intermediateCertificates)
            print("🔐 [CertValidation] Added \(trustAnchorManager.intermediateCertificates.count) intermediate(s) to chain")
        }

        print("🔐 [CertValidation] Validating with custom anchors...")
        let result = validateTrust(
            fullChain,
            customAnchors: trustAnchorManager.anchorCertificates,
            useCustomAnchorsOnly: useCustomAnchorsOnly
        )
        logValidationResult(result)
        return result
    }

    private static func logValidationResult(_ result: Result<Void, CertificateValidationError>) {
        switch result {
        case .success:
            print("🔐 [CertValidation] ✅ Certificate chain validation PASSED")
        case .failure(let error):
            print("🔐 [CertValidation] ❌ Certificate chain validation FAILED: \(error.errorDescription ?? "Unknown")")
        }
        print("🔐 [CertValidation] =================================================")
    }

    /// Core trust validation with optional custom anchors
    /// - Parameters:
    ///   - certificates: Certificate chain to validate
    ///   - customAnchors: Optional custom anchor certificates (root CAs). If nil, uses system CA.
    ///   - useCustomAnchorsOnly: If true and customAnchors is set, only trust custom anchors
    /// - Returns: Result with success or detailed error
    private static func validateTrust(
        _ certificates: [SecCertificate],
        customAnchors: [SecCertificate]?,
        useCustomAnchorsOnly: Bool
    ) -> Result<Void, CertificateValidationError> {
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let certsArray = certificates as CFArray

        let status = SecTrustCreateWithCertificates(certsArray, policy, &trust)
        guard status == errSecSuccess, let trust = trust else {
            print("SignatureUtil: Failed to create trust object")
            return .failure(.trustCreationFailed)
        }

        // Set custom anchor certificates if provided
        if let anchors = customAnchors {
            let anchorsArray = anchors as CFArray
            let anchorStatus = SecTrustSetAnchorCertificates(trust, anchorsArray)
            guard anchorStatus == errSecSuccess else {
                print("SignatureUtil: Failed to set anchor certificates")
                return .failure(.anchorSettingFailed)
            }
            SecTrustSetAnchorCertificatesOnly(trust, useCustomAnchorsOnly)
        }

        // Evaluate trust
        var error: CFError?
        if SecTrustEvaluateWithError(trust, &error) {
            var trustResult: SecTrustResultType = .invalid
            let result = SecTrustGetTrustResult(trust, &trustResult)
            guard result == errSecSuccess else {
                print("SignatureUtil: Failed to get trust result")
                return .failure(.unknownError(description: "Failed to get trust result"))
            }

            let isValid = trustResult == .unspecified || trustResult == .proceed
            if !isValid {
                print("SignatureUtil: Trust validation failed with result: \(trustResult.rawValue)")
                return .failure(.chainIncomplete)
            }
            return .success(())
        } else {
            let validationError = parseSecTrustError(error, certificates: certificates)
            print("SignatureUtil: Trust evaluation error: \(validationError.errorDescription ?? "unknown")")
            return .failure(validationError)
        }
    }

    /// Parse SecTrust CFError to CertificateValidationError
    private static func parseSecTrustError(
        _ cfError: CFError?,
        certificates: [SecCertificate]
    ) -> CertificateValidationError {
        guard let cfError = cfError else {
            return .unknownError(description: "Unknown error")
        }

        let nsError = cfError as Error as NSError
        let code = nsError.code

        // Get certificate name from the first certificate
        let certName: String
        if let firstCert = certificates.first {
            certName = SecCertificateCopySubjectSummary(firstCert) as String? ?? "Unknown"
        } else {
            certName = "Unknown"
        }

        // Map OSStatus codes to specific errors
        // Reference: Security.framework SecBase.h
        switch Int32(code) {
        case -67818: // errSecCertificateExpired
            return .certificateExpired(certificateName: certName)
        case -67819: // errSecCertificateNotValidYet
            return .certificateNotYetValid(certificateName: certName)
        case -67820: // errSecCertificateRevoked
            return .certificateRevoked(certificateName: certName)
        case -67843: // errSecNotTrusted
            return .untrustedRoot(certificateName: certName)
        default:
            // Try to extract description from error
            let description = nsError.localizedDescription
            return .unknownError(description: description)
        }
    }
}
