//
//  Metadata.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/25.
//

import Foundation
import SwiftyJSON

struct Logo: Codable {
    let uri: String
    let altText: String?
}

struct BackgroundImage: Codable {
    let uri: String?
}

protocol Displayable: Codable {
    var name: String? { get }
    var locale: String? { get }
}

struct IssuerDisplay: Displayable {
    let name: String?
    let locale: String?
    let logo: Logo?
}

struct ClaimDisplay: Displayable {
    let name: String?
    let locale: String?
}

struct CredentialDisplay: Codable {
    let name: String
    let locale: String?
    let logo: Logo?
    let description: String?
    let backgroundColor: String?
    let backgroundImage: BackgroundImage?
    let textColor: String?
}

struct Claim: Codable {
    let mandatory: Bool?
    let valueType: String?
    let display: [ClaimDisplay]?
}

struct ClaimOnlyMandatory: Codable {
    var mandatory: Bool?
}

// OID4VCI 1.0: credential_metadata entry (map-based structure - legacy)
struct ClaimMetadataEntry: Codable {
    let display: [ClaimDisplay]?
}

// OID4VCI 1.0: Array-based claim entry (used by EUDI servers)
struct ArrayClaimEntry: Codable {
    let path: [String]?
    let valueType: String?
    let mandatory: Bool?
    let display: [ClaimDisplay]?
}

// OID4VCI 1.0: credential_metadata structure
// Supports both array-based claims (EUDI servers) and map-based claims (legacy)
struct CredentialMetadata: Codable {
    // Array-based structure (EUDI servers): claims is an array of entries with path
    let claimsArray: [ArrayClaimEntry]?
    // Map-based structure (legacy): key is claim name, value contains display info
    let claimsMap: [String: ClaimMetadataEntry]?
    // Display info for the credential itself
    let display: [CredentialDisplay]?

    // For protocol conformance
    var claims: [String: ClaimMetadataEntry]? {
        return claimsMap
    }
    var claimOrder: [String]? {
        return claimsMap?.keys.sorted()
    }

    enum CodingKeys: String, CodingKey {
        case claims
        case display
    }

    init(claimsArray: [ArrayClaimEntry]? = nil, claimsMap: [String: ClaimMetadataEntry]? = nil, display: [CredentialDisplay]? = nil) {
        self.claimsArray = claimsArray
        self.claimsMap = claimsMap
        self.display = display
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Try to decode display
        self.display = try container.decodeIfPresent([CredentialDisplay].self, forKey: .display)

        // Try array-based claims first (EUDI servers)
        if let arrayBasedClaims = try? container.decode([ArrayClaimEntry].self, forKey: .claims) {
            self.claimsArray = arrayBasedClaims
            self.claimsMap = nil
        }
        // Fall back to map-based claims (legacy)
        else if let mapBasedClaims = try? container.decode([String: ClaimMetadataEntry].self, forKey: .claims) {
            self.claimsArray = nil
            self.claimsMap = mapBasedClaims
        }
        else {
            self.claimsArray = nil
            self.claimsMap = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(display, forKey: .display)
        if let claimsArray = claimsArray {
            try container.encode(claimsArray, forKey: .claims)
        } else if let claimsMap = claimsMap {
            try container.encode(claimsMap, forKey: .claims)
        }
    }

    /// Get localized claim names from either array or map-based claims
    func getLocalizedClaimNames(locale: String = "ja-JP") -> [String] {
        // Array-based claims (EUDI servers)
        if let claimsArray = claimsArray {
            var result: [String] = []
            for claim in claimsArray {
                if let displays = claim.display, !displays.isEmpty {
                    let matchingDisplay = displays.first { $0.locale == locale && $0.name != nil }
                    if let name = matchingDisplay?.name ?? displays.first?.name {
                        result.append(name)
                    } else if let path = claim.path, let lastPath = path.last {
                        result.append(lastPath)
                    }
                } else if let path = claim.path, let lastPath = path.last {
                    result.append(lastPath)
                }
            }
            return result
        }

        // Map-based claims (legacy)
        if let claimsMap = claimsMap {
            return getLocalizedClaimNamesFromMap(claimsMap: claimsMap, order: claimOrder, locale: locale)
        }

        return []
    }
}

struct ProofSigningAlgValuesSupported: Codable {
    let proofSigningAlgValuesSupported: [String]
}

struct CredentialResponseEncryption: Codable {
    let algValuesSupported: [String]
    let encValuesSupported: [String]
    let encryptionRequired: Bool
}

protocol CredentialConfiguration: Codable {
    var format: String { get }
    var scope: String? { get }
    var cryptographicBindingMethodsSupported: [String]? { get }
    var credentialSigningAlgValuesSupported: [String]? { get }
    var proofTypesSupported: [String: ProofSigningAlgValuesSupported]? { get }
    var display: [CredentialDisplay]? { get }

