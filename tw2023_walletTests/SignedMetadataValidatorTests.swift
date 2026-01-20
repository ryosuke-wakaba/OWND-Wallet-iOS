//
//  SignedMetadataValidatorTests.swift
//  tw2023_walletTests
//
//  Tests for OID4VCI Signed Metadata validation (Section 12.2.3)
//

import CryptoKit
import Foundation
import Security
import SwiftASN1
import X509
import XCTest

@testable import tw2023_wallet

final class SignedMetadataValidatorTests: XCTestCase {

    // Test certificate chain
    var rootPrivateKey: P256.Signing.PrivateKey!
    var intermediatePrivateKey: P256.Signing.PrivateKey!
    var leafPrivateKey: P256.Signing.PrivateKey!

    var rootCertificate: Certificate!
    var intermediateCertificate: Certificate!
    var leafCertificate: Certificate!

    let testIssuerIdentifier = "https://issuer.example.com"

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Generate key pairs
        rootPrivateKey = P256.Signing.PrivateKey()
        intermediatePrivateKey = P256.Signing.PrivateKey()
        leafPrivateKey = P256.Signing.PrivateKey()

        // Generate root CA (self-signed)
        rootCertificate = try generateRootCACertificate(
            privateKey: rootPrivateKey,
            commonName: "Test Root CA"
        )

        // Generate intermediate CA (signed by root)
        intermediateCertificate = try generateIntermediateCACertificate(
            subjectPrivateKey: intermediatePrivateKey,
            issuerPrivateKey: rootPrivateKey,
            issuerCertificate: rootCertificate,
            commonName: "Test Intermediate CA"
        )

        // Generate leaf certificate (signed by intermediate)
        leafCertificate = try generateLeafCertificate(
            subjectPrivateKey: leafPrivateKey,
            issuerPrivateKey: intermediatePrivateKey,
            issuerCertificate: intermediateCertificate,
            commonName: "issuer.example.com"
        )

