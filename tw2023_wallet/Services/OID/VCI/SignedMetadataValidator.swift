//
//  SignedMetadataValidator.swift
//  tw2023_wallet
//
//  Created on 2026/01/05.
//

import Foundation
import JWTDecode

/// Errors specific to Signed Metadata validation
enum SignedMetadataError: LocalizedError, Equatable {
    case unsupportedSignatureMethod(String)
    case invalidTyp(String)
    case missingRequiredClaim(String)
    case subjectMismatch(expected: String, actual: String)
    case expiredMetadata
    case signatureVerificationFailed(String)
    case certificateValidationFailed(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedSignatureMethod:
            return "Unable to verify issuer metadata. The signature method is not supported. Please contact the service provider."
        case .invalidTyp:
            return "Unable to verify issuer metadata. Invalid metadata format. Please contact the service provider."
        case .missingRequiredClaim:
            return "Unable to verify issuer metadata. Required information is missing. Please contact the service provider."
        case .subjectMismatch:
            return "Unable to verify issuer metadata. The issuer identifier does not match. Please contact the service provider."
        case .expiredMetadata:
            return "Unable to verify issuer metadata. The metadata has expired. Please contact the service provider."
        case .signatureVerificationFailed:
            return "Unable to verify issuer metadata. Signature verification failed. Please contact the service provider."
        case .certificateValidationFailed:
            return "Unable to verify issuer metadata. Certificate validation failed. Please contact the service provider."
        }
    }

    /// Technical details for logging/debugging
    var technicalDescription: String {
        switch self {
        case .unsupportedSignatureMethod(let method):
            return "Unsupported signature method: \(method). Only x5c is supported."
        case .invalidTyp(let typ):
            return "Invalid typ header: \(typ). Expected 'openidvci-issuer-metadata+jwt'."
        case .missingRequiredClaim(let claim):
            return "Missing required claim: \(claim)"
        case .subjectMismatch(let expected, let actual):
            return "Subject mismatch: expected '\(expected)', got '\(actual)'"
        case .expiredMetadata:
            return "Signed metadata has expired"
        case .signatureVerificationFailed(let reason):
            return "Signature verification failed: \(reason)"
        case .certificateValidationFailed(let reason):
            return "Certificate validation failed: \(reason)"
        }
    }

    static func == (lhs: SignedMetadataError, rhs: SignedMetadataError) -> Bool {
        switch (lhs, rhs) {
        case (.unsupportedSignatureMethod(let l), .unsupportedSignatureMethod(let r)):
            return l == r
        case (.invalidTyp(let l), .invalidTyp(let r)):
            return l == r
        case (.missingRequiredClaim(let l), .missingRequiredClaim(let r)):
            return l == r
        case (.subjectMismatch(let le, let la), .subjectMismatch(let re, let ra)):
            return le == re && la == ra
        case (.expiredMetadata, .expiredMetadata):
            return true
        case (.signatureVerificationFailed(let l), .signatureVerificationFailed(let r)):
            return l == r
        case (.certificateValidationFailed(let l), .certificateValidationFailed(let r)):
            return l == r
        default:
            return false
        }
    }
}

/// Result of signed metadata validation
struct SignedMetadataValidationResult {
    let payload: [String: Any]
    let issuer: String?
    let subject: String
    let issuedAt: Date
    let expiresAt: Date?
}

/// Validator for OID4VCI Signed Metadata (Section 12.2.3)
enum SignedMetadataValidator {

    /// Expected typ header value for signed issuer metadata
    static let expectedTyp = "openidvci-issuer-metadata+jwt"

