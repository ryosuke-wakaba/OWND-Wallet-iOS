//
//  SignatureUtil.swift
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

enum SignatureUtilError: Error {
    case KeyConversionError
    case X509CertificateConversionError
}

let x509CertPreamble = "-----BEGIN CERTIFICATE-----\n"
let x509CertPostamble = "\n-----END CERTIFICATE-----"

enum SignatureUtil {
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
            throw SignatureUtilError.KeyConversionError
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
        guard let raw = Data(base64Encoded: base64str) else {
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

    static func decodeBase64ToX509Certificate(base64str: String) throws -> Certificate {
        guard let pem = base64strToPem(base64str: base64str) else {
            throw SignatureUtilError.X509CertificateConversionError
        }
        return try Certificate(pemEncoded: pem)
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

        return try! convertPemToX509Certificates(pemChain: cleaned)
    }

    static func convertPemToX509Certificates(pemChain: [String]) throws -> [Certificate] {
        return pemChain.map {
            try! decodeBase64ToX509Certificate(base64str: $0)
        }
    }

    static func getX509CertificatesFromUrl(url: String, session: URLSession = URLSession.shared)
        -> [Certificate]?
    {
        var result: [Certificate]?
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        SignatureUtil.getX509CertificatesFromUrl_(url: url, session: session) {
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
    /// - Parameters:
    ///   - leafCertificates: Certificates from x5c header (typically just the leaf)
    ///   - useCustomAnchorsOnly: If true, only use custom anchors; if false, use custom anchors + system CA
    /// - Returns: true if chain is valid
    static func validateCertificateChainWithCustomAnchors(
        leafCertificates: [SecCertificate],
        useCustomAnchorsOnly: Bool = false
    ) throws -> Bool {
        let manager = TrustAnchorManager.shared

        // If no custom anchors available, fall back to system CA validation
        guard manager.hasCustomAnchors else {
            print("SignatureUtil: No custom anchors available, falling back to system CA")
            return try validateTrust(
                leafCertificates,
                customAnchors: nil,
                useCustomAnchorsOnly: false
            )
        }

        // Build full chain: leaf + intermediates
        var fullChain = leafCertificates
        fullChain.append(contentsOf: manager.intermediateCertificates)

        return try validateTrust(
            fullChain,
            customAnchors: manager.anchorCertificates,
            useCustomAnchorsOnly: useCustomAnchorsOnly
        )
    }

    /// Core trust validation with optional custom anchors
    /// - Parameters:
    ///   - certificates: Certificate chain to validate
    ///   - customAnchors: Optional custom anchor certificates (root CAs). If nil, uses system CA.
    ///   - useCustomAnchorsOnly: If true and customAnchors is set, only trust custom anchors
    /// - Returns: true if chain is valid
    private static func validateTrust(
        _ certificates: [SecCertificate],
        customAnchors: [SecCertificate]?,
        useCustomAnchorsOnly: Bool
    ) throws -> Bool {
        var trust: SecTrust?
        let policy = SecPolicyCreateBasicX509()
        let certsArray = certificates as CFArray

        let status = SecTrustCreateWithCertificates(certsArray, policy, &trust)
        guard status == errSecSuccess, let trust = trust else {
            print("SignatureUtil: Failed to create trust object")
            return false
        }

        // Set custom anchor certificates if provided
        if let anchors = customAnchors {
            let anchorsArray = anchors as CFArray
            let anchorStatus = SecTrustSetAnchorCertificates(trust, anchorsArray)
            guard anchorStatus == errSecSuccess else {
                print("SignatureUtil: Failed to set anchor certificates")
                return false
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
                return false
            }

            let isValid = trustResult == .unspecified || trustResult == .proceed
            if !isValid {
                print("SignatureUtil: Trust validation failed with result: \(trustResult.rawValue)")
            }
            return isValid
        } else {
            if let error = error {
                print("SignatureUtil: Trust evaluation error: \(error)")
            }
            return false
        }
    }
}
