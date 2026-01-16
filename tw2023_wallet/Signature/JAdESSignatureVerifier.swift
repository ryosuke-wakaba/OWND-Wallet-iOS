//
//  JAdESSignatureVerifier.swift
//  tw2023_wallet
//
//  JAdES Baseline-B signature verification per ETSI TS 119 182-1.
//  Validates JWT signatures with sigT (signing time) and x5t#S256 (certificate thumbprint).
//

import CryptoKit
import Foundation
import JWTDecode
import Security
import SwiftASN1
import X509

/// JAdES Baseline-B signature verification per ETSI TS 119 182-1
enum JAdESSignatureVerifier {

    // MARK: - Error Types

    /// Errors that can occur during JAdES signature verification
    enum JAdESVerificationError: Error, LocalizedError {
        // sigT validation errors
        case sigTMissing
        case sigTInvalidFormat(String)
        case sigTInFuture(sigT: Date, now: Date, tolerance: TimeInterval)
        case sigTOutsideCertificateValidity(sigT: Date, notBefore: Date, notAfter: Date)

        // x5t#S256 validation errors
        case x5tS256Missing
        case x5tS256Mismatch(expected: String, actual: String)

        // Certificate errors
        case noCertificateProvided
        case certificateExtractionFailed(String)
        case publicKeyExtractionFailed

        // Signature errors
        case signatureVerificationFailed(String)
        case unsupportedAlgorithm(String)

        // crit header errors
        case criticalHeaderNotProcessed(String)

        // JWT format errors
        case invalidJWTFormat(String)

        var errorDescription: String? {
            switch self {
            case .sigTMissing:
                return "Required 'sigT' (signing time) header is missing"
            case .sigTInvalidFormat(let format):
                return "Invalid sigT format: \(format). Expected ISO 8601 / RFC 3339"
            case .sigTInFuture(let sigT, let now, let tolerance):
                return
                    "sigT (\(formatISO8601(sigT))) is in the future (now: \(formatISO8601(now)), tolerance: \(tolerance)s)"
            case .sigTOutsideCertificateValidity(let sigT, let notBefore, let notAfter):
                return
                    "sigT (\(formatISO8601(sigT))) is outside certificate validity period (\(notBefore) - \(notAfter))"
            case .x5tS256Missing:
                return "Required 'x5t#S256' (certificate thumbprint) header is missing"
            case .x5tS256Mismatch(let expected, let actual):
                return "Certificate thumbprint mismatch: header contains \(expected), calculated \(actual)"
            case .noCertificateProvided:
                return "No certificate provided for verification"
            case .certificateExtractionFailed(let reason):
                return "Failed to extract certificate: \(reason)"
            case .publicKeyExtractionFailed:
                return "Failed to extract public key from certificate"
            case .signatureVerificationFailed(let reason):
                return "Signature verification failed: \(reason)"
            case .unsupportedAlgorithm(let alg):
                return "Unsupported algorithm: \(alg)"
            case .criticalHeaderNotProcessed(let header):
                return "Critical header '\(header)' was not processed"
            case .invalidJWTFormat(let reason):
                return "Invalid JWT format: \(reason)"
            }
        }
    }

    // MARK: - Configuration

    /// Configuration options for JAdES verification
    struct VerificationOptions {
        /// Clock skew tolerance for sigT future check (default: 5 minutes)
        let clockSkewTolerance: TimeInterval

        /// Whether to validate sigT against certificate validity period
        let validateSigTAgainstCertValidity: Bool

        /// Whether to require crit header validation
        let requireCritValidation: Bool

        static let `default` = VerificationOptions(
            clockSkewTolerance: 300,  // 5 minutes
            validateSigTAgainstCertValidity: true,
            requireCritValidation: true
        )

        static let lenient = VerificationOptions(
            clockSkewTolerance: 600,  // 10 minutes
            validateSigTAgainstCertValidity: false,
            requireCritValidation: false
        )
    }

    // MARK: - Result Types

    /// Result of JAdES signature verification
    struct VerificationResult {
        /// Decoded payload data
        let payload: Data
        /// Signing time from sigT header
        let signingTime: Date
        /// Certificate thumbprint from x5t#S256 header
        let certificateThumbprint: String
    }

    // MARK: - Supported Critical Headers

    /// Headers that this implementation can process
    private static let supportedCriticalHeaders: Set<String> = ["sigT", "x5t#S256"]

    // MARK: - Date Formatting Helpers

    /// Format Date to ISO 8601 string
    private static func formatISO8601(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter.string(from: date)
    }

