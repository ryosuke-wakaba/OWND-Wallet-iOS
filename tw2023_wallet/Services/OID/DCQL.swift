//
//  DCQL.swift
//  tw2023_wallet
//
//  Digital Credentials Query Language (DCQL) types for OID4VP 1.0
//

import Foundation

// MARK: - DCQL Query Types

/// DCQL Query - Root structure for credential queries
/// https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#name-digital-credentials-query-l
struct DcqlQuery: Codable {
    let credentials: [DcqlCredentialQuery]
}

/// DCQL Credential Query - Defines requirements for a single credential
struct DcqlCredentialQuery: Codable {
    let id: String
    let format: String
    let meta: DcqlCredentialMeta?
    let claims: [DcqlClaimQuery]?

    enum CodingKeys: String, CodingKey {
        case id
        case format
        case meta
        case claims
    }
}

/// DCQL Credential Metadata
struct DcqlCredentialMeta: Codable {
    let vctValues: [String]?

    enum CodingKeys: String, CodingKey {
        case vctValues = "vct_values"
    }
}

/// DCQL Claim Query - Defines requirements for claims within a credential
struct DcqlClaimQuery: Codable {
    let id: String?
    let path: [String]
    let values: [AnyCodableValue]?

    enum CodingKeys: String, CodingKey {
        case id
        case path
        case values
    }
}

// MARK: - AnyCodableValue for flexible value types

/// A type-erased Codable value to handle any JSON value type
enum AnyCodableValue: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if container.decodeNil() {
            self = .null
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .bool(boolValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else {
            throw DecodingError.typeMismatch(
                AnyCodableValue.self,
                DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type")
            )
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        case .null:
            try container.encodeNil()
        }
    }
}

// MARK: - Disclosure Types (from PresentationExchange)

struct DisclosureWithOptionality: Codable {
    var disclosure: Disclosure
    var isSubmit: Bool
    var isUserSelectable: Bool
}

// MARK: - DCQL Matching Result

/// Result of matching a credential against a DCQL query
struct DcqlMatchResult {
    let credentialQueryId: String
    let matchedClaims: [DcqlMatchedClaim]
}

/// A claim that matched the DCQL query
struct DcqlMatchedClaim {
    let path: [String]
    let disclosure: Disclosure
    let isRequired: Bool
}

/// Credential with DCQL matching information
struct DcqlCredentialMatch {
    let credentialQuery: DcqlCredentialQuery
    let disclosuresWithOptionality: [DisclosureWithOptionality]
}
