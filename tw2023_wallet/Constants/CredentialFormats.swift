//
//  CredentialFormats.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Supported credential formats according to OID4VCI 1.0 specification
enum CredentialFormat: String, CaseIterable {
    /// SD-JWT VC format (legacy name - OID4VCI < 1.0)
    case sdJwtVC = "vc+sd-jwt"

    /// SD-JWT VC format (OID4VCI 1.0 Final - new name)
    case dcSDJWT = "dc+sd-jwt"

    /// JWT VC JSON format
    case jwtVCJson = "jwt_vc_json"

    /// Returns true if the format is an SD-JWT variant (vc+sd-jwt or dc+sd-jwt)
    var isSDJWT: Bool {
        return self == .sdJwtVC || self == .dcSDJWT
    }

    /// Returns the claim name for the type/vct field
    /// - SD-JWT formats use "vct" (verifiable credential type)
    /// - JWT VC JSON uses "type"
    var typeClaimName: String {
        switch self {
        case .sdJwtVC, .dcSDJWT:
            return "vct"
        case .jwtVCJson:
            return "type"
        }
    }

    /// Initialize from a format string, returns nil if the format is not supported
    init?(formatString: String) {
        if let format = CredentialFormat(rawValue: formatString) {
            self = format
        } else {
            return nil
        }
    }

    /// Check if a format string is supported
    static func isSupported(_ formatString: String) -> Bool {
        return CredentialFormat(rawValue: formatString) != nil
    }
}