    /// Parse ISO 8601 string to Date
    private static func parseISO8601(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        return formatter.date(from: string)
    }

    // MARK: - Public Methods

    /// Verify a JAdES-signed JWT with certificate from x5c header
    /// - Parameters:
    ///   - jwt: The JWT string to verify
    ///   - options: Verification options (default: strict)
    /// - Returns: VerificationResult on success, JAdESVerificationError on failure
    static func verifyJAdES(
        jwt: String,
        options: VerificationOptions = .default
    ) -> Result<VerificationResult, JAdESVerificationError> {
        print("🔐 [JAdES] ========== Starting JAdES Verification ==========")

        // 1. Decode JWT to get header
        guard let (header, _, _) = try? JWTOperations.decodeJwt(jwt: jwt) else {
            print("🔐 [JAdES] ❌ Failed to decode JWT")
            return .failure(.invalidJWTFormat("Failed to decode JWT"))
        }

        print("🔐 [JAdES] Header keys: \(header.keys.sorted())")

        // 2. Extract x5c certificate chain
        guard let x5cArray = header["x5c"] as? [String], !x5cArray.isEmpty else {
            print("🔐 [JAdES] ❌ x5c header not found or empty")
            return .failure(.noCertificateProvided)
        }

        print("🔐 [JAdES] x5c certificates: \(x5cArray.count)")

        // 3. Parse leaf certificate (first in x5c array)
        guard let leafCertData = Data(base64Encoded: x5cArray[0]) else {
            print("🔐 [JAdES] ❌ Failed to decode x5c[0] from base64")
            return .failure(.certificateExtractionFailed("Failed to decode base64"))
        }

        guard
            let leafSecCertificate = SecCertificateCreateWithData(nil, leafCertData as CFData)
        else {
            print("🔐 [JAdES] ❌ Failed to create SecCertificate from x5c[0]")
            return .failure(.certificateExtractionFailed("Failed to create SecCertificate"))
        }

        // 4. Perform verification with the extracted certificate
        return verifyJAdES(
            jwt: jwt,
            signingCertificate: leafSecCertificate,
            options: options
        )
    }

    /// Verify a JAdES-signed JWT with externally provided SecCertificate
    /// Used when certificate comes from TrustedList lookup instead of x5c header
    /// - Parameters:
    ///   - jwt: The JWT string to verify
    ///   - signingCertificate: The signing certificate as SecCertificate
    ///   - options: Verification options (default: strict)
    /// - Returns: VerificationResult on success, JAdESVerificationError on failure
    static func verifyJAdES(
        jwt: String,
        signingCertificate: SecCertificate,
        options: VerificationOptions = .default
    ) -> Result<VerificationResult, JAdESVerificationError> {
        print("🔐 [JAdES] Verifying with provided SecCertificate")

        // 1. Decode JWT to get header
        guard let (header, _, _) = try? JWTOperations.decodeJwt(jwt: jwt) else {
            print("🔐 [JAdES] ❌ Failed to decode JWT")
            return .failure(.invalidJWTFormat("Failed to decode JWT"))
        }

        // 2. Validate crit header if required
        if options.requireCritValidation {
            if let critResult = validateCritHeader(header: header) {
                return .failure(critResult)
            }
        }

        // 3. Validate sigT
        let sigTResult = validateSigT(
            header: header,
            certificate: signingCertificate,
            options: options
        )

        let signingTime: Date
        switch sigTResult {
        case .success(let date):
            signingTime = date
            print("🔐 [JAdES] ✓ sigT validated: \(date))")
        case .failure(let error):
            print("🔐 [JAdES] ❌ sigT validation failed: \(error)")
            return .failure(error)
        }

        // 4. Validate x5t#S256
        let x5tResult = validateX5tS256(header: header, certificate: signingCertificate)

        let thumbprint: String
        switch x5tResult {
        case .success(let hash):
            thumbprint = hash
            print("🔐 [JAdES] ✓ x5t#S256 validated: \(hash)")
        case .failure(let error):
            print("🔐 [JAdES] ❌ x5t#S256 validation failed: \(error)")
            return .failure(error)
        }

        // 5. Extract public key from certificate
        guard let publicKey = SecCertificateCopyKey(signingCertificate) else {
            print("🔐 [JAdES] ❌ Failed to extract public key from certificate")
            return .failure(.publicKeyExtractionFailed)
        }

        // 6. Verify JWT signature
        let signatureResult = JWTOperations.verifyJwt(jwt: jwt, publicKey: publicKey)
        switch signatureResult {
        case .success:
            print("🔐 [JAdES] ✓ Signature verified")
        case .failure(let error):
            print("🔐 [JAdES] ❌ Signature verification failed: \(error)")
            return .failure(.signatureVerificationFailed(error.localizedDescription))
        }

        // 7. Extract payload
        guard let payloadData = extractPayload(from: jwt) else {
            print("🔐 [JAdES] ❌ Failed to extract payload")
            return .failure(.invalidJWTFormat("Failed to extract payload"))
        }

        print("🔐 [JAdES] ✅ JAdES verification successful")
        print("🔐 [JAdES] ==============================================")

        return .success(
            VerificationResult(
                payload: payloadData,
                signingTime: signingTime,
                certificateThumbprint: thumbprint
            ))
    }