        // Setup TrustAnchorManager with test certificates
        setupTrustAnchorManager()
    }

    override func tearDownWithError() throws {
        TrustAnchorManager.shared.clear()
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testValidSignedMetadata() async throws {
        let jwt = try createSignedMetadataJwt(
            privateKey: leafPrivateKey,
            certificates: [leafCertificate, intermediateCertificate],
            sub: testIssuerIdentifier,
            iat: Date(),
            exp: Date().addingTimeInterval(3600),
            additionalClaims: [
                "credential_issuer": testIssuerIdentifier,
                "credential_endpoint": "\(testIssuerIdentifier)/credential"
            ]
        )

        let result = await SignedMetadataValidator.validate(
            jwt: jwt,
            expectedIssuerIdentifier: testIssuerIdentifier,
            contextSearchInfos: []
        )

        switch result {
        case .success(let validationResult):
            XCTAssertEqual(validationResult.subject, testIssuerIdentifier)
            XCTAssertNotNil(validationResult.issuedAt)
            XCTAssertNotNil(validationResult.expiresAt)
        case .failure(let error):
            XCTFail("Validation should succeed: \(error)")
        }
    }

    func testInvalidTypHeader() async throws {
        let jwt = try createSignedMetadataJwt(
            privateKey: leafPrivateKey,
            certificates: [leafCertificate, intermediateCertificate],
            sub: testIssuerIdentifier,
            iat: Date(),
            typ: "jwt"  // Invalid typ
        )

        let result = await SignedMetadataValidator.validate(
            jwt: jwt,
            expectedIssuerIdentifier: testIssuerIdentifier,
            contextSearchInfos: []
        )

        switch result {
        case .success:
            XCTFail("Validation should fail with invalid typ")
        case .failure(let error):
            if case .invalidTyp(let typ) = error {
                XCTAssertEqual(typ, "jwt")
            } else {
                XCTFail("Expected invalidTyp error, got: \(error)")
            }
        }
    }

    func testMissingTypHeader() async throws {
        let jwt = try createSignedMetadataJwt(
            privateKey: leafPrivateKey,
            certificates: [leafCertificate, intermediateCertificate],
            sub: testIssuerIdentifier,
            iat: Date(),
            typ: nil  // Missing typ
        )

        let result = await SignedMetadataValidator.validate(
            jwt: jwt,
            expectedIssuerIdentifier: testIssuerIdentifier,
            contextSearchInfos: []
        )

        switch result {
        case .success:
            XCTFail("Validation should fail with missing typ")
        case .failure(let error):
            if case .missingRequiredClaim(let claim) = error {
                XCTAssertEqual(claim, "typ")
            } else {
                XCTFail("Expected missingRequiredClaim error, got: \(error)")
            }
        }
    }

    func testUnsupportedSignatureMethod_Kid() async throws {
        // Create JWT with kid header instead of x5c
        let jwt = try createJwtWithKid(
            privateKey: leafPrivateKey,
            kid: "test-key-id",
            sub: testIssuerIdentifier,
            iat: Date()
        )

        let result = await SignedMetadataValidator.validate(
            jwt: jwt,
            expectedIssuerIdentifier: testIssuerIdentifier,
            contextSearchInfos: []
        )

        switch result {
        case .success:
            XCTFail("Validation should fail with kid (unsupported)")
        case .failure(let error):
            if case .unsupportedSignatureMethod(let method) = error {
                XCTAssertEqual(method, "kid")
            } else {
                XCTFail("Expected unsupportedSignatureMethod error, got: \(error)")
            }
        }
    }

    func testSubjectMismatch() async throws {
        let jwt = try createSignedMetadataJwt(
            privateKey: leafPrivateKey,
            certificates: [leafCertificate, intermediateCertificate],
            sub: "https://other-issuer.example.com",  // Wrong sub
            iat: Date()
        )

        let result = await SignedMetadataValidator.validate(
            jwt: jwt,
            expectedIssuerIdentifier: testIssuerIdentifier,
            contextSearchInfos: []
        )

        switch result {
        case .success:
            XCTFail("Validation should fail with subject mismatch")
        case .failure(let error):
            if case .subjectMismatch(let expected, let actual) = error {
                XCTAssertEqual(expected, testIssuerIdentifier)
                XCTAssertEqual(actual, "https://other-issuer.example.com")
            } else {
                XCTFail("Expected subjectMismatch error, got: \(error)")
            }
        }
    }

    func testMissingSub() async throws {
        let jwt = try createSignedMetadataJwt(
            privateKey: leafPrivateKey,
            certificates: [leafCertificate, intermediateCertificate],
            sub: nil,  // Missing sub
            iat: Date()
        )

        let result = await SignedMetadataValidator.validate(
            jwt: jwt,
            expectedIssuerIdentifier: testIssuerIdentifier,
            contextSearchInfos: []
        )

        switch result {
        case .success:
            XCTFail("Validation should fail with missing sub")
        case .failure(let error):
            if case .missingRequiredClaim(let claim) = error {
                XCTAssertEqual(claim, "sub")
            } else {
                XCTFail("Expected missingRequiredClaim error, got: \(error)")
            }
        }
    }

    func testMissingIat() async throws {
        let jwt = try createSignedMetadataJwt(
            privateKey: leafPrivateKey,
            certificates: [leafCertificate, intermediateCertificate],
            sub: testIssuerIdentifier,
            iat: nil  // Missing iat
        )

        let result = await SignedMetadataValidator.validate(
            jwt: jwt,
            expectedIssuerIdentifier: testIssuerIdentifier,
            contextSearchInfos: []
        )

        switch result {
        case .success:
            XCTFail("Validation should fail with missing iat")
        case .failure(let error):
            if case .missingRequiredClaim(let claim) = error {
                XCTAssertEqual(claim, "iat")
            } else {
                XCTFail("Expected missingRequiredClaim error, got: \(error)")
            }
        }
    }

    func testExpiredMetadata() async throws {
        let jwt = try createSignedMetadataJwt(
            privateKey: leafPrivateKey,
            certificates: [leafCertificate, intermediateCertificate],
            sub: testIssuerIdentifier,
            iat: Date().addingTimeInterval(-7200),  // 2 hours ago
            exp: Date().addingTimeInterval(-3600)   // 1 hour ago (expired)
        )

        let result = await SignedMetadataValidator.validate(
            jwt: jwt,
            expectedIssuerIdentifier: testIssuerIdentifier,
            contextSearchInfos: []
        )

        switch result {
        case .success:
            XCTFail("Validation should fail with expired metadata")
        case .failure(let error):
            if case .expiredMetadata = error {
                // Expected
            } else {
                XCTFail("Expected expiredMetadata error, got: \(error)")
            }
        }
    }

    func testValidMetadataWithoutExp() async throws {
        // exp is OPTIONAL, so this should succeed
        let jwt = try createSignedMetadataJwt(
            privateKey: leafPrivateKey,
            certificates: [leafCertificate, intermediateCertificate],
            sub: testIssuerIdentifier,
            iat: Date(),
            exp: nil  // No expiration
        )

        let result = await SignedMetadataValidator.validate(
            jwt: jwt,
            expectedIssuerIdentifier: testIssuerIdentifier,
            contextSearchInfos: []
        )

        switch result {
        case .success(let validationResult):
            XCTAssertNil(validationResult.expiresAt)
        case .failure(let error):
            XCTFail("Validation should succeed without exp: \(error)")
        }
    }

    func testExtractMetadataJson() throws {
        let payload: [String: Any] = [
            "sub": testIssuerIdentifier,
            "iat": Int(Date().timeIntervalSince1970),
            "credential_issuer": testIssuerIdentifier,
            "credential_endpoint": "\(testIssuerIdentifier)/credential"
        ]

        let jsonData = try SignedMetadataValidator.extractMetadataJson(from: payload)
        let decoded = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any]

        XCTAssertEqual(decoded?["credential_issuer"] as? String, testIssuerIdentifier)
        XCTAssertEqual(decoded?["credential_endpoint"] as? String, "\(testIssuerIdentifier)/credential")
    }

    // MARK: - Certificate Generation Helpers

    private func generateRootCACertificate(
        privateKey: P256.Signing.PrivateKey,
        commonName: String
    ) throws -> Certificate {
        let publicKey = Certificate.PublicKey(privateKey.publicKey)
        let signingKey = Certificate.PrivateKey(privateKey)

        let name = try DistinguishedName {
            CommonName(commonName)
            OrganizationName("Test Organization")
            CountryName("JP")
        }

        let notBefore = Date().addingTimeInterval(-60 * 60)
        let notAfter = Date().addingTimeInterval(60 * 60 * 24 * 365)

        let extensions = try Certificate.Extensions {
            Critical(
                BasicConstraints.isCertificateAuthority(maxPathLength: 1)
            )
            Critical(
                KeyUsage(keyCertSign: true, cRLSign: true)
            )
        }

        return try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: publicKey,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: name,
            subject: name,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions,
            issuerPrivateKey: signingKey
        )
    }

    private func generateIntermediateCACertificate(
        subjectPrivateKey: P256.Signing.PrivateKey,
        issuerPrivateKey: P256.Signing.PrivateKey,
        issuerCertificate: Certificate,
        commonName: String
    ) throws -> Certificate {
        let publicKey = Certificate.PublicKey(subjectPrivateKey.publicKey)
        let signingKey = Certificate.PrivateKey(issuerPrivateKey)

        let subjectName = try DistinguishedName {
            CommonName(commonName)
            OrganizationName("Test Organization")
            CountryName("JP")
        }

        let notBefore = Date().addingTimeInterval(-60 * 60)
        let notAfter = Date().addingTimeInterval(60 * 60 * 24 * 365)

        let extensions = try Certificate.Extensions {
            Critical(
                BasicConstraints.isCertificateAuthority(maxPathLength: 0)
            )
            Critical(
                KeyUsage(keyCertSign: true, cRLSign: true)
            )
        }

        return try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: publicKey,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: issuerCertificate.subject,
            subject: subjectName,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions,
            issuerPrivateKey: signingKey
        )
    }

    private func generateLeafCertificate(
        subjectPrivateKey: P256.Signing.PrivateKey,
        issuerPrivateKey: P256.Signing.PrivateKey,
        issuerCertificate: Certificate,
        commonName: String
    ) throws -> Certificate {
        let publicKey = Certificate.PublicKey(subjectPrivateKey.publicKey)
        let signingKey = Certificate.PrivateKey(issuerPrivateKey)

        let subjectName = try DistinguishedName {
            CommonName(commonName)
            OrganizationName("Test Organization")
            CountryName("JP")
        }

        let notBefore = Date().addingTimeInterval(-60 * 60)
        let notAfter = Date().addingTimeInterval(60 * 60 * 24 * 365)

        let extensions = try Certificate.Extensions {
            Critical(
                BasicConstraints.notCertificateAuthority
            )
            Critical(
                KeyUsage(digitalSignature: true)
            )
            SubjectAlternativeNames([.dnsName(commonName)])
        }

        return try Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: publicKey,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: issuerCertificate.subject,
            subject: subjectName,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions,
            issuerPrivateKey: signingKey
        )
    }

    private func setupTrustAnchorManager() {
        let manager = TrustAnchorManager.shared
        manager.clear()

        // Add root certificate as anchor
        let rootDerData = try! rootCertificate.serializeAsPEM().derBytes
        _ = manager.addAnchorCertificate(derData: Data(rootDerData))

        // Add intermediate certificate
        let intermediateDerData = try! intermediateCertificate.serializeAsPEM().derBytes
        _ = manager.addIntermediateCertificate(derData: Data(intermediateDerData))
    }

    // MARK: - JWT Creation Helpers

    private func createSignedMetadataJwt(
        privateKey: P256.Signing.PrivateKey,
        certificates: [Certificate],
        sub: String?,
        iat: Date?,
        exp: Date? = nil,
        typ: String? = SignedMetadataValidator.expectedTyp,
        additionalClaims: [String: Any] = [:]
    ) throws -> String {
        // Get certificates as base64 array (for x5c header)
        let certBase64Array = try certificates.map { cert -> String in
            let certPem = try cert.serializeAsPEM()
            return Data(certPem.derBytes).base64EncodedString()
        }

        // Create header
        var header: [String: Any] = [
            "alg": "ES256",
            "x5c": certBase64Array
        ]
        if let typ = typ {
            header["typ"] = typ
        }

        // Create payload
        var payload: [String: Any] = additionalClaims
        if let sub = sub {
            payload["sub"] = sub
        }
        if let iat = iat {
            payload["iat"] = Int(iat.timeIntervalSince1970)
        }
        if let exp = exp {
            payload["exp"] = Int(exp.timeIntervalSince1970)
        }

        // Encode header and payload
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        let headerBase64 = headerData.base64URLEncodedString()
        let payloadBase64 = payloadData.base64URLEncodedString()

        let tbsContent = "\(headerBase64).\(payloadBase64)"
        guard let tbsData = tbsContent.data(using: .utf8) else {
            throw NSError(domain: "JWTCreation", code: 1, userInfo: nil)
        }

        // Sign with P256 private key
        let signature = try privateKey.signature(for: tbsData)
        let signatureData = signature.rawRepresentation
        let signatureBase64 = signatureData.base64URLEncodedString()

        return "\(tbsContent).\(signatureBase64)"
    }

    private func createJwtWithKid(
        privateKey: P256.Signing.PrivateKey,
        kid: String,
        sub: String,
        iat: Date
    ) throws -> String {
        // Create header with kid (no x5c)
        let header: [String: Any] = [
            "alg": "ES256",
            "typ": SignedMetadataValidator.expectedTyp,
            "kid": kid
        ]

        // Create payload
        let payload: [String: Any] = [
            "sub": sub,
            "iat": Int(iat.timeIntervalSince1970)
        ]

        // Encode header and payload
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        let headerBase64 = headerData.base64URLEncodedString()
        let payloadBase64 = payloadData.base64URLEncodedString()

        let tbsContent = "\(headerBase64).\(payloadBase64)"
        guard let tbsData = tbsContent.data(using: .utf8) else {
            throw NSError(domain: "JWTCreation", code: 1, userInfo: nil)
        }

        // Sign with P256 private key
        let signature = try privateKey.signature(for: tbsData)
        let signatureData = signature.rawRepresentation
        let signatureBase64 = signatureData.base64URLEncodedString()

        return "\(tbsContent).\(signatureBase64)"
    }
}
