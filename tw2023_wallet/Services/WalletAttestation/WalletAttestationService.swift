//
//  WalletAttestationService.swift
//  tw2023_wallet
//
//  Service for generating Wallet Attestation JWTs according to:
//  - OID4VCI Appendix E (Wallet Attestations in JWT format)
//  - OAuth 2.0 Attestation-Based Client Authentication (draft-ietf-oauth-attestation-based-client-auth)
//  - HAIP 4.4.1 (Wallet Attestation)
//

import CryptoKit
import Foundation
import Security

/// Service for managing Wallet Attestation (Client Attestation) functionality
class WalletAttestationService {
    static let shared = WalletAttestationService()

    // MARK: - Error Types

    enum WalletAttestationError: Error, LocalizedError {
        case keyNotFound
        case providerKeyNotFound
        case providerCertificateNotFound
        case attestationGenerationFailed
        case popGenerationFailed
        case attestationNotEnabled
        case attestationExpired
        case signingFailed(String)

        var errorDescription: String? {
            switch self {
            case .keyNotFound:
                return "Wallet attestation key not found"
            case .providerKeyNotFound:
                return "Wallet provider private key not found"
            case .providerCertificateNotFound:
                return "Wallet provider certificate not found"
            case .attestationGenerationFailed:
                return "Failed to generate client attestation"
            case .popGenerationFailed:
                return "Failed to generate client attestation PoP"
            case .attestationNotEnabled:
                return "Client attestation is not enabled"
            case .attestationExpired:
                return "Client attestation has expired"
            case .signingFailed(let reason):
                return "Signing failed: \(reason)"
            }
        }
    }

    // MARK: - Constants

    /// Key alias for the wallet attestation key pair (used in cnf claim)
    private var keyAlias: String {
        Constants.Cryptography.KEY_WALLET_ATTESTATION
    }

    /// Provider key PEM filename (bundled at build time)
    private let providerKeyFilename = "wallet-provider-private"

    /// Provider certificate filename (bundled at build time)
    private let providerCertFilename = "wallet-provider"

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// Check if client attestation is enabled
    func isAttestationEnabled() -> Bool {
        return PreferencesDataStore.shared.getUseClientAttestation()
    }

    /// Generate and store Client Attestation JWT
    /// Called when the user enables client attestation in settings
    func generateAndStoreClientAttestation() async throws {
        print("[WalletAttestation] ========== Generating Client Attestation ==========")

        // Ensure attestation key pair exists
        try ensureKeyPairExists()

        // Generate the attestation JWT
        let attestationJwt = try generateClientAttestation()

        // Store it
        PreferencesDataStore.shared.saveClientAttestationJwt(attestationJwt)

        print("[WalletAttestation] Client Attestation generated and stored successfully")
        print("[WalletAttestation] JWT length: \(attestationJwt.count) characters")
        print("[WalletAttestation] ===================================================")
    }

    /// Get stored Client Attestation JWT, regenerating if expired or not present
    /// - Returns: Valid Client Attestation JWT
    func getClientAttestation() throws -> String {
        guard isAttestationEnabled() else {
            throw WalletAttestationError.attestationNotEnabled
        }

        // Check if we have a stored attestation
        if let storedJwt = PreferencesDataStore.shared.getClientAttestationJwt() {
            // Check if it's still valid (not expired)
            if !isAttestationExpired(storedJwt) {
                return storedJwt
            }
            print("[WalletAttestation] Stored attestation is expired, regenerating...")
        }

        // Generate new attestation
        let newJwt = try generateClientAttestation()
        PreferencesDataStore.shared.saveClientAttestationJwt(newJwt)
        return newJwt
    }

    /// Generate Client Attestation PoP JWT for a specific authorization server
    /// - Parameter audience: The authorization server's issuer URL
    /// - Returns: Client Attestation PoP JWT
    func generateClientAttestationPoP(audience: String) throws -> String {
        print("[WalletAttestation] ========== Generating Client Attestation PoP ==========")
        print("[WalletAttestation] Audience: \(audience)")

        guard isAttestationEnabled() else {
            throw WalletAttestationError.attestationNotEnabled
        }

        // Ensure key pair exists
        try ensureKeyPairExists()

        // Build PoP JWT header
        let header: [String: Any] = [
            "typ": "oauth-client-attestation-pop+jwt",
            "alg": "ES256",
        ]

        // Build PoP JWT payload
        let now = Date()
        let iat = Int(now.timeIntervalSince1970)
        let jti = UUID().uuidString

        let payload: [String: Any] = [
            "iss": Constants.WalletAttestation.CLIENT_ID,
            "aud": audience,
            "jti": jti,
            "iat": iat,
        ]

        print("[WalletAttestation] PoP Header: typ=oauth-client-attestation-pop+jwt, alg=ES256")
        print("[WalletAttestation] PoP Payload:")
        print("[WalletAttestation]   iss: \(Constants.WalletAttestation.CLIENT_ID)")
        print("[WalletAttestation]   aud: \(audience)")
        print("[WalletAttestation]   jti: \(jti)")
        print("[WalletAttestation]   iat: \(iat)")

        // Sign with the attestation key (same key referenced in cnf of Client Attestation)
        let result = JWTOperations.sign(keyAlias: keyAlias, header: header, payload: payload)
        switch result {
        case .success(let jwt):
            print("[WalletAttestation] PoP JWT created successfully")
            print("[WalletAttestation] JWT length: \(jwt.count) characters")
            print("[WalletAttestation] ======================================================")
            return jwt
        case .failure(let error):
            print("[WalletAttestation] ERROR: Failed to sign PoP JWT - \(error)")
            throw WalletAttestationError.popGenerationFailed
        }
    }