    func getCredentialDisplayName(locale: String) -> String
    func getClaimNames(locale: String) -> [String]
}

extension CredentialConfiguration {
    func getCredentialDisplayName(locale: String = "ja-JP") -> String {
        let defaultCredentialDisplay = "Unknown Credential"
        guard let credentialDisplays = self.display, credentialDisplays.count > 0 else {
            return defaultCredentialDisplay
        }
        for d in credentialDisplays {
            if let displayLocale = d.locale {
                if displayLocale == locale {
                    return d.name
                }
            }
        }
        if let firstDisplay = credentialDisplays.first {
            return firstDisplay.name
        }

        return defaultCredentialDisplay
    }

    func getClaimNames(locale: String = "ja-JP") -> [String] {
        return []
    }
}

typealias ClaimMap = [String: Claim]

struct CredentialSupportedVcSdJwt: CredentialConfiguration {
    let format: String
    let scope: String?
    let cryptographicBindingMethodsSupported: [String]?
    let credentialSigningAlgValuesSupported: [String]?
    let proofTypesSupported: [String: ProofSigningAlgValuesSupported]?
    let display: [CredentialDisplay]?

    let vct: String
    let claims: ClaimMap?
    let order: [String]?

    // OID4VCI 1.0: New credential_metadata field
    let credentialMetadata: CredentialMetadata?

    func getClaimNames(locale: String = "ja-JP") -> [String] {
        // OID4VCI 1.0: Use credentialMetadata (supports both array and map-based claims)
        if let metadata = self.credentialMetadata {
            let result = metadata.getLocalizedClaimNames(locale: locale)
            if !result.isEmpty {
                return result
            }
        }

        // Fall back to legacy claims field
        guard let claims = self.claims else {
            return []
        }

        return getLocalizedClaimNames(claims: claims, locale: locale)
    }

}

struct JwtVcJsonCredentialDefinition: Codable {
    let type: [String]
    let credentialSubject: ClaimMap?

    enum CodingKeys: String, CodingKey {
        case type
        case credentialSubject = "credentialSubject"
    }

    func getClaimNames(locale: String) -> [String] {
        guard let subject = self.credentialSubject else {
            return []
        }
        return getLocalizedClaimNames(claims: subject, locale: locale)
    }

}

struct CredentialSupportedJwtVcJson: CredentialConfiguration {
    let format: String
    let scope: String?
    let cryptographicBindingMethodsSupported: [String]?
    let credentialSigningAlgValuesSupported: [String]?
    let proofTypesSupported: [String: ProofSigningAlgValuesSupported]?
    let display: [CredentialDisplay]?

    let credentialDefinition: JwtVcJsonCredentialDefinition
    let order: [String]?

    // OID4VCI 1.0: New credential_metadata field
    let credentialMetadata: CredentialMetadata?

    func getClaimNames(locale: String = "ja-JP") -> [String] {
        // OID4VCI 1.0: Use credentialMetadata (supports both array and map-based claims)
        if let metadata = self.credentialMetadata {
            let result = metadata.getLocalizedClaimNames(locale: locale)
            if !result.isEmpty {
                return result
            }
        }

        return self.credentialDefinition.getClaimNames(locale: locale)
    }
}

struct LdpVcCredentialDefinition: Codable {
    let context: [String]  // todo オブジェクト形式に対応する
    let type: [String]
    let credentialSubject: ClaimMap?

    enum CodingKeys: String, CodingKey {
        case type
        case credentialSubject = "credentialSubject"
        case context = "@context"
    }

    func getClaimNames(locale: String) -> [String] {
        guard let subject = self.credentialSubject else {
            return []
        }
        return getLocalizedClaimNames(claims: subject, locale: locale)
    }

}

struct CredentialSupportedLdpVc: CredentialConfiguration {
    let format: String
    let scope: String?
    let cryptographicBindingMethodsSupported: [String]?
    let credentialSigningAlgValuesSupported: [String]?
    let proofTypesSupported: [String: ProofSigningAlgValuesSupported]?
    let display: [CredentialDisplay]?

