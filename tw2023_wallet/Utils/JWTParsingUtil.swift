//
//  JWTParsingUtil.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Utility for parsing JWT and SD-JWT credentials
struct JWTParsingUtil {

    /// Information extracted from a JWT credential
    struct CredentialInfo {
        let iss: String
        let iat: Int64
        let exp: Int64
        let typeOrVct: String
    }

    /// Extract basic information from a JWT credential
    /// - Parameters:
    ///   - jwt: The JWT string
    ///   - format: The credential format (used to determine type claim name)
    /// - Returns: Dictionary containing iss, iat, exp, and typeOrVct
    static func extractInfoFromJwt(jwt: String, format: String) -> [String: Any] {
        guard let decodedPayload = jwt.components(separatedBy: ".")[1].base64UrlDecoded(),
            let decodedString = String(data: decodedPayload, encoding: .utf8),
            let jsonData = decodedString.data(using: .utf8),
            let jwtDictionary = try? JSONSerialization.jsonObject(with: jsonData, options: [])
                as? [String: Any]
        else {
            return [:]
        }

        let iss = jwtDictionary["iss"] as? String ?? ""
        let iat = jwtDictionary["iat"] as? Int64 ?? 0
        let exp = jwtDictionary["exp"] as? Int64 ?? 0

        // Determine the type claim name based on format
        let credentialFormat = CredentialFormat(formatString: format)
        let typeClaimName = credentialFormat?.typeClaimName ?? "type"
        let typeOrVct = jwtDictionary[typeClaimName] as? String ?? ""

        return ["iss": iss, "iat": iat, "exp": exp, "typeOrVct": typeOrVct]
    }

    /// Extract basic information from an SD-JWT credential
    /// - Parameters:
    ///   - credential: The full SD-JWT string (with disclosures)
    ///   - format: The credential format
    /// - Returns: Dictionary containing iss, iat, exp, and typeOrVct
    static func extractSDJwtInfo(credential: String, format: String) -> [String: Any] {
        let issuerSignedJwt = credential.split(separator: "~")[0]
        return extractInfoFromJwt(jwt: String(issuerSignedJwt), format: format)
    }

    /// Extract basic information from a JWT VC JSON credential
    /// - Parameters:
    ///   - credential: The JWT VC JSON string
    ///   - format: The credential format
    /// - Returns: Dictionary containing iss, iat, exp, and typeOrVct
    static func extractJwtVcJsonInfo(credential: String, format: String) -> [String: Any] {
        return extractInfoFromJwt(jwt: credential, format: format)
    }

    /// Extract credential information as a structured type
    /// - Parameters:
    ///   - jwt: The JWT string
    ///   - format: The credential format
    /// - Returns: CredentialInfo struct or nil if parsing fails
    static func extractCredentialInfo(jwt: String, format: String) -> CredentialInfo? {
        let info = extractInfoFromJwt(jwt: jwt, format: format)

        guard let iss = info["iss"] as? String,
              let iat = info["iat"] as? Int64,
              let exp = info["exp"] as? Int64,
              let typeOrVct = info["typeOrVct"] as? String else {
            return nil
        }

        return CredentialInfo(iss: iss, iat: iat, exp: exp, typeOrVct: typeOrVct)
    }
}
