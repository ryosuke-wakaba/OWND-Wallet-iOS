//
//  DPoPService.swift
//  tw2023_wallet
//
//  Created for DPoP (RFC 9449) support.
//

import CryptoKit
import Foundation

/// DPoP (Demonstrating Proof of Possession) service according to RFC 9449
/// https://www.rfc-editor.org/rfc/rfc9449.html
enum DPoPService {

    /// DPoP-related errors
    enum DPoPError: Error, LocalizedError {
        case keyNotFound
        case unableToCreateProof
        case invalidAccessToken

        var errorDescription: String? {
            switch self {
            case .keyNotFound:
                return "DPoP key not found"
            case .unableToCreateProof:
                return "Unable to create DPoP proof"
            case .invalidAccessToken:
                return "Invalid access token for ath calculation"
            }
        }
    }

    /// Key alias for DPoP key pair
    private static var keyAlias: String {
        Constants.Cryptography.KEY_DPOP
    }

    /// Ensure DPoP key pair exists, create if not
    static func ensureKeyPairExists() throws {
        if !KeyPairUtil.isKeyPairExist(alias: keyAlias) {
            try KeyPairUtil.generateSignVerifyKeyPair(alias: keyAlias)
        }
    }

    /// Create DPoP Proof JWT for Token Endpoint (without ath)
    /// - Parameters:
    ///   - httpMethod: HTTP method (e.g., "POST")
    ///   - httpUri: Target URI (e.g., "https://issuer.example.com/token")
    ///   - nonce: Optional server-provided nonce
    /// - Returns: DPoP Proof JWT string
    static func createProof(
        httpMethod: String,
        httpUri: String,
        nonce: String? = nil
    ) throws -> String {
        return try createProofInternal(
            httpMethod: httpMethod,
            httpUri: httpUri,
            accessToken: nil,
            nonce: nonce
        )
    }

    /// Create DPoP Proof JWT for Resource Server (with ath)
    /// - Parameters:
    ///   - httpMethod: HTTP method (e.g., "POST")
    ///   - httpUri: Target URI (e.g., "https://issuer.example.com/credential")
    ///   - accessToken: Access token for ath calculation
    ///   - nonce: Optional server-provided nonce
    /// - Returns: DPoP Proof JWT string
    static func createProofWithAccessToken(
        httpMethod: String,
        httpUri: String,
        accessToken: String,
        nonce: String? = nil
    ) throws -> String {
        return try createProofInternal(
            httpMethod: httpMethod,
            httpUri: httpUri,
            accessToken: accessToken,
            nonce: nonce
        )
    }

    /// Internal method to create DPoP Proof JWT
    private static func createProofInternal(
        httpMethod: String,
        httpUri: String,
        accessToken: String?,
        nonce: String?
    ) throws -> String {
        // Ensure key exists
        try ensureKeyPairExists()

        // Get public key for JWK
        guard let publicKey = KeyPairUtil.getPublicKey(alias: keyAlias),
            let jwk = KeyPairUtil.publicKeyToJwk(publicKey: publicKey)
        else {
            throw DPoPError.keyNotFound
        }

        // Build header
        // RFC 9449: typ MUST be "dpop+jwt", alg MUST be asymmetric, jwk contains public key
        let header: [String: Any] = [
            "typ": "dpop+jwt",
            "alg": "ES256",
            "jwk": jwk,
        ]

        // Build payload
        var payload: [String: Any] = [
            "jti": generateJti(),
            "htm": httpMethod.uppercased(),
            "htu": normalizeUri(httpUri),
            "iat": Int(Date().timeIntervalSince1970),
        ]

        // Add ath if access token is provided (for resource server requests)
        if let accessToken = accessToken {
            let ath = try calculateAth(accessToken: accessToken)
            payload["ath"] = ath
        }

        // Add nonce if provided
        if let nonce = nonce {
            payload["nonce"] = nonce
        }

        // Sign and return JWT
        let result = JWTUtil.sign(keyAlias: keyAlias, header: header, payload: payload)
        switch result {
        case .success(let jwt):
            return jwt
        case .failure:
            throw DPoPError.unableToCreateProof
        }
    }

    /// Calculate ath (Access Token Hash) according to RFC 9449
    /// ath = Base64URL(SHA256(access_token))
    /// - Parameter accessToken: The access token string
    /// - Returns: Base64URL-encoded SHA256 hash of the access token
    static func calculateAth(accessToken: String) throws -> String {
        guard let data = accessToken.data(using: .ascii) else {
            throw DPoPError.invalidAccessToken
        }

        let hash = SHA256.hash(data: data)
        let hashData = Data(hash)

        return hashData.base64URLEncodedString()
    }

    /// Generate unique JWT ID (jti)
    /// Uses UUID + timestamp for sufficient entropy
    private static func generateJti() -> String {
        return UUID().uuidString
    }

    /// Normalize URI by removing query and fragment
    /// RFC 9449: htu MUST NOT include query and fragment components
    private static func normalizeUri(_ uri: String) -> String {
        guard let url = URL(string: uri),
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        else {
            return uri
        }

        // Remove query and fragment
        components.query = nil
        components.fragment = nil

        return components.string ?? uri
    }

    /// Get the public key JWK for the DPoP key
    /// This can be used to verify the key or for debugging
    static func getPublicKeyJwk() -> [String: String]? {
        guard let publicKey = KeyPairUtil.getPublicKey(alias: keyAlias) else {
            return nil
        }
        return KeyPairUtil.publicKeyToJwk(publicKey: publicKey)
    }
}
