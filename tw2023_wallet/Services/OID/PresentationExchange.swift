//
//  PresentationExchange.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/30.
//

import Foundation

enum LimitDisclosure: String, Codable {
    case required = "required"
    case preferred = "preferred"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        guard let limitDisclosure = LimitDisclosure(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid limitDisclosure type value: \(value)")
        }

        self = limitDisclosure
    }
}

enum Rule: String, Codable {
    case pick = "pick"
    case all = "all"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        guard let rule = Rule(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid rule type value: \(value)")
        }

        self = rule
    }
}

enum SubjectIsIssuer: String, Codable {
    case required = "required"
    case preferred = "preferred"

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let value = try container.decode(String.self)

        guard let subjectIsIssuer = SubjectIsIssuer(rawValue: value) else {
            throw DecodingError.dataCorruptedError(
                in: container, debugDescription: "Invalid SubjectIsIssuer type value: \(value)")
        }

        self = subjectIsIssuer
    }
}

struct PresentationDefinition: Codable {
    let id: String
    let inputDescriptors: [InputDescriptor]
    let name: String?
    let purpose: String?

    // extension
    let submissionRequirements: [SubmissionRequirement]?
}

struct ClaimFormat: Codable {
    let alg: [String]?
    let proofType: [String]?
}

struct InputDescriptor: Codable {
    let id: String
    let name: String?
    let purpose: String?
    let format: [String: ClaimFormat]?
    let constraints: InputDescriptorConstraints

    // extension
    let group: [String]?  // value MUST match one of the grouping strings listed in the from values of a Submission Requirement Rule object
}

struct InputDescriptorConstraints: Codable {
    let fields: [Field]?
    let limitDisclosure: LimitDisclosure?

    // extension
    let subjectIsIssuer: SubjectIsIssuer?
}

struct JSONSchemaProperties: Codable {
    let type: [String: String]?
}

struct Filter: Codable {
    let type: String?
    let required: [String]?
    let properties: JSONSchemaProperties?
}

struct Field: Codable {
    let path: [String]
    let id: String?
    let purpose: String?
    let name: String?
    let filter: Filter?
    let optional: Bool?  // true indicates the field is optional, and false or non-presence of the property indicates the field is required
}

enum InitializationError: Error {
    case invalidValue
}

struct SubmissionRequirement: Codable {
    let rule: Rule

    // MUST contain either a from or from_nested property.
    // If both properties are present, the implementation MUST produce an error
    let from: String?
    let fromNested: [SubmissionRequirement]?

    let name: String?  // used by a consuming User Agent to display the general name of the requirement set to a user
    let purpose: String?  // string that describes the purpose for which the submission is being requested
    // count, min, and max may be present with a pick rule
    let count: Int?
    let min: Int?
    let max: Int?

    init(
        rule: Rule,
        from: String? = nil,
        fromNested: [SubmissionRequirement]? = nil,
        name: String? = nil,
        purpose: String? = nil,
        count: Int? = nil,
        min: Int? = nil,
        max: Int? = nil
    ) throws {
        if (from != nil && fromNested != nil) || (from == nil && fromNested == nil) {
            throw InitializationError.invalidValue
        }

        if let cnt = count, cnt <= 0 {
            throw InitializationError.invalidValue
        }

        if let minimum = min, minimum < 0 {
            throw InitializationError.invalidValue
        }

        if let maximum = max {
            if maximum <= 0 {
                throw InitializationError.invalidValue
            }
            if let minimum = min, maximum <= minimum {
                throw InitializationError.invalidValue
            }
        }

        self.rule = rule
        self.from = from
        self.fromNested = fromNested
        self.name = name
        self.purpose = purpose
        self.count = count
        self.min = min
        self.max = max
    }
}

struct Path: Codable {
    let format: String
    let path: String
}

// https://identity.foundation/presentation-exchange/spec/v2.0.0/#presentation-submission
struct DescriptorMap: Codable {
    let id: String
    let format: String
    let path: String
    let pathNested: Path?
}

struct PresentationSubmission: Codable {
    let id: String
    let definitionId: String
    let descriptorMap: [DescriptorMap]
}

struct DisclosureWithOptionality: Codable {
    var disclosure: Disclosure
    var isSubmit: Bool
    var optional: Bool

    init(disclosure: Disclosure, isSubmit: Bool, optional: Bool) {
        self.disclosure = disclosure
        self.isSubmit = isSubmit
        self.optional = optional
    }
}

class JwtVpJsonPresentation {
    static func genDescriptorMap(
        inputDescriptorId: String, pathIndex: Int = -1, pathNestedIndex: Int = 0
    ) -> DescriptorMap {
        let path: String
        if pathIndex == -1 {
            path = "$"
        }
        else {
            path = "$[\(pathIndex)]"
        }

        let pathNested = Path(
            format: "jwt_vc_json",
            path: "$.vp.verifiableCredential[\(pathNestedIndex)]"
        )

        return DescriptorMap(
            id: inputDescriptorId,
            format: "jwt_vp_json",
            path: path,
            pathNested: pathNested
        )
    }
}
