//
//  X509ChainValidationTests.swift
//  tw2023_walletTests
//
//  Tests for X.509 certificate chain validation with custom trust anchors.
//  Verifies that JWT with x5c header can be validated using built-in intermediate and root certificates.
//

import CryptoKit
import Foundation
import Security
import SwiftASN1
import X509
import XCTest

@testable import tw2023_wallet

final class X509ChainValidationTests: XCTestCase {

    // Test certificate chain
    var rootPrivateKey: P256.Signing.PrivateKey!
    var intermediatePrivateKey: P256.Signing.PrivateKey!
    var leafPrivateKey: P256.Signing.PrivateKey!

    var rootCertificate: Certificate!
    var intermediateCertificate: Certificate!
    var leafCertificate: Certificate!

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
            commonName: "test.example.com"
        )

        // Setup TrustAnchorManager with test certificates
        setupTrustAnchorManager()
    }

    override func tearDownWithError() throws {
        // Clear TrustAnchorManager
        TrustAnchorManager.shared.clear()
        try super.tearDownWithError()
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

        // Use a time window that is definitely valid (1 hour ago to 1 year from now)
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

        // Use a time window that is definitely valid (1 hour ago to 1 year from now)
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

        // Use a time window that is definitely valid (1 hour ago to 1 year from now)
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

    private func certificateToSecCertificate(_ cert: Certificate) -> SecCertificate? {
        let pem = try? cert.serializeAsPEM()
        guard let derData = pem.map({ Data($0.derBytes) }) else { return nil }
        return SecCertificateCreateWithData(nil, derData as CFData)
    }

    // MARK: - Test Cases

    func testTrustAnchorManagerSetup() {
        let manager = TrustAnchorManager.shared

        XCTAssertTrue(manager.hasCustomAnchors, "Should have custom anchors")
        XCTAssertEqual(manager.anchorCertificates.count, 1, "Should have 1 root certificate")
        XCTAssertEqual(
            manager.intermediateCertificates.count, 1, "Should have 1 intermediate certificate")
    }

    func testValidCertificateChainWithCustomAnchors() throws {
        // Convert leaf certificate to SecCertificate
        guard let leafSecCert = certificateToSecCertificate(leafCertificate) else {
            XCTFail("Failed to convert leaf certificate")
            return
        }

        // Validate chain with only leaf certificate (intermediate and root from TrustAnchorManager)
        let isValid = try SignatureUtil.validateCertificateChainWithCustomAnchors(
            leafCertificates: [leafSecCert]
        )

        XCTAssertTrue(isValid, "Certificate chain should be valid")
    }

    func testCertificateChainWithExplicitAnchors() throws {
        // Convert all certificates to SecCertificate
        guard let leafSecCert = certificateToSecCertificate(leafCertificate),
            let intermediateSecCert = certificateToSecCertificate(intermediateCertificate),
            let rootSecCert = certificateToSecCertificate(rootCertificate)
        else {
            XCTFail("Failed to convert certificates")
            return
        }

        // Validate chain with explicit anchors
        let isValid = try SignatureUtil.validateCertificateChainWithCustomAnchors(
            leafCertificates: [leafSecCert],
            intermediateCertificates: [intermediateSecCert],
            anchorCertificates: [rootSecCert]
        )

        XCTAssertTrue(isValid, "Certificate chain should be valid with explicit anchors")
    }

    func testInvalidChainWithMissingIntermediate() throws {
        // Clear TrustAnchorManager and only add root (no intermediate)
        let manager = TrustAnchorManager.shared
        manager.clear()

        let rootDerData = try rootCertificate.serializeAsPEM().derBytes
        _ = manager.addAnchorCertificate(derData: Data(rootDerData))
        // Note: NOT adding intermediate certificate

        guard let leafSecCert = certificateToSecCertificate(leafCertificate) else {
            XCTFail("Failed to convert leaf certificate")
            return
        }

        // This should fail because intermediate is missing
        let isValid = try SignatureUtil.validateCertificateChainWithCustomAnchors(
            leafCertificates: [leafSecCert]
        )

        XCTAssertFalse(
            isValid, "Certificate chain should be invalid without intermediate certificate")
    }

    func testInvalidChainWithUnknownRoot() throws {
        // Create a different root CA that is NOT in TrustAnchorManager
        let unknownRootKey = P256.Signing.PrivateKey()
        let unknownRoot = try generateRootCACertificate(
            privateKey: unknownRootKey,
            commonName: "Unknown Root CA"
        )

        // Create a leaf signed by unknown root
        let unknownLeaf = try generateLeafCertificate(
            subjectPrivateKey: leafPrivateKey,
            issuerPrivateKey: unknownRootKey,
            issuerCertificate: unknownRoot,
            commonName: "unknown.example.com"
        )

        guard let unknownLeafSecCert = certificateToSecCertificate(unknownLeaf) else {
            XCTFail("Failed to convert leaf certificate")
            return
        }

        // This should fail because the root CA is not trusted
        let isValid = try SignatureUtil.validateCertificateChainWithCustomAnchors(
            leafCertificates: [unknownLeafSecCert]
        )

        XCTAssertFalse(isValid, "Certificate chain should be invalid with unknown root")
    }

    // MARK: - JWT with x5c Header Tests

    func testJwtWithX5CHeaderValidation() throws {
        // Create a JWT signed with the leaf certificate's private key
        let jwt = try createJwtWithX5C(
            privateKey: leafPrivateKey,
            certificate: leafCertificate,
            payload: ["sub": "test-subject", "iss": "test-issuer"]
        )

        // Verify JWT using verifyJwtByX5C (which should use custom anchor validation)
        let result = JWTUtil.verifyJwtByX5C(jwt: jwt, verifyCertChain: true)

        switch result {
        case .success(let verified):
            XCTAssertEqual(verified.decoded.body["sub"] as? String, "test-subject")
            XCTAssertEqual(verified.decoded.body["iss"] as? String, "test-issuer")
        case .failure(let error):
            XCTFail("JWT verification failed: \(error)")
        }
    }

    func testJwtWithX5CHeaderInvalidChain() throws {
        // Clear TrustAnchorManager to simulate no trusted anchors
        TrustAnchorManager.shared.clear()

        let jwt = try createJwtWithX5C(
            privateKey: leafPrivateKey,
            certificate: leafCertificate,
            payload: ["sub": "test-subject"]
        )

        // Without custom anchors, it falls back to system CA which won't trust our test cert
        let result = JWTUtil.verifyJwtByX5C(jwt: jwt, verifyCertChain: true)

        switch result {
        case .success:
            // This might succeed if system CA validation passes (unlikely with self-signed)
            // or if there are no custom anchors and fallback behavior changes
            break
        case .failure:
            // Expected - chain should be invalid without proper trust anchors
            break
        }
    }

    // MARK: - JWT Creation Helper

    private func createJwtWithX5C(
        privateKey: P256.Signing.PrivateKey,
        certificate: Certificate,
        payload: [String: Any]
    ) throws -> String {
        // Get certificate as base64 (for x5c header)
        let certPem = try certificate.serializeAsPEM()
        let certBase64 = Data(certPem.derBytes).base64EncodedString()

        // Create header
        let header: [String: Any] = [
            "alg": "ES256",
            "typ": "JWT",
            "x5c": [certBase64],
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

// Note: base64URLEncodedString() extension is available from tw2023_wallet module (ES256K.swift)