    // MARK: - Private Methods

    /// Ensure the attestation key pair exists
    private func ensureKeyPairExists() throws {
        if !KeyPairUtil.isKeyPairExist(alias: keyAlias) {
            print("[WalletAttestation] Creating new attestation key pair...")
            try KeyPairUtil.generateSignVerifyKeyPair(alias: keyAlias)
            print("[WalletAttestation] Attestation key pair created successfully")
        } else {
            print("[WalletAttestation] Using existing attestation key pair")
        }
    }

    /// Generate Client Attestation JWT
    /// - Returns: Client Attestation JWT signed by the wallet provider
    private func generateClientAttestation() throws -> String {
        print("[WalletAttestation] Generating Client Attestation JWT...")

        // Load provider private key and certificate from bundled PEM files
        let providerPrivateKey: SecKey
        let x5cChain: [String]

        do {
            providerPrivateKey = try PEMUtils.loadPrivateKey(filename: providerKeyFilename)
            print("[WalletAttestation] Provider private key loaded")
        } catch {
            print("[WalletAttestation] ERROR: Failed to load provider private key: \(error)")
            throw WalletAttestationError.providerKeyNotFound
        }

        do {
            x5cChain = try PEMUtils.getCertificateChainForX5C(filename: providerCertFilename)
            print("[WalletAttestation] Provider certificate chain loaded (\(x5cChain.count) cert(s))")
        } catch {
            print("[WalletAttestation] ERROR: Failed to load provider certificate: \(error)")
            throw WalletAttestationError.providerCertificateNotFound
        }

        // Get public key JWK for cnf claim
        guard let publicKey = KeyPairUtil.getPublicKey(alias: keyAlias),
              let jwk = KeyPairUtil.publicKeyToJwk(publicKey: publicKey) else {
            throw WalletAttestationError.keyNotFound
        }

        print("[WalletAttestation] Attestation public key JWK:")
        print("[WalletAttestation]   kty: \(jwk["kty"] ?? "N/A")")
        print("[WalletAttestation]   crv: \(jwk["crv"] ?? "N/A")")

        // Build JWT header with x5c
        let header: [String: Any] = [
            "typ": "oauth-client-attestation+jwt",
            "alg": "ES256",
            "x5c": x5cChain,
        ]

        // Build JWT payload
        let now = Date()
        let nbf = Int(now.timeIntervalSince1970)
        let exp = Int(now.addingTimeInterval(Constants.WalletAttestation.ATTESTATION_VALIDITY_SECONDS).timeIntervalSince1970)

        let payload: [String: Any] = [
            "iss": Constants.WalletAttestation.PROVIDER_ISSUER,
            "sub": Constants.WalletAttestation.CLIENT_ID,
            "nbf": nbf,
            "exp": exp,
            "cnf": ["jwk": jwk],
            "wallet_name": Constants.WalletAttestation.WALLET_NAME,
            "wallet_link": Constants.WalletAttestation.WALLET_LINK,
        ]

        print("[WalletAttestation] Attestation Header:")
        print("[WalletAttestation]   typ: oauth-client-attestation+jwt")
        print("[WalletAttestation]   alg: ES256")
        print("[WalletAttestation]   x5c: \(x5cChain.count) certificate(s)")
        print("[WalletAttestation] Attestation Payload:")
        print("[WalletAttestation]   iss: \(Constants.WalletAttestation.PROVIDER_ISSUER)")
        print("[WalletAttestation]   sub: \(Constants.WalletAttestation.CLIENT_ID)")
        print("[WalletAttestation]   nbf: \(nbf)")
        print("[WalletAttestation]   exp: \(exp)")
        print("[WalletAttestation]   wallet_name: \(Constants.WalletAttestation.WALLET_NAME)")

        // Sign with provider's private key using JWTOperations
        let result = JWTOperations.sign(privateKey: providerPrivateKey, header: header, payload: payload)
        switch result {
        case .success(let jwt):
            return jwt
        case .failure(let error):
            throw WalletAttestationError.signingFailed("\(error)")
        }
    }

    /// Check if attestation JWT is expired
    /// - Parameter jwt: JWT string to check
    /// - Returns: true if expired, false otherwise
    private func isAttestationExpired(_ jwt: String) -> Bool {
        do {
            let (_, payload, _) = try JWTOperations.decodeJwt(jwt: jwt)
            guard let exp = payload["exp"] as? Int else {
                return true // No exp claim, consider expired
            }

            let expirationDate = Date(timeIntervalSince1970: TimeInterval(exp))
            // Add a buffer (e.g., 5 minutes) before actual expiration
            let bufferSeconds: TimeInterval = 300
            return Date().addingTimeInterval(bufferSeconds) >= expirationDate
        } catch {
            return true // Unable to decode, consider expired
        }
    }
}