    let credentialDefinition: LdpVcCredentialDefinition
    let order: [String]?

    func getClaimNames(locale: String = "ja-JP") -> [String] {
        return self.credentialDefinition.getClaimNames(locale: locale)
    }
}

typealias CredentialSupportedJwtVcJsonLd = CredentialSupportedLdpVc

// MARK: - mso_mdoc (ISO/IEC 18013-5)
// Minimal support for metadata parsing. Full credential issuance support is not yet implemented.

/// mso_mdoc claim entry (different from JWT-based claims)
struct MsoMdocClaimEntry: Codable {
    let path: [String]?
    let valueType: String?
    let mandatory: Bool?
    let display: [ClaimDisplay]?
}

/// mso_mdoc credential_metadata structure
struct MsoMdocCredentialMetadata: Codable {
    let claims: [MsoMdocClaimEntry]?
    let display: [CredentialDisplay]?
}

struct CredentialSupportedMsoMdoc: CredentialConfiguration {
    let format: String
    let scope: String?
    let cryptographicBindingMethodsSupported: [String]?
    let proofTypesSupported: [String: ProofSigningAlgValuesSupported]?

    // mso_mdoc specific fields
    let doctype: String?
    let credentialMetadata: MsoMdocCredentialMetadata?

    // Stored as strings (converted from either integer COSE IDs or string algorithm names)
    private let _credentialSigningAlgValuesSupported: [String]?

    // CredentialConfiguration protocol conformance
    var credentialSigningAlgValuesSupported: [String]? {
        return _credentialSigningAlgValuesSupported
    }

    // Display comes from credential_metadata for mso_mdoc
    var display: [CredentialDisplay]? {
        return credentialMetadata?.display
    }

    enum CodingKeys: String, CodingKey {
        case format
        case scope
        case cryptographicBindingMethodsSupported
        case proofTypesSupported
        case doctype
        case credentialMetadata
        case credentialSigningAlgValuesSupported
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        format = try container.decode(String.self, forKey: .format)
        scope = try container.decodeIfPresent(String.self, forKey: .scope)
        cryptographicBindingMethodsSupported = try container.decodeIfPresent([String].self, forKey: .cryptographicBindingMethodsSupported)
        proofTypesSupported = try container.decodeIfPresent([String: ProofSigningAlgValuesSupported].self, forKey: .proofTypesSupported)
        doctype = try container.decodeIfPresent(String.self, forKey: .doctype)
        credentialMetadata = try container.decodeIfPresent(MsoMdocCredentialMetadata.self, forKey: .credentialMetadata)

        // Handle credential_signing_alg_values_supported as either [Int] or [String]
        if let intValues = try? container.decode([Int].self, forKey: .credentialSigningAlgValuesSupported) {
            _credentialSigningAlgValuesSupported = intValues.map { String($0) }
        } else if let stringValues = try? container.decode([String].self, forKey: .credentialSigningAlgValuesSupported) {
            _credentialSigningAlgValuesSupported = stringValues
        } else {
            _credentialSigningAlgValuesSupported = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(format, forKey: .format)
        try container.encodeIfPresent(scope, forKey: .scope)
        try container.encodeIfPresent(cryptographicBindingMethodsSupported, forKey: .cryptographicBindingMethodsSupported)
        try container.encodeIfPresent(proofTypesSupported, forKey: .proofTypesSupported)
        try container.encodeIfPresent(doctype, forKey: .doctype)
        try container.encodeIfPresent(credentialMetadata, forKey: .credentialMetadata)
        try container.encodeIfPresent(_credentialSigningAlgValuesSupported, forKey: .credentialSigningAlgValuesSupported)
    }