    // MARK: - Private Validation Methods

    /// Validate crit (critical) header
    /// Returns error if there are unprocessed critical headers
    private static func validateCritHeader(header: [String: Any]) -> JAdESVerificationError? {
        guard let crit = header["crit"] as? [String] else {
            // crit header is optional, but if present, all listed headers must be processed
            return nil
        }

        print("🔐 [JAdES] crit header: \(crit)")

        for criticalHeader in crit {
            if !supportedCriticalHeaders.contains(criticalHeader) {
                print("🔐 [JAdES] ❌ Unsupported critical header: \(criticalHeader)")
                return .criticalHeaderNotProcessed(criticalHeader)
            }
        }

        return nil
    }

    /// Validate sigT (signing time) claim
    private static func validateSigT(
        header: [String: Any],
        certificate: SecCertificate,
        options: VerificationOptions
    ) -> Result<Date, JAdESVerificationError> {
        // 1. Check existence
        guard let sigTString = header["sigT"] as? String else {
            return .failure(.sigTMissing)
        }

        print("🔐 [JAdES] sigT value: \(sigTString)")

        // 2. Parse ISO 8601
        guard let sigT = parseISO8601(sigTString) else {
            return .failure(.sigTInvalidFormat(sigTString))
        }

        // 3. Future check with tolerance
        let now = Date()
        let maxAllowedTime = now.addingTimeInterval(options.clockSkewTolerance)
        if sigT > maxAllowedTime {
            return .failure(.sigTInFuture(sigT: sigT, now: now, tolerance: options.clockSkewTolerance))
        }

        // 4. Optional: Certificate validity check
        if options.validateSigTAgainstCertValidity {
            // Try to parse certificate with swift-certificates to get validity period
            let certData = SecCertificateCopyData(certificate) as Data
            if let cert = try? Certificate(derEncoded: Array(certData)) {
                let notBefore = cert.notValidBefore
                let notAfter = cert.notValidAfter
                if sigT < notBefore || sigT > notAfter {
                    return .failure(
                        .sigTOutsideCertificateValidity(
                            sigT: sigT, notBefore: notBefore, notAfter: notAfter))
                }
            }
        }

        return .success(sigT)
    }

    /// Validate x5t#S256 (certificate thumbprint)
    private static func validateX5tS256(
        header: [String: Any],
        certificate: SecCertificate
    ) -> Result<String, JAdESVerificationError> {
        // 1. Check existence
        guard let expectedThumbprint = header["x5t#S256"] as? String else {
            return .failure(.x5tS256Missing)
        }

        print("🔐 [JAdES] x5t#S256 header value: \(expectedThumbprint)")

        // 2. Calculate certificate SHA-256 thumbprint
        let derData = SecCertificateCopyData(certificate) as Data
        let hash = SHA256.hash(data: derData)
        let actualThumbprint = Data(hash).base64URLEncodedString()

        print("🔐 [JAdES] x5t#S256 calculated: \(actualThumbprint)")

        // 3. Compare
        if actualThumbprint != expectedThumbprint {
            return .failure(.x5tS256Mismatch(expected: expectedThumbprint, actual: actualThumbprint))
        }

        return .success(actualThumbprint)
    }

    /// Extract payload data from JWT
    private static func extractPayload(from jwt: String) -> Data? {
        let parts = jwt.split(separator: ".")
        guard parts.count >= 2 else {
            return nil
        }

        var base64Payload = String(parts[1])

        // Add padding if needed for base64 decoding
        let remainder = base64Payload.count % 4
        if remainder > 0 {
            base64Payload += String(repeating: "=", count: 4 - remainder)
        }

        // Convert from base64url to base64
        base64Payload =
            base64Payload
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        return Data(base64Encoded: base64Payload)
    }
}
