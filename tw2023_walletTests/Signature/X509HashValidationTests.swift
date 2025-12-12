//
//  X509HashValidationTests.swift
//  tw2023_walletTests
//
//  Tests for x509_hash Client Identifier Prefix validation (OID4VP 1.0).
//  Verifies SHA-256 hash calculation of X.509 certificates and client_id matching.
//

import CryptoKit
import Foundation
import SwiftASN1
import X509
import XCTest

@testable import tw2023_wallet

final class X509HashValidationTests: XCTestCase {

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

        let rootDerData = try! rootCertificate.serializeAsPEM().derBytes
        _ = manager.addAnchorCertificate(derData: Data(rootDerData))

        let intermediateDerData = try! intermediateCertificate.serializeAsPEM().derBytes
        _ = manager.addIntermediateCertificate(derData: Data(intermediateDerData))
    }

    // MARK: - calculateX509CertificateHash Tests

    func testCalculateX509CertificateHash_ReturnsValidBase64UrlString() throws {
        // Test that calculateX509CertificateHash returns a valid Base64URL string
        let hash = calculateX509CertificateHash(leafCertificate)

        XCTAssertNotNil(hash, "Hash should not be nil")

        // Base64URL should only contain alphanumeric, '-', and '_' (no '+', '/', or '=')
        let base64UrlPattern = "^[A-Za-z0-9_-]+$"
        let regex = try NSRegularExpression(pattern: base64UrlPattern)
        let range = NSRange(hash!.startIndex..., in: hash!)
        let matches = regex.numberOfMatches(in: hash!, range: range)

        XCTAssertEqual(matches, 1, "Hash should be valid Base64URL format")
    }

    func testCalculateX509CertificateHash_ReturnsCorrectLength() throws {
        // SHA-256 produces 32 bytes, which becomes 43 characters in Base64URL (no padding)
        let hash = calculateX509CertificateHash(leafCertificate)

        XCTAssertNotNil(hash, "Hash should not be nil")
        XCTAssertEqual(hash!.count, 43, "SHA-256 Base64URL hash should be 43 characters")
    }

    func testCalculateX509CertificateHash_IsDeterministic() throws {
        // Same certificate should always produce the same hash
        let hash1 = calculateX509CertificateHash(leafCertificate)
        let hash2 = calculateX509CertificateHash(leafCertificate)

        XCTAssertNotNil(hash1, "First hash should not be nil")
        XCTAssertNotNil(hash2, "Second hash should not be nil")
        XCTAssertEqual(hash1, hash2, "Same certificate should produce identical hash")
    }

    func testCalculateX509CertificateHash_DifferentCertificatesProduceDifferentHashes() throws {
        // Different certificates should produce different hashes
        let leafHash = calculateX509CertificateHash(leafCertificate)
        let intermediateHash = calculateX509CertificateHash(intermediateCertificate)
        let rootHash = calculateX509CertificateHash(rootCertificate)

        XCTAssertNotNil(leafHash, "Leaf hash should not be nil")
        XCTAssertNotNil(intermediateHash, "Intermediate hash should not be nil")
        XCTAssertNotNil(rootHash, "Root hash should not be nil")

        XCTAssertNotEqual(leafHash, intermediateHash, "Leaf and intermediate should have different hashes")
        XCTAssertNotEqual(leafHash, rootHash, "Leaf and root should have different hashes")
        XCTAssertNotEqual(intermediateHash, rootHash, "Intermediate and root should have different hashes")
    }

    func testCalculateX509CertificateHash_NoBase64Padding() throws {
        // Base64URL should not contain padding characters
        let hash = calculateX509CertificateHash(leafCertificate)

        XCTAssertNotNil(hash, "Hash should not be nil")
        XCTAssertFalse(hash!.contains("="), "Base64URL hash should not contain padding")
    }

    func testCalculateX509CertificateHash_NoStandardBase64Characters() throws {
        // Base64URL should not contain '+' or '/'
        let hash = calculateX509CertificateHash(leafCertificate)

        XCTAssertNotNil(hash, "Hash should not be nil")
        XCTAssertFalse(hash!.contains("+"), "Base64URL hash should not contain '+'")
        XCTAssertFalse(hash!.contains("/"), "Base64URL hash should not contain '/'")
    }

    // MARK: - x509_hash Client ID Validation Tests
    // Tests for validateX509HashClientId() in CertificateUtil.swift

    func testValidateX509Hash_ValidClientId() throws {
        // Calculate the correct hash from the leaf certificate
        let correctHash = calculateX509CertificateHash(leafCertificate)!
        let clientId = "x509_hash:\(correctHash)"

        // Validate using production code - should succeed
        let result = tw2023_wallet.validateX509HashClientId(clientId: clientId, certificates: [leafCertificate])
        XCTAssertTrue(result.isSuccess, "Validation should succeed for matching hash")
        XCTAssertNil(result.errorMessage, "Error message should be nil on success")
    }

    func testValidateX509Hash_WrongHash() throws {
        // Use a hash from a different certificate (intermediate instead of leaf)
        let wrongHash = calculateX509CertificateHash(intermediateCertificate)!
        let clientId = "x509_hash:\(wrongHash)"

        // Validate with leaf certificate - should fail because hash is from intermediate
        let result = tw2023_wallet.validateX509HashClientId(clientId: clientId, certificates: [leafCertificate])
        XCTAssertFalse(result.isSuccess, "Validation should fail for mismatched hash")

        if case .hashMismatch(let expected, let actual) = result {
            XCTAssertEqual(expected, wrongHash, "Expected hash should be from client_id")
            XCTAssertEqual(actual, calculateX509CertificateHash(leafCertificate), "Actual hash should be from certificate")
        } else {
            XCTFail("Expected hashMismatch result, got: \(result)")
        }
    }

    func testValidateX509Hash_TamperedHash() throws {
        // Calculate correct hash and tamper with it
        let correctHash = calculateX509CertificateHash(leafCertificate)!
        let tamperedHash = "X" + String(correctHash.dropFirst()) // Replace first character
        let clientId = "x509_hash:\(tamperedHash)"

        // Validate - should fail with hashMismatch
        let result = tw2023_wallet.validateX509HashClientId(clientId: clientId, certificates: [leafCertificate])
        XCTAssertFalse(result.isSuccess, "Validation should fail for tampered hash")

        if case .hashMismatch = result {
            // Expected
        } else {
            XCTFail("Expected hashMismatch result, got: \(result)")
        }
    }

    func testValidateX509Hash_WrongPrefix() throws {
        let hash = calculateX509CertificateHash(leafCertificate)!

        // Test with wrong prefix
        let clientIdSanDns = "x509_san_dns:\(hash)"
        let result1 = tw2023_wallet.validateX509HashClientId(clientId: clientIdSanDns, certificates: [leafCertificate])
        if case .invalidPrefix = result1 {
            // Expected
        } else {
            XCTFail("Should return invalidPrefix for x509_san_dns prefix, got: \(result1)")
        }

        // Test with no prefix
        let clientIdNoPrefix = hash
        let result2 = tw2023_wallet.validateX509HashClientId(clientId: clientIdNoPrefix, certificates: [leafCertificate])
        if case .invalidPrefix = result2 {
            // Expected
        } else {
            XCTFail("Should return invalidPrefix for client_id without prefix, got: \(result2)")
        }
    }

    func testValidateX509Hash_EmptyCertificates() throws {
        let hash = calculateX509CertificateHash(leafCertificate)!
        let clientId = "x509_hash:\(hash)"

        // Validate with empty certificate list - should fail
        let result = tw2023_wallet.validateX509HashClientId(clientId: clientId, certificates: [])
        if case .noCertificates = result {
            // Expected
        } else {
            XCTFail("Should return noCertificates for empty certificate list, got: \(result)")
        }
    }

    // MARK: - JWT with x5c Header Integration Tests

    func testJwtX5cIntegration_ValidClientId() throws {
        // Create JWT signed with leaf certificate
        let jwt = try createJwtWithX5C(
            privateKey: leafPrivateKey,
            certificate: leafCertificate,
            payload: ["sub": "test-subject", "client_id": "x509_hash:placeholder"]
        )

        // Verify JWT and get certificates
        let jwtResult = JWTUtil.verifyJwtByX5C(jwt: jwt, verifyCertChain: true)

        switch jwtResult {
        case .success(let verified):
            // Create client_id with correct hash
            let correctHash = calculateX509CertificateHash(verified.certs[0])!
            let clientId = "x509_hash:\(correctHash)"

            // Validate using production code - should succeed
            let result = tw2023_wallet.validateX509HashClientId(clientId: clientId, certificates: verified.certs)
            XCTAssertTrue(result.isSuccess, "Validation should succeed for JWT certificate matching client_id hash")

        case .failure(let error):
            XCTFail("JWT verification failed: \(error)")
        }
    }

    func testJwtX5cIntegration_AttackerCertificate() throws {
        // Simulate attack: attacker creates JWT with their own certificate
        // but uses client_id hash from legitimate certificate

        // Create JWT with attacker's certificate (using intermediate as "attacker's cert")
        let attackerJwt = try createJwtWithX5C(
            privateKey: intermediatePrivateKey,
            certificate: intermediateCertificate,
            payload: ["sub": "attacker"]
        )

        // Legitimate client_id uses leaf certificate hash
        let legitimateHash = calculateX509CertificateHash(leafCertificate)!
        let clientId = "x509_hash:\(legitimateHash)"

        // Verify attacker's JWT
        let jwtResult = JWTUtil.verifyJwtByX5C(jwt: attackerJwt, verifyCertChain: true)

        switch jwtResult {
        case .success(let verified):
            // Validation should fail because certificate in JWT doesn't match client_id hash
            let result = tw2023_wallet.validateX509HashClientId(clientId: clientId, certificates: verified.certs)
            XCTAssertFalse(result.isSuccess, "Should detect certificate mismatch - attacker's cert doesn't match client_id")

            if case .hashMismatch(let expected, let actual) = result {
                XCTAssertEqual(expected, legitimateHash, "Expected should be legitimate hash")
                XCTAssertNotEqual(actual, legitimateHash, "Actual should be attacker's cert hash")
            } else {
                XCTFail("Expected hashMismatch result, got: \(result)")
            }

        case .failure(let error):
            XCTFail("JWT verification failed: \(error)")
        }
    }

    // MARK: - isDomainInSAN Tests (for x509_san_dns validation)

    func testIsDomainInSAN_MatchingDomain() throws {
        // leafCertificate has SAN entry for "test.example.com"
        let result = isDomainInSAN(certificate: leafCertificate, domain: "test.example.com")
        XCTAssertTrue(result, "Domain should be found in SAN")
    }

    func testIsDomainInSAN_NonMatchingDomain() throws {
        let result = isDomainInSAN(certificate: leafCertificate, domain: "other.example.com")
        XCTAssertFalse(result, "Non-matching domain should not be found in SAN")
    }

    func testIsDomainInSAN_SubdomainMismatch() throws {
        // Should not match subdomain
        let result = isDomainInSAN(certificate: leafCertificate, domain: "sub.test.example.com")
        XCTAssertFalse(result, "Subdomain should not match exact SAN entry")
    }

    func testIsDomainInSAN_ParentDomainMismatch() throws {
        // Should not match parent domain
        let result = isDomainInSAN(certificate: leafCertificate, domain: "example.com")
        XCTAssertFalse(result, "Parent domain should not match SAN entry")
    }

    // MARK: - JWT Creation Helper

    private func createJwtWithX5C(
        privateKey: P256.Signing.PrivateKey,
        certificate: Certificate,
        payload: [String: Any]
    ) throws -> String {
        let certPem = try certificate.serializeAsPEM()
        let certBase64 = Data(certPem.derBytes).base64EncodedString()

        let header: [String: Any] = [
            "alg": "ES256",
            "typ": "JWT",
            "x5c": [certBase64],
        ]

        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        let headerBase64 = headerData.base64URLEncodedString()
        let payloadBase64 = payloadData.base64URLEncodedString()

        let tbsContent = "\(headerBase64).\(payloadBase64)"
        guard let tbsData = tbsContent.data(using: .utf8) else {
            throw NSError(domain: "JWTCreation", code: 1, userInfo: nil)
        }

        let signature = try privateKey.signature(for: tbsData)
        let signatureData = signature.rawRepresentation
        let signatureBase64 = signatureData.base64URLEncodedString()

        return "\(tbsContent).\(signatureBase64)"
    }
}
