//
//  DPoPServiceTests.swift
//  tw2023_walletTests
//
//  Created for DPoP (RFC 9449) support testing.
//

import XCTest

final class DPoPServiceTests: XCTestCase {

    override func setUpWithError() throws {
        // Ensure DPoP key pair exists before tests
        try DPoPService.ensureKeyPairExists()
    }

    override func tearDownWithError() throws {
        // Cleanup if needed
    }

    // MARK: - ath calculation tests

    /// Test ath (Access Token Hash) calculation consistency
    /// RFC 9449 specifies: ath = Base64URL(SHA256(access_token))
    func testCalculateAthConsistency() throws {
        let accessToken = "test-access-token-12345"

        // Calculate ath twice - should produce same result
        let ath1 = try DPoPService.calculateAth(accessToken: accessToken)
        let ath2 = try DPoPService.calculateAth(accessToken: accessToken)

        XCTAssertEqual(ath1, ath2, "ath calculation should be consistent")

        // Verify length - SHA256 produces 32 bytes, Base64URL encodes to 43 characters (no padding)
        XCTAssertEqual(ath1.count, 43, "ath should be 43 characters (Base64URL encoded SHA256)")
    }

    /// Test ath calculation with known value (manually verified)
    func testCalculateAthWithKnownValue() throws {
        // Manually verified: SHA256("test") in Base64URL = "n4bQgYhMfWWaL-qgxVrQFaO_TxsrC4Is0V1sFbDwCgg"
        let accessToken = "test"
        let expectedAth = "n4bQgYhMfWWaL-qgxVrQFaO_TxsrC4Is0V1sFbDwCgg"

        let calculatedAth = try DPoPService.calculateAth(accessToken: accessToken)

        XCTAssertEqual(calculatedAth, expectedAth, "ath calculation should produce correct hash")
    }

    /// Test ath calculation produces base64url encoding (no padding, url-safe characters)
    func testCalculateAthProducesBase64UrlEncoding() throws {
        let accessToken = "test-access-token-123"

        let ath = try DPoPService.calculateAth(accessToken: accessToken)

        // Base64URL should not contain +, /, or =
        XCTAssertFalse(ath.contains("+"), "ath should not contain + character")
        XCTAssertFalse(ath.contains("/"), "ath should not contain / character")
        XCTAssertFalse(ath.contains("="), "ath should not contain padding")
    }

    // MARK: - DPoP Proof generation tests

    /// Test creating DPoP proof for token endpoint (without ath)
    func testCreateProofForTokenEndpoint() throws {
        let httpMethod = "POST"
        let httpUri = "https://example.com/token"

        let proof = try DPoPService.createProof(
            httpMethod: httpMethod,
            httpUri: httpUri
        )

        // Verify proof is a valid JWT (3 parts separated by dots)
        let parts = proof.components(separatedBy: ".")
        XCTAssertEqual(parts.count, 3, "DPoP proof should be a valid JWT with 3 parts")

        // Decode and verify header
        let headerData = Data(base64URLEncoded: parts[0].data(using: .utf8)!)!
        let header = try JSONSerialization.jsonObject(with: headerData) as! [String: Any]

        XCTAssertEqual(header["typ"] as? String, "dpop+jwt", "typ should be dpop+jwt")
        XCTAssertEqual(header["alg"] as? String, "ES256", "alg should be ES256")
        XCTAssertNotNil(header["jwk"], "jwk should be present in header")

        // Decode and verify payload
        let payloadData = Data(base64URLEncoded: parts[1].data(using: .utf8)!)!
        let payload = try JSONSerialization.jsonObject(with: payloadData) as! [String: Any]

        XCTAssertNotNil(payload["jti"], "jti should be present")
        XCTAssertEqual(payload["htm"] as? String, "POST", "htm should be POST")
        XCTAssertEqual(payload["htu"] as? String, httpUri, "htu should match the URI")
        XCTAssertNotNil(payload["iat"], "iat should be present")
        XCTAssertNil(payload["ath"], "ath should NOT be present for token endpoint")
    }

