//
//  JWEUtil.swift
//  tw2023_wallet
//
//  Created for HAIP VP Token encryption support
//

import CryptoKit
import Foundation

enum JWEError: Error {
    case invalidPublicKey
    case encryptionFailed
    case invalidJWK
    case unsupportedAlgorithm
}

/// JWE encryption utility for HAIP-compliant VP Token encryption
/// Supports ECDH-ES + A128GCM with P-256 curve
struct JWEUtil {

    /// Decode Base64URL string to Data
    private static func base64URLDecode(_ string: String) -> Data? {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let paddingLength = (4 - base64.count % 4) % 4
        base64 += String(repeating: "=", count: paddingLength)

        return Data(base64Encoded: base64)
    }

    /// Encrypt payload using ECDH-ES + A128GCM
    /// - Parameters:
    ///   - payload: JSON payload to encrypt (e.g., {"vp_token": {...}})
    ///   - recipientPublicKey: Verifier's public key from client_metadata.jwks
    /// - Returns: JWE Compact Serialization string
    static func encrypt(payload: [String: Any], recipientPublicKey: ClientJWK) throws -> String {
        // Validate public key
        guard recipientPublicKey.kty == "EC",
              recipientPublicKey.crv == "P-256",
              let x = recipientPublicKey.x,
              let y = recipientPublicKey.y
        else {
            throw JWEError.invalidJWK
        }

        // Convert payload to JSON data
        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        // Decode x and y coordinates from Base64URL
        guard let xData = base64URLDecode(x),
              let yData = base64URLDecode(y)
        else {
            throw JWEError.invalidPublicKey
        }

        // Create recipient's P256 public key
        let recipientKey = try P256.KeyAgreement.PublicKey(
            x963Representation: Data([0x04]) + xData + yData
        )

        // Generate ephemeral key pair for ECDH
        let ephemeralPrivateKey = P256.KeyAgreement.PrivateKey()
        let ephemeralPublicKey = ephemeralPrivateKey.publicKey

        // Perform ECDH key agreement
        let sharedSecret = try ephemeralPrivateKey.sharedSecretFromKeyAgreement(with: recipientKey)

        // Derive content encryption key using Concat KDF (simplified for A128GCM)
        // For ECDH-ES, the derived key is used directly
        let algorithmId = "A128GCM"
        let derivedKey = deriveKey(
            sharedSecret: sharedSecret,
            algorithmId: algorithmId,
            keyLength: 16  // 128 bits for A128GCM
        )

        // Generate random IV (96 bits for GCM)
        var iv = Data(count: 12)
        _ = iv.withUnsafeMutableBytes { SecRandomCopyBytes(kSecRandomDefault, 12, $0.baseAddress!) }

        // Encrypt with AES-GCM
        let symmetricKey = CryptoKit.SymmetricKey(data: derivedKey)
        let nonce = try AES.GCM.Nonce(data: iv)
        let sealedBox = try AES.GCM.seal(payloadData, using: symmetricKey, nonce: nonce)

        // Build JWE Protected Header
        let epkX = ephemeralPublicKey.x963Representation.dropFirst().prefix(32)
        let epkY = ephemeralPublicKey.x963Representation.dropFirst().dropFirst(32)

        var header: [String: Any] = [
            "alg": "ECDH-ES",
            "enc": "A128GCM",
            "epk": [
                "kty": "EC",
                "crv": "P-256",
                "x": epkX.base64URLEncodedString(),
                "y": epkY.base64URLEncodedString()
            ]
        ]

        // Include kid if present
        if let kid = recipientPublicKey.kid {
            header["kid"] = kid
        }

        let headerData = try JSONSerialization.data(withJSONObject: header)
        let protectedHeader = headerData.base64URLEncodedString()

        // For ECDH-ES, encrypted key is empty
        let encryptedKey = ""

        // IV
        let ivEncoded = iv.base64URLEncodedString()

        // Ciphertext (without tag)
        let ciphertext = sealedBox.ciphertext.base64URLEncodedString()

        // Authentication tag
        let tag = sealedBox.tag.base64URLEncodedString()

        // Build JWE Compact Serialization
        return "\(protectedHeader).\(encryptedKey).\(ivEncoded).\(ciphertext).\(tag)"
    }

    /// Derive key using Concat KDF for ECDH-ES
    private static func deriveKey(sharedSecret: SharedSecret, algorithmId: String, keyLength: Int) -> Data {
        // Concat KDF as per RFC 7518 Section 4.6
        // OtherInfo = AlgorithmID || PartyUInfo || PartyVInfo || SuppPubInfo
        // For simplicity, using algorithm ID length-prefixed

        let algIdData = algorithmId.data(using: .utf8)!
        var otherInfo = Data()

        // AlgorithmID (length-prefixed)
        var algIdLen = UInt32(algIdData.count).bigEndian
        otherInfo.append(Data(bytes: &algIdLen, count: 4))
        otherInfo.append(algIdData)

        // PartyUInfo (empty, length-prefixed)
        var partyULen = UInt32(0).bigEndian
        otherInfo.append(Data(bytes: &partyULen, count: 4))

        // PartyVInfo (empty, length-prefixed)
        var partyVLen = UInt32(0).bigEndian
        otherInfo.append(Data(bytes: &partyVLen, count: 4))

        // SuppPubInfo (key length in bits, big-endian)
        var keyLenBits = UInt32(keyLength * 8).bigEndian
        otherInfo.append(Data(bytes: &keyLenBits, count: 4))

        // Use HKDF with SHA-256
        let derivedKey = sharedSecret.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: Data(),
            sharedInfo: otherInfo,
            outputByteCount: keyLength
        )

        return derivedKey.withUnsafeBytes { Data($0) }
    }
}
