//
//  PEMUtilsTests.swift
//  tw2023_walletTests
//
//  Tests for PEMUtils - PEM file parsing utilities
//

import XCTest
@testable import tw2023_wallet

final class PEMUtilsTests: XCTestCase {

    // MARK: - Test Data

    /// Valid EC P-256 private key in PKCS#8 format (for testing only)
    private let validPKCS8PrivateKeyPEM = """
-----BEGIN PRIVATE KEY-----
MIGHAgEAMBMGByqGSM49AgEGCCqGSM49AwEHBG0wawIBAQQgJ0K4TM4+M+lA8iCw
TILqwbnM6KMGMdDqP3lKWLcGxcWhRANCAARMgJpqGk8P2lOdKto8bXy9F1k+jS1x
tUIxU3lEb1W8+ZbQFUb8SXriDPb4mXnbHrGJcCZwKJBxVQmz4C4xYmZe
-----END PRIVATE KEY-----
"""

    /// Certificate chain with multiple certificates (leaf + CA)
    private let certificateChainPEM = """
-----BEGIN CERTIFICATE-----
MIIBajCCARCgAwIBAgIULAy96MGgfUBE7H9sEevJm9TYJskwCgYIKoZIzj0EAwIw
EjEQMA4GA1UEAwwHdGVzdC1jYTAeFw0yNjAxMjMwNTQ2MjhaFw0yNzAxMjMwNTQ2
MjhaMBQxEjAQBgNVBAMMCXRlc3QtbGVhZjBZMBMGByqGSM49AgEGCCqGSM49AwEH
A0IABHG8vexXPEq5+2ANRT0i44arIaxXeCvQ1uRaOMT+hIbJ4BbWJBc5WzyCm817
XsnTuHRuDg1d8tTam/mNsSzYHV+jQjBAMB0GA1UdDgQWBBQJy+CSh3HqxQKwo1f+
n/9RYfWjfjAfBgNVHSMEGDAWgBRxQn2xNlUr7u6dUkCW+6LjDvRKADAKBggqhkjO
PQQDAgNIADBFAiABScH1UlxkOQ4kg2KmMzCVAJY9L3fDyn+EQKElQe0tygIhAPSB
tFSyrg/7kXTAUGgysgEXuqLFJKmzpEAuxUQEACti
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
MIIBeTCCAR+gAwIBAgIUeOeKHOSqSiV7z54NCDheq9MTQiQwCgYIKoZIzj0EAwIw
EjEQMA4GA1UEAwwHdGVzdC1jYTAeFw0yNjAxMjMwNTQ2MjhaFw0yNzAxMjMwNTQ2
MjhaMBIxEDAOBgNVBAMMB3Rlc3QtY2EwWTATBgcqhkjOPQIBBggqhkjOPQMBBwNC
AAT8iofMums6u0K0XdZhF6E+5Xgpnf7d8a1z58m/Bj6CDgqG4aBPgWC1itXqX2NM
3aZXOGuU3ZB8knqGu67GF48Oo1MwUTAdBgNVHQ4EFgQUcUJ9sTZVK+7unVJAlvui
4w70SgAwHwYDVR0jBBgwFoAUcUJ9sTZVK+7unVJAlvui4w70SgAwDwYDVR0TAQH/
BAUwAwEB/zAKBggqhkjOPQQDAgNIADBFAiBQEmiIxkd+BlauinjUoIG2sLty7I2r
hQC0O2vxszABYAIhAPWoUpAejHkpuAwielwciOIypbPfgblvAHd7l+zbKnVL
-----END CERTIFICATE-----
"""

    /// Single certificate PEM (valid self-signed EC P-256 certificate for testing)
    private let singleCertificatePEM = """
-----BEGIN CERTIFICATE-----
MIIBfTCCASOgAwIBAgIUR+U7J6Q2gRhjv0nHiE8hBsLGP50wCgYIKoZIzj0EAwIw
FDESMBAGA1UEAwwJdGVzdC1jZXJ0MB4XDTI2MDEyMzA1NDQ1NFoXDTI3MDEyMzA1
NDQ1NFowFDESMBAGA1UEAwwJdGVzdC1jZXJ0MFkwEwYHKoZIzj0CAQYIKoZIzj0D
AQcDQgAELicUNMWd16dD7f9iQKz8QSwtlZF66UpZ+uTeJsbwO4Vtu6/oOKKt1wt7
aIlUHTFmRTs49x2RQezfMduKYspXRaNTMFEwHQYDVR0OBBYEFKfBUkLvPeoNl6W1
tKSuXcolSeoqMB8GA1UdIwQYMBaAFKfBUkLvPeoNl6W1tKSuXcolSeoqMA8GA1Ud
EwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIhANE8XrX+GgY95TgbCeVXrrBQ
Mrk4N+0kja7F8zEXaYZfAiBhNO2m/8rsngb92WHPH9s6uGeyi6cSNHI8ZKW+WJ63
Kg==
-----END CERTIFICATE-----
"""

    /// Invalid PEM data
    private let invalidPEM = """
This is not a valid PEM format
just some random text
"""

    // MARK: - Private Key Tests

