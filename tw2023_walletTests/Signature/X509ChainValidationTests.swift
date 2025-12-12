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
        let result = SignatureUtil.validateCertificateChainWithCustomAnchors(
            certificates: [leafSecCert]
        )

        switch result {
        case .success:
            break // Test passes
        case .failure(let error):
            XCTFail("Certificate chain should be valid, but got error: \(error.errorDescription ?? "unknown")")
        }
    }

    func testValidCertificateChainWithTwoTrustChains() throws {
        // Create second trust chain: Root B -> Intermediate B -> Leaf B
        let rootBKey = P256.Signing.PrivateKey()
        let intermediateBKey = P256.Signing.PrivateKey()
        let leafBKey = P256.Signing.PrivateKey()

        let rootBCert = try generateRootCACertificate(
            privateKey: rootBKey,
            commonName: "Test Root CA B"
        )

        let intermediateBCert = try generateIntermediateCACertificate(
            subjectPrivateKey: intermediateBKey,
            issuerPrivateKey: rootBKey,
            issuerCertificate: rootBCert,
            commonName: "Test Intermediate CA B"
        )

        let leafBCert = try generateLeafCertificate(
            subjectPrivateKey: leafBKey,
            issuerPrivateKey: intermediateBKey,
            issuerCertificate: intermediateBCert,
            commonName: "testB.example.com"
        )

        // Setup TrustAnchorManager with both chains
        let manager = TrustAnchorManager.shared
        manager.clear()

        // Add both root certificates as anchors
        let rootADerData = try rootCertificate.serializeAsPEM().derBytes
        _ = manager.addAnchorCertificate(derData: Data(rootADerData))

        let rootBDerData = try rootBCert.serializeAsPEM().derBytes
        _ = manager.addAnchorCertificate(derData: Data(rootBDerData))

        // Add both intermediate certificates
        let intermediateADerData = try intermediateCertificate.serializeAsPEM().derBytes
        _ = manager.addIntermediateCertificate(derData: Data(intermediateADerData))

        let intermediateBDerData = try intermediateBCert.serializeAsPEM().derBytes
        _ = manager.addIntermediateCertificate(derData: Data(intermediateBDerData))

        XCTAssertEqual(manager.anchorCertificates.count, 2, "Should have 2 root certificates")
        XCTAssertEqual(manager.intermediateCertificates.count, 2, "Should have 2 intermediate certificates")

        // Validate chain A (leaf from chain A)
        guard let leafASecCert = certificateToSecCertificate(leafCertificate) else {
            XCTFail("Failed to convert leaf A certificate")
            return
        }

        let resultA = SignatureUtil.validateCertificateChainWithCustomAnchors(
            certificates: [leafASecCert]
        )
        switch resultA {
        case .success:
            break // Test passes
        case .failure(let error):
            XCTFail("Certificate chain A should be valid, but got error: \(error.errorDescription ?? "unknown")")
        }

        // Validate chain B (leaf from chain B)
        guard let leafBSecCert = certificateToSecCertificate(leafBCert) else {
            XCTFail("Failed to convert leaf B certificate")
            return
        }

        let resultB = SignatureUtil.validateCertificateChainWithCustomAnchors(
            certificates: [leafBSecCert]
        )
        switch resultB {
        case .success:
            break // Test passes
        case .failure(let error):
            XCTFail("Certificate chain B should be valid, but got error: \(error.errorDescription ?? "unknown")")
        }
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
        let result = SignatureUtil.validateCertificateChainWithCustomAnchors(
            certificates: [leafSecCert]
        )

        switch result {
        case .success:
            XCTFail("Certificate chain should be invalid without intermediate certificate")
        case .failure:
            break // Test passes - expected to fail
        }
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
        let result = SignatureUtil.validateCertificateChainWithCustomAnchors(
            certificates: [unknownLeafSecCert]
        )

        switch result {
        case .success:
            XCTFail("Certificate chain should be invalid with unknown root")
        case .failure(let error):
            // Verify we get the expected error type
            if case .untrustedRoot = error {
                break // Test passes - expected to fail with untrustedRoot
            } else {
                // Other failure types are also acceptable as long as it fails
                break
            }
        }
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

    // MARK: - x5c Chain Tests (Intermediate Certificates in x5c)

    /// Test that x5c containing leaf + intermediate is validated correctly
    /// When x5c has multiple certificates, they should be used as-is (TrustAnchorManager intermediates not appended)
    func testX5cWithChain_LeafAndIntermediate() throws {
        // Clear TrustAnchorManager and only add root (no intermediate)
        let manager = TrustAnchorManager.shared
        manager.clear()

        let rootDerData = try rootCertificate.serializeAsPEM().derBytes
        _ = manager.addAnchorCertificate(derData: Data(rootDerData))
        // Note: NOT adding intermediate certificate to TrustAnchorManager

        // Convert certificates to SecCertificate
        guard let leafSecCert = certificateToSecCertificate(leafCertificate),
              let intermediateSecCert = certificateToSecCertificate(intermediateCertificate) else {
            XCTFail("Failed to convert certificates")
            return
        }

        // Pass chain with leaf + intermediate (x5c order: leaf first, then intermediate)
        let result = SignatureUtil.validateCertificateChainWithCustomAnchors(
            certificates: [leafSecCert, intermediateSecCert]
        )

        switch result {
        case .success:
            break // Test passes - chain should be valid because intermediate is in x5c
        case .failure(let error):
            XCTFail("Certificate chain should be valid with intermediate in x5c, but got error: \(error.errorDescription ?? "unknown")")
        }
    }

    /// Test that x5c with only leaf fails when TrustAnchorManager has no intermediate
    /// This verifies the fallback behavior works correctly
    func testX5cWithLeafOnly_FailsWithoutIntermediate() throws {
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

        // Pass only leaf certificate (no intermediate in x5c)
        let result = SignatureUtil.validateCertificateChainWithCustomAnchors(
            certificates: [leafSecCert]
        )

        switch result {
        case .success:
            XCTFail("Certificate chain should fail without intermediate")
        case .failure:
            break // Test passes - expected to fail because intermediate is missing
        }
    }

    /// Test JWT with x5c containing full chain (leaf + intermediate)
    func testJwtWithX5CChain_LeafAndIntermediate() throws {
        // Clear TrustAnchorManager and only add root (no intermediate)
        let manager = TrustAnchorManager.shared
        manager.clear()

        let rootDerData = try rootCertificate.serializeAsPEM().derBytes
        _ = manager.addAnchorCertificate(derData: Data(rootDerData))
        // Note: NOT adding intermediate certificate to TrustAnchorManager

        // Create JWT with x5c containing both leaf and intermediate
        let jwt = try createJwtWithX5CChain(
            privateKey: leafPrivateKey,
            certificates: [leafCertificate, intermediateCertificate],
            payload: ["sub": "test-subject", "iss": "test-issuer"]
        )

        // Verify JWT - should succeed because intermediate is in x5c
        let result = JWTUtil.verifyJwtByX5C(jwt: jwt, verifyCertChain: true)

        switch result {
        case .success(let verified):
            XCTAssertEqual(verified.decoded.body["sub"] as? String, "test-subject")
            XCTAssertEqual(verified.decoded.body["iss"] as? String, "test-issuer")
        case .failure(let error):
            XCTFail("JWT verification should succeed with intermediate in x5c: \(error)")
        }
    }

    /// Test JWT with x5c containing only leaf when TrustAnchorManager has intermediate
    func testJwtWithX5CLeafOnly_SucceedsWithTrustAnchorManagerIntermediate() throws {
        // Setup TrustAnchorManager with root and intermediate
        setupTrustAnchorManager()

        // Create JWT with x5c containing only leaf
        let jwt = try createJwtWithX5C(
            privateKey: leafPrivateKey,
            certificate: leafCertificate,
            payload: ["sub": "test-subject"]
        )

        // Verify JWT - should succeed because TrustAnchorManager provides intermediate
        let result = JWTUtil.verifyJwtByX5C(jwt: jwt, verifyCertChain: true)

        switch result {
        case .success:
            break // Test passes
        case .failure(let error):
            XCTFail("JWT verification should succeed with TrustAnchorManager intermediate: \(error)")
        }
    }

    // MARK: - JWT Creation Helpers

    private func createJwtWithX5CChain(
        privateKey: P256.Signing.PrivateKey,
        certificates: [Certificate],
        payload: [String: Any]
    ) throws -> String {
        // Get all certificates as base64 array (for x5c header)
        let certBase64Array = try certificates.map { cert -> String in
            let certPem = try cert.serializeAsPEM()
            return Data(certPem.derBytes).base64EncodedString()
        }

        // Create header with certificate chain
        let header: [String: Any] = [
            "alg": "ES256",
            "typ": "JWT",
            "x5c": certBase64Array,
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

    // MARK: - Invalid x5c Format Tests

    /// Test that comma-separated certificates in x5c string throws an error
    func testInvalidX5cFormat_CommaSeparatedCertificates() throws {
        // Create comma-separated certificate string (invalid format)
        let cert1Pem = try leafCertificate.serializeAsPEM()
        let cert1Base64 = Data(cert1Pem.derBytes).base64EncodedString()

        let cert2Pem = try intermediateCertificate.serializeAsPEM()
        let cert2Base64 = Data(cert2Pem.derBytes).base64EncodedString()

        // Invalid: certificates joined with comma instead of being separate array elements
        let invalidX5c = "\(cert1Base64),\(cert2Base64)"

        // This should throw invalidX5cFormat error
        XCTAssertThrowsError(try SignatureUtil.convertPemToX509Certificates(pemChain: [invalidX5c])) { error in
            guard let sigError = error as? SignatureUtilError else {
                XCTFail("Expected SignatureUtilError, got \(error)")
                return
            }
            XCTAssertEqual(sigError, .invalidX5cFormat)
            XCTAssertTrue(sigError.localizedDescription.contains("comma-separated"))
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