    func getClaimNames(locale: String = "ja-JP") -> [String] {
        guard let claims = credentialMetadata?.claims else {
            return []
        }
        var result: [String] = []
        for claim in claims {
            if let displays = claim.display, !displays.isEmpty {
                let matchingDisplay = displays.first { $0.locale == locale && $0.name != nil }
                if let name = matchingDisplay?.name ?? displays.first?.name {
                    result.append(name)
                } else if let path = claim.path, let lastPath = path.last {
                    result.append(lastPath)
                }
            } else if let path = claim.path, let lastPath = path.last {
                result.append(lastPath)
            }
        }
        return result
    }
}

struct CredentialSupportedFormat: Decodable {
    let format: String
}

func getLocalizedClaimNames(claims: ClaimMap, locale: String) -> [String] {
    var result: [String] = []
    for (claimKey, claimValue) in claims {
        if let displays = claimValue.display {
            if displays.isEmpty {
                result.append(claimKey)
            }
            else {
                // Priority is given to those matching LOCALE.
                let firstElmMatchingToLocale = displays.first(where: {
                    ($0.locale == locale) && ($0.name != nil)
                })
                if let elm = firstElmMatchingToLocale {
                    result.append(elm.name!)
                }
                else {
                    // If there is no match for Locale, use the first element.
                    // And, If `name` does not exist for the first element, `claimKey` is used.
                    let firstDisplay = displays.first!  // `displays` is not empty
                    if let firstDisplayName = firstDisplay.name {
                        result.append(firstDisplayName)
                    }
                    else {
                        result.append(claimKey)
                    }
                }
            }
        }
        else {
            result.append(claimKey)
        }
    }
    return result
}

// OID4VCI 1.0: Get localized claim names from map-based credential_metadata structure
func getLocalizedClaimNamesFromMap(claimsMap: [String: ClaimMetadataEntry], order: [String]?, locale: String) -> [String] {
    var result: [String] = []
    // Use order if provided, otherwise iterate through claimsMap keys
    let keys = order ?? Array(claimsMap.keys)
    for claimKey in keys {
        guard let claimValue = claimsMap[claimKey] else { continue }
        if let displays = claimValue.display {
            if displays.isEmpty {
                result.append(claimKey)
            }
            else {
                // Priority is given to those matching LOCALE.
                let firstElmMatchingToLocale = displays.first(where: {
                    ($0.locale == locale) && ($0.name != nil)
                })
                if let elm = firstElmMatchingToLocale {
                    result.append(elm.name!)
                }
                else {
                    // If there is no match for Locale, use the first element.
                    // And, If `name` does not exist for the first element, `claimKey` is used.
                    let firstDisplay = displays.first!  // `displays` is not empty
                    if let firstDisplayName = firstDisplay.name {
                        result.append(firstDisplayName)
                    }
                    else {
                        result.append(claimKey)
                    }
                }
            }
        }
        else {
            result.append(claimKey)
        }
    }
    return result
}

func decodeCredentialSupported(from jsonData: Data) throws -> CredentialConfiguration {

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    // 一時的なコンテナ構造体をデコードして、formatフィールドを読み取る
    let formatContainer = try decoder.decode(CredentialSupportedFormat.self, from: jsonData)

    print(formatContainer)

    switch formatContainer.format {
        case CredentialFormat.dcSDJWT.rawValue:  // OID4VCI 1.0: New format name
            return try decoder.decode(CredentialSupportedVcSdJwt.self, from: jsonData)
        case CredentialFormat.jwtVCJson.rawValue:
            return try decoder.decode(CredentialSupportedJwtVcJson.self, from: jsonData)
        case "ldp_vc":
            return try decoder.decode(CredentialSupportedLdpVc.self, from: jsonData)
        case CredentialFormat.msoMdoc.rawValue:
            do {
                return try decoder.decode(CredentialSupportedMsoMdoc.self, from: jsonData)
            } catch {
                print("mso_mdoc decoding error: \(error)")
                if let jsonString = String(data: jsonData, encoding: .utf8) {
                    print("mso_mdoc JSON: \(jsonString)")
                }
                throw error
            }
        default:
            throw DecodingError.dataCorrupted(
                DecodingError.Context(codingPath: [], debugDescription: "Invalid format value"))

    }
}

struct CredentialIssuerMetadata: Codable {
    let credentialIssuer: String
    let authorizationServers: [String]?
    let credentialEndpoint: String
    let batchCredentialEndpoint: String?
    let deferredCredentialEndpoint: String?
    let notificationEndpoint: String?
    let nonceEndpoint: String?
    let credentialResponseEncryption: CredentialResponseEncryption?
    let credentialIdentifiersSupported: Bool?
    let signedMetadata: String?
    let display: [IssuerDisplay]?
    let credentialConfigurationsSupported: [String: CredentialConfiguration]