    /// Validates a signed metadata JWT with TrustedList support
    /// - Parameters:
    ///   - jwt: The signed metadata JWT string
    ///   - expectedIssuerIdentifier: The expected credential issuer identifier (for sub validation)
    ///   - loteSearchInfos: Array of LoTE search infos specifying which LoTEs to search
    /// - Returns: Validation result containing the decoded payload
    static func validate(
        jwt: String,
        expectedIssuerIdentifier: String,
        loteSearchInfos: [LoTESearchInfo]
    ) async -> Result<SignedMetadataValidationResult, SignedMetadataError> {
        print("🔐 [SignedMetadata] ========== Validating Signed Metadata ==========")
        print("🔐 [SignedMetadata] Issuer Identifier: \(expectedIssuerIdentifier)")

        // 1. Decode JWT to inspect header
        guard let decodedJwt = try? decode(jwt: jwt) else {
            print("🔐 [SignedMetadata] ❌ Failed to decode JWT")
            return .failure(.signatureVerificationFailed("Unable to decode JWT"))
        }

        // 2. Validate typ header
        if let typ = decodedJwt.header["typ"] as? String {
            if typ != expectedTyp {
                print("🔐 [SignedMetadata] ❌ Invalid typ: \(typ)")
                return .failure(.invalidTyp(typ))
            }
        } else {
            print("🔐 [SignedMetadata] ❌ Missing typ header")
            return .failure(.missingRequiredClaim("typ"))
        }
        print("🔐 [SignedMetadata] ✓ typ header valid")

        // 3. Check signature method - only x5c is supported
        let hasX5c = decodedJwt.header["x5c"] != nil
        let hasKid = decodedJwt.header["kid"] != nil
        let hasTrustChain = decodedJwt.header["trust_chain"] != nil

        if !hasX5c {
            if hasKid {
                print("🔐 [SignedMetadata] ❌ Unsupported method: kid")
                return .failure(.unsupportedSignatureMethod("kid"))
            } else if hasTrustChain {
                print("🔐 [SignedMetadata] ❌ Unsupported method: trust_chain")
                return .failure(.unsupportedSignatureMethod("trust_chain"))
            } else {
                print("🔐 [SignedMetadata] ❌ x5c not found")
                return .failure(.unsupportedSignatureMethod("unknown (x5c not found)"))
            }
        }
        print("🔐 [SignedMetadata] ✓ x5c header found")

        // 4. Verify JWT signature using x5c with TrustedList support
        print("🔐 [SignedMetadata] Verifying signature with TrustedList lookup...")
        let verificationResult = await X5CJWTVerifier.verifyJwtWithX5C(
            jwt: jwt,
            issuerURL: expectedIssuerIdentifier,
            loteSearchInfos: loteSearchInfos,
            verifyCertChain: true
        )

        switch verificationResult {
        case .failure(let error):
            switch error {
            case .certificateValidationFailed(let certError):
                print("🔐 [SignedMetadata] ❌ Certificate validation failed")
                return .failure(.certificateValidationFailed(certError.errorDescription ?? "Unknown certificate error"))
            default:
                print("🔐 [SignedMetadata] ❌ Signature verification failed: \(error)")
                return .failure(.signatureVerificationFailed(String(describing: error)))
            }
        case .success:
            print("🔐 [SignedMetadata] ✓ Signature and certificate chain valid")
        }

        // 5. Validate payload claims
        let result = validatePayloadClaims(decodedJwt: decodedJwt, expectedIssuerIdentifier: expectedIssuerIdentifier)
        switch result {
        case .success:
            print("🔐 [SignedMetadata] ✅ Signed metadata validation PASSED")
        case .failure(let error):
            print("🔐 [SignedMetadata] ❌ Payload validation failed: \(error.technicalDescription)")
        }
        print("🔐 [SignedMetadata] ====================================================")
        return result
    }

    /// Validate JWT payload claims (shared logic)
    private static func validatePayloadClaims(
        decodedJwt: JWT,
        expectedIssuerIdentifier: String
    ) -> Result<SignedMetadataValidationResult, SignedMetadataError> {
        let payload = decodedJwt.body

        // sub is REQUIRED and must match credential issuer identifier
        guard let sub = payload["sub"] as? String else {
            return .failure(.missingRequiredClaim("sub"))
        }

        if sub != expectedIssuerIdentifier {
            return .failure(.subjectMismatch(expected: expectedIssuerIdentifier, actual: sub))
        }

        // iat is REQUIRED
        guard let iatValue = payload["iat"] else {
            return .failure(.missingRequiredClaim("iat"))
        }

        let iat: Date
        if let iatDouble = iatValue as? Double {
            iat = Date(timeIntervalSince1970: iatDouble)
        } else if let iatInt = iatValue as? Int {
            iat = Date(timeIntervalSince1970: Double(iatInt))
        } else {
            return .failure(.missingRequiredClaim("iat (invalid format)"))
        }

        // exp is OPTIONAL but if present, must not be expired
        var exp: Date? = nil
        if let expValue = payload["exp"] {
            if let expDouble = expValue as? Double {
                exp = Date(timeIntervalSince1970: expDouble)
            } else if let expInt = expValue as? Int {
                exp = Date(timeIntervalSince1970: Double(expInt))
            }

            if let expDate = exp, expDate < Date() {
                return .failure(.expiredMetadata)
            }
        }

        // iss is OPTIONAL
        let iss = payload["iss"] as? String

        return .success(SignedMetadataValidationResult(
            payload: payload,
            issuer: iss,
            subject: sub,
            issuedAt: iat,
            expiresAt: exp
        ))
    }

    /// Extracts metadata from a validated signed metadata JWT payload
    /// - Parameter payload: The validated JWT payload
    /// - Returns: JSON data that can be decoded as CredentialIssuerMetadata
    static func extractMetadataJson(from payload: [String: Any]) throws -> Data {
        return try JSONSerialization.data(withJSONObject: payload, options: [])
    }
}
