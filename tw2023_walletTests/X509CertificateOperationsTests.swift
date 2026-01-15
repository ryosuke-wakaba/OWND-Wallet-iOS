//
//  SignatureUtilTests.swift
//  tw2023_walletTests
//
//  Tests for SignatureUtil utility functions
//

import CryptoKit
import Foundation
import XCTest

@testable import tw2023_wallet

final class SignatureUtilTests: XCTestCase {

    // MARK: - extractDERFromPEM Tests

    func testExtractDERFromPEM_validPEM() throws {
        // Create a test certificate using P256 key
        let privateKey = P256.Signing.PrivateKey()
        let certificate = X509CertificateOperations.generateSelfSignedCertificate(
            issuerPrivateKey: privateKey
        )

        // Convert to PEM format
        let pem = X509CertificateOperations.certificateToPem(certificate: certificate, withDelimiters: true)

        // Extract DER from PEM
        let derData = X509CertificateOperations.extractDERFromPEM(pem)

        XCTAssertNotNil(derData, "Should extract DER data from valid PEM")

        // Verify the extracted DER can be used to create a SecCertificate
        if let derData = derData {
            let secCert = SecCertificateCreateWithData(nil, derData as CFData)
            XCTAssertNotNil(secCert, "Extracted DER should create valid SecCertificate")
        }
    }

    func testExtractDERFromPEM_validPEMWithWhitespace() throws {
        // Create a PEM with extra whitespace and newlines
        let privateKey = P256.Signing.PrivateKey()
        let certificate = X509CertificateOperations.generateSelfSignedCertificate(
            issuerPrivateKey: privateKey
        )

        let basePem = X509CertificateOperations.certificateToPem(certificate: certificate, withDelimiters: true)

        // Add extra whitespace
        let pemWithWhitespace = "\n  \n" + basePem + "\n  \n"

        let derData = X509CertificateOperations.extractDERFromPEM(pemWithWhitespace)

        XCTAssertNotNil(derData, "Should extract DER data from PEM with extra whitespace")
    }

    func testExtractDERFromPEM_invalidFormat_noMarkers() {
        // Test with string that has no PEM markers
        let invalidPem = "This is not a PEM certificate"

        let derData = X509CertificateOperations.extractDERFromPEM(invalidPem)

        XCTAssertNil(derData, "Should return nil for string without PEM markers")
    }

    func testExtractDERFromPEM_invalidFormat_onlyBeginMarker() {
        // Test with only BEGIN marker
        let invalidPem = "-----BEGIN CERTIFICATE-----\nSomeBase64Data"

        let derData = X509CertificateOperations.extractDERFromPEM(invalidPem)

        XCTAssertNil(derData, "Should return nil for PEM with only BEGIN marker")
    }

    func testExtractDERFromPEM_invalidFormat_onlyEndMarker() {
        // Test with only END marker
        let invalidPem = "SomeBase64Data\n-----END CERTIFICATE-----"

        let derData = X509CertificateOperations.extractDERFromPEM(invalidPem)

        XCTAssertNil(derData, "Should return nil for PEM with only END marker")
    }

    func testExtractDERFromPEM_emptyString() {
        let derData = X509CertificateOperations.extractDERFromPEM("")

        XCTAssertNil(derData, "Should return nil for empty string")
    }

    func testExtractDERFromPEM_emptyContent() {
        // Test with markers but empty content between them
        let emptyContentPem = "-----BEGIN CERTIFICATE-----\n-----END CERTIFICATE-----"

        let derData = X509CertificateOperations.extractDERFromPEM(emptyContentPem)

        // Empty base64 string returns empty Data, not nil
        // This tests that the function handles this edge case
        XCTAssertNotNil(derData, "Should return empty Data for empty content")
        XCTAssertEqual(derData?.count, 0, "Data should be empty")
    }

    func testExtractDERFromPEM_invalidBase64() {
        // Test with invalid base64 content
        let invalidBase64Pem = """
        -----BEGIN CERTIFICATE-----
        This is not valid base64!!!@@@
        -----END CERTIFICATE-----
        """

        let derData = X509CertificateOperations.extractDERFromPEM(invalidBase64Pem)

        XCTAssertNil(derData, "Should return nil for invalid base64 content")
    }

    func testExtractDERFromPEM_pemWithCarriageReturns() throws {
        // Create a PEM with Windows-style line endings (CRLF)
        let privateKey = P256.Signing.PrivateKey()
        let certificate = X509CertificateOperations.generateSelfSignedCertificate(
            issuerPrivateKey: privateKey
        )

        let basePem = X509CertificateOperations.certificateToPem(certificate: certificate, withDelimiters: true)

        // Convert to Windows-style line endings
        let pemWithCRLF = basePem.replacingOccurrences(of: "\n", with: "\r\n")

        let derData = X509CertificateOperations.extractDERFromPEM(pemWithCRLF)

        XCTAssertNotNil(derData, "Should extract DER data from PEM with CRLF line endings")

        // Verify the extracted DER can be used to create a SecCertificate
        if let derData = derData {
            let secCert = SecCertificateCreateWithData(nil, derData as CFData)
            XCTAssertNotNil(secCert, "Extracted DER should create valid SecCertificate")
        }
    }

    // MARK: - base64UrlDecoded Tests

    func testBase64UrlDecoded_validBase64Url() {
        // Standard base64: "Hello World" = "SGVsbG8gV29ybGQ="
        // base64url uses - instead of + and _ instead of /
        let base64Url = "SGVsbG8gV29ybGQ"  // Without padding

        let decoded = base64Url.base64UrlDecoded()

        XCTAssertNotNil(decoded)
        if let decoded = decoded {
            let string = String(data: decoded, encoding: .utf8)
            XCTAssertEqual(string, "Hello World")
        }
    }

    func testBase64UrlDecoded_withSpecialChars() {
        // Test with base64url special characters (- and _)
        // These would be + and / in standard base64
        let base64Url = "PDw_Pz4-"  // "<<??>>>" in base64url

        let decoded = base64Url.base64UrlDecoded()

        XCTAssertNotNil(decoded, "Should decode base64url with special characters")
    }

    func testBase64UrlDecoded_requiresPadding() {
        // Test string that requires padding
        let base64Url = "YQ"  // "a" - requires 2 padding chars

        let decoded = base64Url.base64UrlDecoded()

        XCTAssertNotNil(decoded)
        if let decoded = decoded {
            let string = String(data: decoded, encoding: .utf8)
            XCTAssertEqual(string, "a")
        }
    }
}
