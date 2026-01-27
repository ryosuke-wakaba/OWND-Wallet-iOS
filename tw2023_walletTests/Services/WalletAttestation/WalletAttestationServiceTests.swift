//
//  WalletAttestationServiceTests.swift
//  tw2023_walletTests
//
//  Tests for WalletAttestationService - Wallet Attestation JWT generation
//
//  Specification references:
//  - OID4VCI Appendix E: Wallet Attestations in JWT format
//  - OAuth 2.0 Attestation-Based Client Authentication (draft-ietf-oauth-attestation-based-client-auth)
//  - HAIP 4.4.1: Wallet Attestation
//

import XCTest
@testable import tw2023_wallet

final class WalletAttestationServiceTests: XCTestCase {

    override func setUpWithError() throws {
        // Setup if needed
    }

    override func tearDownWithError() throws {
        // Cleanup if needed
    }

    // MARK: - Client Attestation PoP JWT Format Tests

    /// Test that Client Attestation PoP JWT has correct header format
    /// Specification: typ MUST be "oauth-client-attestation-pop+jwt"
    func testClientAttestationPoPJWTHeaderFormat() throws {
        // Skip if attestation is not enabled
        guard WalletAttestationService.shared.isAttestationEnabled() else {
            throw XCTSkip("Client attestation is not enabled")
        }

        let audience = "https://issuer.example.com"
        let popJwt = try WalletAttestationService.shared.generateClientAttestationPoP(audience: audience)

        // Decode JWT header
        let parts = popJwt.components(separatedBy: ".")
        XCTAssertEqual(parts.count, 3, "JWT should have 3 parts")

        let headerData = try decodeBase64URL(parts[0])
        let header = try JSONSerialization.jsonObject(with: headerData) as! [String: Any]

        // Verify header per specification
        XCTAssertEqual(header["typ"] as? String, "oauth-client-attestation-pop+jwt",
                       "typ MUST be oauth-client-attestation-pop+jwt")
        XCTAssertEqual(header["alg"] as? String, "ES256",
                       "alg should be ES256")
    }

    /// Test that Client Attestation PoP JWT has all required claims
    /// Specification: iss, aud, jti, iat are REQUIRED
    func testClientAttestationPoPJWTRequiredClaims() throws {
        guard WalletAttestationService.shared.isAttestationEnabled() else {
            throw XCTSkip("Client attestation is not enabled")
        }

        let audience = "https://issuer.example.com"
        let popJwt = try WalletAttestationService.shared.generateClientAttestationPoP(audience: audience)

        // Decode JWT payload
        let parts = popJwt.components(separatedBy: ".")
        let payloadData = try decodeBase64URL(parts[1])
        let payload = try JSONSerialization.jsonObject(with: payloadData) as! [String: Any]

        // Verify required claims per specification
        XCTAssertNotNil(payload["iss"], "iss (issuer) claim is REQUIRED")
        XCTAssertNotNil(payload["aud"], "aud (audience) claim is REQUIRED")
        XCTAssertNotNil(payload["jti"], "jti (JWT identifier) claim is REQUIRED")
        XCTAssertNotNil(payload["iat"], "iat (issued at) claim is REQUIRED")
    }

    /// Test that PoP JWT aud matches the provided audience
    /// Specification: aud MUST identify the authorization server as intended audience
    func testClientAttestationPoPJWTAudienceMatchesInput() throws {
        guard WalletAttestationService.shared.isAttestationEnabled() else {
            throw XCTSkip("Client attestation is not enabled")
        }

        let expectedAudience = "https://issuer.example.com"
        let popJwt = try WalletAttestationService.shared.generateClientAttestationPoP(audience: expectedAudience)

        let parts = popJwt.components(separatedBy: ".")
        let payloadData = try decodeBase64URL(parts[1])
        let payload = try JSONSerialization.jsonObject(with: payloadData) as! [String: Any]

        XCTAssertEqual(payload["aud"] as? String, expectedAudience,
                       "aud should match the authorization server issuer URL")
    }

