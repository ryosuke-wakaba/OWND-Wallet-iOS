//
//  PresentationExchange.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/30.
//

import Foundation

var decodeDisclosureFunction: ([String]) -> [Disclosure] = SDJwtUtil.decodeDisclosure

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

    func matchSdJwtVcToRequirement(sdJwt: String) -> (
        InputDescriptor, [DisclosureWithOptionality]
    )? {
        guard let sdJwtParts = try? SDJwtUtil.divideSDJwt(sdJwt: sdJwt) else {
            return nil
        }

        // [Disclosure]
        let allDisclosures = decodeDisclosureFunction(sdJwtParts.disclosures)
        let sourcePayload = Dictionary(
            uniqueKeysWithValues: allDisclosures.compactMap { disclosure in
                if let key = disclosure.key, let value = disclosure.value {
                    return (key, value)
                }
                else {
                    return nil
                }
            })

        // 各InputDescriptorをループ
        for inputDescriptor in inputDescriptors {
            // fieldKeysを取得
            let requiredOrOptionalKeys = inputDescriptor.filterKeysWithOptionality(
                from: sourcePayload)

            let matchingDisclosures = createDisclosureWithOptionality(
                from: allDisclosures,
                with: requiredOrOptionalKeys
            )

            if !matchingDisclosures.isEmpty {
                return (inputDescriptor, matchingDisclosures)
            }
        }
        return nil
    }
    private func createDisclosureWithOptionality(
        from allDisclosures: [Disclosure], with requiredOrOptionalKeys: [(String, Bool)]
    ) -> [DisclosureWithOptionality] {
        return allDisclosures.map { disclosure in
            guard let dkey = disclosure.key else {
                return DisclosureWithOptionality(
                    disclosure: disclosure, isSubmit: false, isUserSelectable: false)
            }
            for (keyName, optionality) in requiredOrOptionalKeys {
                if keyName.contains(dkey) {
                    return DisclosureWithOptionality(
                        disclosure: disclosure, isSubmit: !optionality,
                        isUserSelectable: optionality)
                }
            }
            return DisclosureWithOptionality(
                disclosure: disclosure, isSubmit: false, isUserSelectable: false)
        }
    }

    func satisfyConstrains(credential: [String: Any])
        -> Bool
    {
        // TODO: 暫定で固定パス(vc.credentialSubject)のクレデンシャルをサポートする
        guard let vc = credential["vc"] as? [String: Any] else {
            print("unsupported format")
            print(credential)
            return false
        }
        guard let credentialSubject: [String: Any] = vc["credentialSubject"] as? [String: Any]
        else {
            print("unsupported format")
            print(credential)
            return false
        }
        let inputDescriptors = inputDescriptors

        var matchingFieldsCount = 0

        for inputDescriptor in inputDescriptors {
            guard let fields = inputDescriptor.constraints.fields else { continue }

            for field in fields {
                let isFieldMatched = field.path.contains { jsonPath -> Bool in
                    let pathComponents = jsonPath.components(separatedBy: ".")
                    if let lastComponent = pathComponents.last, lastComponent != "$" {
                        let key = lastComponent.replacingOccurrences(of: "vc.", with: "")
                        // credentialのキーとして含まれているか判定
                        return credentialSubject.keys.contains(key)
                    }
                    return false
                }

                if isFieldMatched {
                    matchingFieldsCount += 1
                    break  // pathのいずれかがマッチしたら、そのfieldは条件を満たしていると見なす
                }
            }
        }

        print("match count: \(matchingFieldsCount)")
        // 元のfieldsの件数と該当したfieldの件数が一致するか判定
        return matchingFieldsCount == inputDescriptors.compactMap({ $0.constraints.fields }).count
    }
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

    func filterKeysWithOptionality(
        from sourcePayload: [String: String]
    ) -> [(String, Bool)] {
        /*
     array of (String, Bool) values filtered by `inputDescriptor.constraints.fields.path`
     A Bool value represents whether the field is required.

     example of input_descriptors
         "input_descriptors": [
           {
             "constraints": {
               "fields": [
                 {
                   "path": ["$.claim1"], ここが配列になっている理由はformat毎に異なるpathを指定するため
                   "optional": true
                 }
               ]
             }
           }
         ]
     */
        guard let fields = constraints.fields else { return [] }
        return fields.flatMap { field in
            let optional = field.optional ?? false
            return field.path.compactMap { jsonPath in
                let key = String(jsonPath.dropFirst(2))  // "$."を削除
                return sourcePayload.keys.contains(key) ? (key, optional) : nil
            }
        }
    }
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

    // If the value of `isUserSelectable` is `true`, the value of `isSubmit`
    // is a mutable that can be changed by the user (via toggle operation).
    var isSubmit: Bool
    var isUserSelectable: Bool

    init(disclosure: Disclosure, isSubmit: Bool, isUserSelectable: Bool) {
        self.disclosure = disclosure
        self.isSubmit = isSubmit
        self.isUserSelectable = isUserSelectable
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

        /*
         Add a comment regarding the leading `$`.
         In VP draft 18 (ID 2), when sending `vp_token` as an array, the correct notation is `$[N].`.
         However, in draft 21, the correct notation is `$.`. (In other words, it is a relative path)

         For now, we will keep the current implementation, but it should be adjusted accordingly based on the specification we adopt.
         */
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
