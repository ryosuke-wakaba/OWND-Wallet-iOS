//
//  JAdESSignatureVerifierTests.swift
//  tw2023_walletTests
//
//  Tests for JAdES Baseline-B signature verification.
//

import CryptoKit
import Foundation
import SwiftASN1
import X509
import XCTest

@testable import tw2023_wallet

final class JAdESSignatureVerifierTests: XCTestCase {

    // Test key pairs and certificates
    var signingPrivateKey: P256.Signing.PrivateKey!
    var signingCertificate: Certificate!
    var signingSecCertificate: SecCertificate!

    override func setUpWithError() throws {
        try super.setUpWithError()

        // Generate signing key pair
        signingPrivateKey = P256.Signing.PrivateKey()

        // Generate self-signed certificate for testing
        signingCertificate = try generateSelfSignedCertificate(
            privateKey: signingPrivateKey,
            commonName: "JAdES Test Signer"
        )

        // Convert to SecCertificate
        let derBytes = try signingCertificate.serializeAsPEM().derBytes
        signingSecCertificate = SecCertificateCreateWithData(nil, Data(derBytes) as CFData)!
    }

    override func tearDownWithError() throws {
        signingPrivateKey = nil
        signingCertificate = nil
        signingSecCertificate = nil
        try super.tearDownWithError()
    }

    // MARK: - Date Formatting Helpers