    /// Test that each PoP JWT has unique jti
    /// Specification: jti MUST be a unique identifier for replay attack detection
    func testClientAttestationPoPJWTUniqueJti() throws {
        guard WalletAttestationService.shared.isAttestationEnabled() else {
            throw XCTSkip("Client attestation is not enabled")
        }

        let audience = "https://issuer.example.com"

        let popJwt1 = try WalletAttestationService.shared.generateClientAttestationPoP(audience: audience)
        let popJwt2 = try WalletAttestationService.shared.generateClientAttestationPoP(audience: audience)

        // Extract jti from both
        let jti1 = try extractClaim(from: popJwt1, claim: "jti") as? String
        let jti2 = try extractClaim(from: popJwt2, claim: "jti") as? String

        XCTAssertNotNil(jti1)
        XCTAssertNotNil(jti2)
        XCTAssertNotEqual(jti1, jti2, "Each PoP JWT should have a unique jti for replay protection")
    }

    /// Test that PoP JWT iss matches Client Attestation sub (client_id)
    /// Specification: iss in PoP JWT MUST match sub in Client Attestation
    func testClientAttestationPoPJWTIssMatchesClientId() throws {
        guard WalletAttestationService.shared.isAttestationEnabled() else {
            throw XCTSkip("Client attestation is not enabled")
        }

        let audience = "https://issuer.example.com"
        let popJwt = try WalletAttestationService.shared.generateClientAttestationPoP(audience: audience)

        let parts = popJwt.components(separatedBy: ".")
        let payloadData = try decodeBase64URL(parts[1])
        let payload = try JSONSerialization.jsonObject(with: payloadData) as! [String: Any]

        let popIss = payload["iss"] as? String
        let expectedClientId = Constants.WalletAttestation.CLIENT_ID

        XCTAssertEqual(popIss, expectedClientId,
                       "PoP JWT iss should match CLIENT_ID (which is also Client Attestation sub)")
    }

    // MARK: - Error Handling Tests

    /// Test that generating PoP throws error when attestation is not enabled
    func testGeneratePoPThrowsWhenNotEnabled() {
        // Temporarily disable attestation
        let wasEnabled = PreferencesDataStore.shared.getUseClientAttestation()
        PreferencesDataStore.shared.setUseClientAttestation(false)

        defer {
            // Restore original state
            PreferencesDataStore.shared.setUseClientAttestation(wasEnabled)
        }

        XCTAssertThrowsError(
            try WalletAttestationService.shared.generateClientAttestationPoP(audience: "https://example.com")
        ) { error in
            if case WalletAttestationService.WalletAttestationError.attestationNotEnabled = error {
                // Expected
            } else {
                XCTFail("Should throw attestationNotEnabled error, got: \(error)")
            }
        }
    }

    /// Test isAttestationEnabled returns correct value based on settings
    func testIsAttestationEnabledReflectsSettings() {
        let originalValue = PreferencesDataStore.shared.getUseClientAttestation()

        // Test with enabled
        PreferencesDataStore.shared.setUseClientAttestation(true)
        XCTAssertTrue(WalletAttestationService.shared.isAttestationEnabled())

        // Test with disabled
        PreferencesDataStore.shared.setUseClientAttestation(false)
        XCTAssertFalse(WalletAttestationService.shared.isAttestationEnabled())

        // Restore original value
        PreferencesDataStore.shared.setUseClientAttestation(originalValue)
    }

    // MARK: - Helper Methods

    private func decodeBase64URL(_ string: String) throws -> Data {
        var base64 = string
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        let remainder = base64.count % 4
        if remainder > 0 {
            base64 += String(repeating: "=", count: 4 - remainder)
        }

        guard let data = Data(base64Encoded: base64) else {
            throw NSError(domain: "Test", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid base64"])
        }
        return data
    }

    private func extractClaim(from jwt: String, claim: String) throws -> Any? {
        let parts = jwt.components(separatedBy: ".")
        guard parts.count == 3 else { return nil }

        let payloadData = try decodeBase64URL(parts[1])
        let payload = try JSONSerialization.jsonObject(with: payloadData) as? [String: Any]
        return payload?[claim]
    }
}
