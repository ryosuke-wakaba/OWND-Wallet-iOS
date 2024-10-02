//
//  ProviderTypes.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2024/10/02.
//

struct ProviderOption {
    let signingCurve: String = "secp256k1"
    let signingAlgo: String = "ES256K"
    let expiresIn: Int64 = 600
}

struct PostResult: Decodable {
    let statusCode: Int
    let location: String?
    let cookies: [String]?
}

struct PreparedSubmissionData {
    let vpToken: String
    let descriptorMap: DescriptorMap
    let disclosedClaims: [DisclosedClaim]
    let purpose: String?
}

struct SubmissionCredential: Codable, Equatable {
    let id: String
    let format: String
    let types: [String]
    let credential: String
    let inputDescriptor: InputDescriptor
    let discloseClaims: [DisclosureWithOptionality]

    static func == (lhs: SubmissionCredential, rhs: SubmissionCredential) -> Bool {
        return lhs.id == rhs.id
    }
}

struct DisclosedClaim: Codable {
    let id: String  // credential identifier
    let types: [String]
    let name: String
    let value: String?
    // let path: String   // when nested claim is supported, it may be needed
}

struct SharedContent: Codable {
    let id: String
    let sharedClaims: [DisclosedClaim]
}