    /// Test creating private key from valid PKCS#8 PEM
    func testCreatePrivateKeyFromPKCS8PEM() throws {
        let privateKey = try PEMUtils.createPrivateKey(fromPEM: validPKCS8PrivateKeyPEM)

        XCTAssertNotNil(privateKey, "Should successfully create private key from PKCS#8 PEM")

        // Verify it's an EC key
        let attributes = SecKeyCopyAttributes(privateKey) as? [String: Any]
        XCTAssertEqual(attributes?[kSecAttrKeyType as String] as? String,
                       kSecAttrKeyTypeECSECPrimeRandom as String,
                       "Key type should be EC")
        XCTAssertEqual(attributes?[kSecAttrKeyClass as String] as? String,
                       kSecAttrKeyClassPrivate as String,
                       "Key class should be private")
    }

    /// Test that creating private key from invalid PEM throws error
    func testCreatePrivateKeyFromInvalidPEMThrows() {
        XCTAssertThrowsError(try PEMUtils.createPrivateKey(fromPEM: invalidPEM)) { error in
            XCTAssertTrue(error is PEMUtils.PEMError, "Should throw PEMError")
        }
    }

    /// Test creating private key from empty string throws error
    func testCreatePrivateKeyFromEmptyStringThrows() {
        XCTAssertThrowsError(try PEMUtils.createPrivateKey(fromPEM: "")) { error in
            XCTAssertTrue(error is PEMUtils.PEMError, "Should throw PEMError")
        }
    }

    // MARK: - Certificate Chain Tests (for x5c header)

    /// Test extracting certificate chain from PEM with multiple certificates
    /// This is used to populate the x5c JOSE header in Client Attestation JWT
    func testExtractCertificateChainForX5C() throws {
        let chain = try PEMUtils.extractCertificateChainBase64(from: certificateChainPEM)

        XCTAssertEqual(chain.count, 2, "Should extract 2 certificates from chain (leaf + intermediate)")

        // Verify each certificate is valid base64 (required for x5c header)
        for (index, base64Cert) in chain.enumerated() {
            XCTAssertFalse(base64Cert.isEmpty, "Certificate \(index) should not be empty")
            XCTAssertNotNil(Data(base64Encoded: base64Cert), "Certificate \(index) should be valid base64 for x5c")
        }
    }

    /// Test extracting certificate chain from single certificate
    func testExtractSingleCertificateChain() throws {
        let chain = try PEMUtils.extractCertificateChainBase64(from: singleCertificatePEM)

        XCTAssertEqual(chain.count, 1, "Should extract 1 certificate")
    }

    /// Test that extracting from invalid PEM throws error
    func testExtractCertificateChainFromInvalidPEMThrows() {
        XCTAssertThrowsError(try PEMUtils.extractCertificateChainBase64(from: invalidPEM)) { error in
            XCTAssertTrue(error is PEMUtils.PEMError, "Should throw PEMError")
            if case PEMUtils.PEMError.invalidPEMFormat = error {
                // Expected
            } else {
                XCTFail("Should throw invalidPEMFormat error")
            }
        }
    }

    /// Test that extracted base64 doesn't contain newlines (required for x5c header)
    func testExtractedBase64HasNoNewlines() throws {
        let chain = try PEMUtils.extractCertificateChainBase64(from: certificateChainPEM)

        for base64Cert in chain {
            XCTAssertFalse(base64Cert.contains("\n"), "Base64 for x5c should not contain newlines")
            XCTAssertFalse(base64Cert.contains("\r"), "Base64 for x5c should not contain carriage returns")
        }
    }

    // MARK: - Certificate Creation Tests

    /// Test creating SecCertificate from valid PEM
    func testCreateCertificateFromPEM() throws {
        let certificate = try PEMUtils.createCertificate(fromPEM: singleCertificatePEM)

        XCTAssertNotNil(certificate, "Should successfully create certificate from PEM")

        // Verify certificate has a subject
        let subject = SecCertificateCopySubjectSummary(certificate) as String?
        XCTAssertNotNil(subject, "Certificate should have a subject")
    }

    /// Test that creating certificate from invalid PEM throws error
    func testCreateCertificateFromInvalidPEMThrows() {
        XCTAssertThrowsError(try PEMUtils.createCertificate(fromPEM: invalidPEM)) { error in
            XCTAssertTrue(error is PEMUtils.PEMError, "Should throw PEMError")
        }
    }

    // MARK: - Error Description Tests

    /// Test that PEMError has localized descriptions
    func testPEMErrorDescriptions() {
        let errors: [PEMUtils.PEMError] = [
            .fileNotFound("test.pem"),
            .invalidPEMFormat,
            .keyCreationFailed,
            .certificateCreationFailed,
            .unsupportedKeyFormat
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty")
        }
    }

    /// Test fileNotFound error includes filename
    func testFileNotFoundErrorIncludesFilename() {
        let filename = "missing-file.pem"
        let error = PEMUtils.PEMError.fileNotFound(filename)

        XCTAssertTrue(error.errorDescription?.contains(filename) ?? false,
                      "Error description should include filename")
    }
}