    /// Test creating DPoP proof for resource server (with ath)
    func testCreateProofWithAccessToken() throws {
        let httpMethod = "POST"
        let httpUri = "https://example.com/credential"
        let accessToken = "test-access-token"

        let proof = try DPoPService.createProofWithAccessToken(
            httpMethod: httpMethod,
            httpUri: httpUri,
            accessToken: accessToken
        )

        // Decode and verify payload
        let parts = proof.components(separatedBy: ".")
        let payloadData = Data(base64URLEncoded: parts[1].data(using: .utf8)!)!
        let payload = try JSONSerialization.jsonObject(with: payloadData) as! [String: Any]

        XCTAssertNotNil(payload["ath"], "ath should be present for resource server requests")

        // Verify ath matches expected value
        let expectedAth = try DPoPService.calculateAth(accessToken: accessToken)
        XCTAssertEqual(payload["ath"] as? String, expectedAth, "ath should match calculated hash")
    }

    /// Test creating DPoP proof with nonce
    func testCreateProofWithNonce() throws {
        let httpMethod = "POST"
        let httpUri = "https://example.com/credential"
        let accessToken = "test-access-token"
        let nonce = "server-provided-nonce"

        let proof = try DPoPService.createProofWithAccessToken(
            httpMethod: httpMethod,
            httpUri: httpUri,
            accessToken: accessToken,
            nonce: nonce
        )

        // Decode and verify payload
        let parts = proof.components(separatedBy: ".")
        let payloadData = Data(base64URLEncoded: parts[1].data(using: .utf8)!)!
        let payload = try JSONSerialization.jsonObject(with: payloadData) as! [String: Any]

        XCTAssertEqual(payload["nonce"] as? String, nonce, "nonce should be included in payload")
    }

    /// Test URI normalization (query and fragment removal)
    func testUriNormalization() throws {
        let httpMethod = "POST"
        let httpUriWithQuery = "https://example.com/credential?foo=bar#section"

        let proof = try DPoPService.createProof(
            httpMethod: httpMethod,
            httpUri: httpUriWithQuery
        )

        // Decode payload
        let parts = proof.components(separatedBy: ".")
        let payloadData = Data(base64URLEncoded: parts[1].data(using: .utf8)!)!
        let payload = try JSONSerialization.jsonObject(with: payloadData) as! [String: Any]

        // htu should not contain query or fragment
        let htu = payload["htu"] as? String
        XCTAssertEqual(htu, "https://example.com/credential", "htu should have query and fragment removed")
    }

    /// Test that each proof has a unique jti
    func testUniqueJtiGeneration() throws {
        let httpMethod = "POST"
        let httpUri = "https://example.com/token"

        let proof1 = try DPoPService.createProof(httpMethod: httpMethod, httpUri: httpUri)
        let proof2 = try DPoPService.createProof(httpMethod: httpMethod, httpUri: httpUri)

        // Decode both payloads
        let parts1 = proof1.components(separatedBy: ".")
        let parts2 = proof2.components(separatedBy: ".")

        let payload1 = try JSONSerialization.jsonObject(with: Data(base64URLEncoded: parts1[1].data(using: .utf8)!)!) as! [String: Any]
        let payload2 = try JSONSerialization.jsonObject(with: Data(base64URLEncoded: parts2[1].data(using: .utf8)!)!) as! [String: Any]

        XCTAssertNotEqual(payload1["jti"] as? String, payload2["jti"] as? String, "Each proof should have a unique jti")
    }

    // MARK: - Public Key tests

    /// Test getting public key JWK
    func testGetPublicKeyJwk() throws {
        let jwk = DPoPService.getPublicKeyJwk()

        XCTAssertNotNil(jwk, "Public key JWK should be available")
        XCTAssertEqual(jwk?["kty"], "EC", "Key type should be EC")
        XCTAssertEqual(jwk?["crv"], "P-256", "Curve should be P-256")
        XCTAssertNotNil(jwk?["x"], "x coordinate should be present")
        XCTAssertNotNil(jwk?["y"], "y coordinate should be present")
    }
}

// MARK: - Helper Extensions

extension Data {
    /// Initialize Data from Base64URL encoded string
    init?(base64URLEncoded input: Data) {
        guard var str = String(data: input, encoding: .utf8) else { return nil }

        // Convert Base64URL to Base64
        str = str.replacingOccurrences(of: "-", with: "+")
        str = str.replacingOccurrences(of: "_", with: "/")

        // Add padding if needed
        let remainder = str.count % 4
        if remainder > 0 {
            str += String(repeating: "=", count: 4 - remainder)
        }

        self.init(base64Encoded: str)
    }
}