    private func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter.string(from: date)
    }

    // MARK: - Certificate Generation Helpers

    private func generateSelfSignedCertificate(
        privateKey: P256.Signing.PrivateKey,
        commonName: String,
        notBefore: Date = Date().addingTimeInterval(-60 * 60),
        notAfter: Date = Date().addingTimeInterval(60 * 60 * 24 * 365)
    ) throws -> Certificate {
        let publicKey = Certificate.PublicKey(privateKey.publicKey)
        let signingKey = Certificate.PrivateKey(privateKey)

        let name = try DistinguishedName {
            CommonName(commonName)
            OrganizationName("Test Organization")
            CountryName("JP")
        }

        let extensions = try Certificate.Extensions {
            Critical(
                BasicConstraints.notCertificateAuthority
            )
            Critical(
                KeyUsage(digitalSignature: true)
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

    // MARK: - JWT Generation Helpers

    /// Calculate certificate thumbprint (SHA-256, Base64URL)
    private func calculateCertificateThumbprint(_ certificate: SecCertificate) -> String {
        let derData = SecCertificateCopyData(certificate) as Data
        let hash = SHA256.hash(data: derData)
        return Data(hash).base64URLEncodedString()
    }

    /// Create a JAdES-signed JWT with all required headers
    private func createJAdESJWT(
        payload: [String: Any],
        sigT: String? = nil,
        x5tS256: String? = nil,
        includeCrit: Bool = true,
        includeX5c: Bool = true
    ) throws -> String {
        var header: [String: Any] = [
            "alg": "ES256",
            "typ": "JWT"
        ]

        // Add x5c (certificate chain)
        if includeX5c {
            let certDerBytes = try signingCertificate.serializeAsPEM().derBytes
            let certBase64 = Data(certDerBytes).base64EncodedString()
            header["x5c"] = [certBase64]
        }

        // Add sigT (signing time)
        if let sigT = sigT {
            header["sigT"] = sigT
        }

        // Add x5t#S256 (certificate thumbprint)
        if let x5tS256 = x5tS256 {
            header["x5t#S256"] = x5tS256
        }

        // Add crit header
        if includeCrit {
            var critHeaders: [String] = []
            if sigT != nil { critHeaders.append("sigT") }
            if x5tS256 != nil { critHeaders.append("x5t#S256") }
            if !critHeaders.isEmpty {
                header["crit"] = critHeaders
            }
        }

        // Encode header and payload
        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: payload)

        let encodedHeader = headerData.base64URLEncodedString()
        let encodedPayload = payloadData.base64URLEncodedString()

        // Create signature
        let tbsContent = "\(encodedHeader).\(encodedPayload)"
        let signature = try signingPrivateKey.signature(for: tbsContent.data(using: .utf8)!)

        // Convert signature to raw format (r || s)
        let rawSignature = signature.rawRepresentation
        let encodedSignature = rawSignature.base64URLEncodedString()

        return "\(encodedHeader).\(encodedPayload).\(encodedSignature)"
    }

    /// Create a valid JAdES JWT with current time
    private func createValidJAdESJWT(payload: [String: Any] = ["test": "data"]) throws -> String {
        let sigT = formatISO8601(Date())
        let x5tS256 = calculateCertificateThumbprint(signingSecCertificate)

        return try createJAdESJWT(
            payload: payload,
            sigT: sigT,
            x5tS256: x5tS256
        )
    }

    // MARK: - sigT Validation Tests

    func testSigT_WhenMissing_ReturnsError() throws {
        let x5tS256 = calculateCertificateThumbprint(signingSecCertificate)
        let jwt = try createJAdESJWT(
            payload: ["test": "data"],
            sigT: nil,
            x5tS256: x5tS256,
            includeCrit: false
        )

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch result {
        case .success:
            XCTFail("Should fail with sigTMissing error")
        case .failure(let error):
            if case .sigTMissing = error {
                // Expected
            } else {
                XCTFail("Expected sigTMissing error, got: \(error)")
            }
        }
    }

    func testSigT_WhenInvalidFormat_ReturnsError() throws {
        let x5tS256 = calculateCertificateThumbprint(signingSecCertificate)
        let jwt = try createJAdESJWT(
            payload: ["test": "data"],
            sigT: "invalid-date-format",
            x5tS256: x5tS256,
            includeCrit: false
        )

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch result {
        case .success:
            XCTFail("Should fail with sigTInvalidFormat error")
        case .failure(let error):
            if case .sigTInvalidFormat = error {
                // Expected
            } else {
                XCTFail("Expected sigTInvalidFormat error, got: \(error)")
            }
        }
    }

    func testSigT_WhenInFuture_ReturnsError() throws {
        let futureDate = Date().addingTimeInterval(60 * 60)  // 1 hour in future
        let sigT = formatISO8601(futureDate)
        let x5tS256 = calculateCertificateThumbprint(signingSecCertificate)

        let jwt = try createJAdESJWT(
            payload: ["test": "data"],
            sigT: sigT,
            x5tS256: x5tS256,
            includeCrit: false
        )

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch result {
        case .success:
            XCTFail("Should fail with sigTInFuture error")
        case .failure(let error):
            if case .sigTInFuture = error {
                // Expected
            } else {
                XCTFail("Expected sigTInFuture error, got: \(error)")
            }
        }
    }

    func testSigT_WhenWithinTolerance_Succeeds() throws {
        // 3 minutes in future (within 5 minute tolerance)
        let futureDate = Date().addingTimeInterval(3 * 60)
        let sigT = formatISO8601(futureDate)
        let x5tS256 = calculateCertificateThumbprint(signingSecCertificate)

        let jwt = try createJAdESJWT(
            payload: ["test": "data"],
            sigT: sigT,
            x5tS256: x5tS256,
            includeCrit: false
        )

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch result {
        case .success:
            // Expected
            break
        case .failure(let error):
            XCTFail("Should succeed, got error: \(error)")
        }
    }

    func testSigT_WhenOutsideCertValidity_ReturnsError() throws {
        // Create certificate valid from 1 day ago to 1 hour ago
        let expiredCertPrivateKey = P256.Signing.PrivateKey()
        let expiredCert = try generateSelfSignedCertificate(
            privateKey: expiredCertPrivateKey,
            commonName: "Expired Cert",
            notBefore: Date().addingTimeInterval(-24 * 60 * 60),
            notAfter: Date().addingTimeInterval(-60 * 60)
        )

        let expiredSecCert = SecCertificateCreateWithData(
            nil,
            Data(try expiredCert.serializeAsPEM().derBytes) as CFData
        )!

        // sigT is now (outside cert validity)
        let sigT = formatISO8601(Date())
        let x5tS256 = calculateCertificateThumbprint(expiredSecCert)

        // Need to recreate signing key for this certificate
        signingPrivateKey = expiredCertPrivateKey
        signingCertificate = expiredCert

        let jwt = try createJAdESJWT(
            payload: ["test": "data"],
            sigT: sigT,
            x5tS256: x5tS256,
            includeCrit: false
        )

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: expiredSecCert,
            options: .default
        )

        switch result {
        case .success:
            XCTFail("Should fail with sigTOutsideCertificateValidity error")
        case .failure(let error):
            if case .sigTOutsideCertificateValidity = error {
                // Expected
            } else {
                XCTFail("Expected sigTOutsideCertificateValidity error, got: \(error)")
            }
        }
    }

    // MARK: - x5t#S256 Validation Tests

    func testX5tS256_WhenMissing_ReturnsError() throws {
        let sigT = formatISO8601(Date())
        let jwt = try createJAdESJWT(
            payload: ["test": "data"],
            sigT: sigT,
            x5tS256: nil,
            includeCrit: false
        )

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch result {
        case .success:
            XCTFail("Should fail with x5tS256Missing error")
        case .failure(let error):
            if case .x5tS256Missing = error {
                // Expected
            } else {
                XCTFail("Expected x5tS256Missing error, got: \(error)")
            }
        }
    }

    func testX5tS256_WhenMismatch_ReturnsError() throws {
        let sigT = formatISO8601(Date())
        let wrongThumbprint = "wrongThumbprintValue123456789012345678901234"

        let jwt = try createJAdESJWT(
            payload: ["test": "data"],
            sigT: sigT,
            x5tS256: wrongThumbprint,
            includeCrit: false
        )

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch result {
        case .success:
            XCTFail("Should fail with x5tS256Mismatch error")
        case .failure(let error):
            if case .x5tS256Mismatch = error {
                // Expected
            } else {
                XCTFail("Expected x5tS256Mismatch error, got: \(error)")
            }
        }
    }

    func testX5tS256_WhenValid_Succeeds() throws {
        let jwt = try createValidJAdESJWT()

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch result {
        case .success(let verificationResult):
            XCTAssertFalse(verificationResult.certificateThumbprint.isEmpty)
        case .failure(let error):
            XCTFail("Should succeed, got error: \(error)")
        }
    }

    // MARK: - Signature Verification Tests

    func testSignature_WhenValid_Succeeds() throws {
        let jwt = try createValidJAdESJWT()

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch result {
        case .success:
            // Expected
            break
        case .failure(let error):
            XCTFail("Should succeed, got error: \(error)")
        }
    }

    func testSignature_WhenTampered_ReturnsError() throws {
        let jwt = try createValidJAdESJWT()

        // Tamper with the JWT by modifying a character in the signature
        let parts = jwt.components(separatedBy: ".")
        guard parts.count == 3 else {
            XCTFail("Invalid JWT format")
            return
        }

        // Modify signature (replace a character to invalidate it)
        var tamperedSignature = parts[2]
        // Find a base64url-safe character to replace
        if tamperedSignature.contains("A") {
            tamperedSignature = tamperedSignature.replacingOccurrences(of: "A", with: "B")
        } else if tamperedSignature.contains("a") {
            tamperedSignature = tamperedSignature.replacingOccurrences(of: "a", with: "b")
        } else {
            // Append an extra character
            tamperedSignature = tamperedSignature + "A"
        }
        let tamperedJwt = "\(parts[0]).\(parts[1]).\(tamperedSignature)"

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: tamperedJwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch result {
        case .success:
            XCTFail("Should fail with signatureVerificationFailed error")
        case .failure(let error):
            if case .signatureVerificationFailed = error {
                // Expected
            } else {
                XCTFail("Expected signatureVerificationFailed error, got: \(error)")
            }
        }
    }

    // MARK: - crit Header Tests

    func testCrit_WhenUnprocessedHeader_ReturnsError() throws {
        let sigT = formatISO8601(Date())
        let x5tS256 = calculateCertificateThumbprint(signingSecCertificate)

        // Create JWT with unsupported critical header
        var header: [String: Any] = [
            "alg": "ES256",
            "typ": "JWT",
            "sigT": sigT,
            "x5t#S256": x5tS256,
            "crit": ["sigT", "x5t#S256", "unknownHeader"],  // Add unsupported header
            "unknownHeader": "someValue"
        ]

        let certDerBytes = try signingCertificate.serializeAsPEM().derBytes
        let certBase64 = Data(certDerBytes).base64EncodedString()
        header["x5c"] = [certBase64]

        let headerData = try JSONSerialization.data(withJSONObject: header)
        let payloadData = try JSONSerialization.data(withJSONObject: ["test": "data"])

        let encodedHeader = headerData.base64URLEncodedString()
        let encodedPayload = payloadData.base64URLEncodedString()

        let tbsContent = "\(encodedHeader).\(encodedPayload)"
        let signature = try signingPrivateKey.signature(for: tbsContent.data(using: .utf8)!)
        let encodedSignature = signature.rawRepresentation.base64URLEncodedString()

        let jwt = "\(encodedHeader).\(encodedPayload).\(encodedSignature)"

        let result = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch result {
        case .success:
            XCTFail("Should fail with criticalHeaderNotProcessed error")
        case .failure(let error):
            if case .criticalHeaderNotProcessed(let header) = error {
                XCTAssertEqual(header, "unknownHeader")
            } else {
                XCTFail("Expected criticalHeaderNotProcessed error, got: \(error)")
            }
        }
    }

    // MARK: - Full Integration Tests

    func testFullJAdESVerification_WithValidJwt_Succeeds() throws {
        let payload: [String: Any] = [
            "LoTE": [
                "TrustedEntitiesList": []
            ]
        ]

        let jwt = try createValidJAdESJWT(payload: payload)

        let result = JAdESSignatureVerifier.verifyJAdES(jwt: jwt, options: .default)

        switch result {
        case .success(let verificationResult):
            XCTAssertFalse(verificationResult.payload.isEmpty)
            XCTAssertFalse(verificationResult.certificateThumbprint.isEmpty)
        case .failure(let error):
            XCTFail("Should succeed, got error: \(error)")
        }
    }

    // MARK: - Options Tests

    func testOptions_LenientMode_AcceptsLargerSkew() throws {
        // 8 minutes in future (beyond default 5 minute tolerance, within lenient 10 minute)
        let futureDate = Date().addingTimeInterval(8 * 60)
        let sigT = formatISO8601(futureDate)
        let x5tS256 = calculateCertificateThumbprint(signingSecCertificate)

        let jwt = try createJAdESJWT(
            payload: ["test": "data"],
            sigT: sigT,
            x5tS256: x5tS256,
            includeCrit: false
        )

        // Should fail with default options
        let defaultResult = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .default
        )

        switch defaultResult {
        case .success:
            XCTFail("Default options should reject 8-minute future sigT")
        case .failure(let error):
            if case .sigTInFuture = error {
                // Expected
            } else {
                XCTFail("Expected sigTInFuture error for default options")
            }
        }

        // Should succeed with lenient options
        let lenientResult = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: signingSecCertificate,
            options: .lenient
        )

        switch lenientResult {
        case .success:
            // Expected
            break
        case .failure(let error):
            XCTFail("Lenient options should accept 8-minute future sigT, got: \(error)")
        }
    }

    func testOptions_DisableCertValidityCheck() throws {
        // Create certificate that expired 1 hour ago
        let expiredCertPrivateKey = P256.Signing.PrivateKey()
        let expiredCert = try generateSelfSignedCertificate(
            privateKey: expiredCertPrivateKey,
            commonName: "Expired Cert",
            notBefore: Date().addingTimeInterval(-24 * 60 * 60),
            notAfter: Date().addingTimeInterval(-60 * 60)
        )

        let expiredSecCert = SecCertificateCreateWithData(
            nil,
            Data(try expiredCert.serializeAsPEM().derBytes) as CFData
        )!

        // sigT is now (outside cert validity)
        signingPrivateKey = expiredCertPrivateKey
        signingCertificate = expiredCert

        let sigT = formatISO8601(Date())
        let x5tS256 = calculateCertificateThumbprint(expiredSecCert)

        let jwt = try createJAdESJWT(
            payload: ["test": "data"],
            sigT: sigT,
            x5tS256: x5tS256,
            includeCrit: false
        )

        // Should fail with default options (validates cert validity)
        let defaultResult = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: expiredSecCert,
            options: .default
        )

        switch defaultResult {
        case .success:
            XCTFail("Default options should reject sigT outside cert validity")
        case .failure(let error):
            if case .sigTOutsideCertificateValidity = error {
                // Expected
            } else {
                XCTFail("Expected sigTOutsideCertificateValidity error")
            }
        }

        // Should succeed with lenient options (skips cert validity check)
        let lenientResult = JAdESSignatureVerifier.verifyJAdES(
            jwt: jwt,
            signingCertificate: expiredSecCert,
            options: .lenient
        )

        switch lenientResult {
        case .success:
            // Expected
            break
        case .failure(let error):
            XCTFail("Lenient options should skip cert validity check, got: \(error)")
        }
    }
}