    // // It is assumed that the snake case strategy is configured.
    enum CodingKeys: String, CodingKey {
        case credentialIssuer = "credentialIssuer"
        case authorizationServers = "authorizationServers"
        case credentialEndpoint = "credentialEndpoint"
        case batchCredentialEndpoint = "batchCredentialEndpoint"
        case deferredCredentialEndpoint = "deferredCredentialEndpoint"
        case notificationEndpoint = "notificationEndpoint"
        case nonceEndpoint = "nonceEndpoint"
        case credentialResponseEncryption = "credentialResponseEncryption"
        case credentialIdentifiersSupported = "credentialIdentifiersSupported"
        case credentialConfigurationsSupported = "credentialConfigurationsSupported"
        case signedMetadata = "signedMetadata"
        case display
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        var credentialsSupportedDict = [String: CredentialConfiguration]()
        // Decode as JSON to preserve original keys (avoid convertFromSnakeCase affecting dictionary keys)
        let credentialsSupportedJSON = try container.decode(JSON.self, forKey: .credentialConfigurationsSupported)
        if let dictionary = credentialsSupportedJSON.dictionary {
            for (originalKey, credentialJSON) in dictionary {
                let credentialData = try JSONSerialization.data(
                    withJSONObject: credentialJSON.object, options: [])

                let credentialSupported = try decodeCredentialSupported(from: credentialData)
                credentialsSupportedDict[originalKey] = credentialSupported  // Use original key
            }
        }

        credentialIssuer = try container.decode(String.self, forKey: .credentialIssuer)
        authorizationServers = try container.decodeIfPresent(
            [String].self, forKey: .authorizationServers)
        credentialEndpoint = try container.decodeIfPresent(
            String.self, forKey: .credentialEndpoint)!
        batchCredentialEndpoint = try container.decodeIfPresent(
            String.self, forKey: .batchCredentialEndpoint)
        deferredCredentialEndpoint = try container.decodeIfPresent(
            String.self, forKey: .deferredCredentialEndpoint)
        notificationEndpoint = try container.decodeIfPresent(
            String.self, forKey: .notificationEndpoint)
        nonceEndpoint = try container.decodeIfPresent(
            String.self, forKey: .nonceEndpoint)
        credentialResponseEncryption = try container.decodeIfPresent(
            CredentialResponseEncryption.self, forKey: .credentialResponseEncryption)
        credentialIdentifiersSupported = try container.decodeIfPresent(
            Bool.self, forKey: .credentialIdentifiersSupported)
        signedMetadata = try container.decodeIfPresent(
            String.self, forKey: .signedMetadata)
        display = try container.decodeIfPresent([IssuerDisplay].self, forKey: .display)
        credentialConfigurationsSupported = credentialsSupportedDict
    }

    func getCredentialIssuerDisplayName(locale: String = "ja-jp") -> String {
        let defaultIssuerDisplay = "Unknown Issuer"
        guard let issuerDisplays = self.display, issuerDisplays.count > 0 else {
            return defaultIssuerDisplay
        }
        for d in issuerDisplays {
            if let displayLocale = d.locale {
                if let name = d.name, displayLocale == locale {
                    return name
                }
            }
        }
        if let firstDisplay = issuerDisplays.first,
            let name = firstDisplay.name
        {
            return name
        }

        return defaultIssuerDisplay
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(credentialIssuer, forKey: .credentialIssuer)
        try container.encodeIfPresent(authorizationServers, forKey: .authorizationServers)
        try container.encodeIfPresent(credentialEndpoint, forKey: .credentialEndpoint)
        try container.encodeIfPresent(batchCredentialEndpoint, forKey: .batchCredentialEndpoint)
        try container.encodeIfPresent(
            deferredCredentialEndpoint, forKey: .deferredCredentialEndpoint)

        // Encode credentialsSupported based on the actual type
        var credentialsSupportedContainer = container.nestedContainer(
            keyedBy: DynamicKey.self, forKey: .credentialConfigurationsSupported)
        for (key, value) in credentialConfigurationsSupported {
            let credentialEncoder = credentialsSupportedContainer.superEncoder(
                forKey: DynamicKey(stringValue: key)!)
            try value.encode(to: credentialEncoder)
        }

        try container.encodeIfPresent(display, forKey: .display)
    }
}

// DynamicKeyを使って動的なキーを扱う
struct DynamicKey: CodingKey {
    var stringValue: String
    init?(stringValue: String) {
        self.stringValue = stringValue
    }
    var intValue: Int?
    init?(intValue: Int) {
        return nil
    }
}

