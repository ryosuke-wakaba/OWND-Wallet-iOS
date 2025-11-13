//
//  TokenIssuer.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/26.
//

import Foundation

enum VCIClientError: Error {
    case undecodableCredentialOffer(json: String)
    case retrieveMetaDataError(error: MetadataError)
    case tokenEndpointIsRequired
    case credentialEndpointIsRequiredG
    case unsupportedCredentialFormat(format: String)
    case credentialEndpointIsRequired
    case jwtProofRequired
    case nonceEndpointIsRequired  // OID4VCI 1.0
}

struct GrantAuthorizationCode: Codable {
    let issuerState: String?
    let authorizationServer: String?
}

struct TxCode: Codable {
    let inputMode: String?
    let length: Int?
    let description: String?
    enum CodingKeys: String, CodingKey {
        case inputMode = "inputMode"  // It is assumed that the snake case strategy is configured.
        case length, description
    }
}

struct GrantPreAuthorizedCode: Codable {
    let preAuthorizedCode: String
    let txCode: TxCode?
    var interval: Int? = 5
    let authorizationServer: String?

    // It is assumed that the snake case strategy is configured.
    enum CodingKeys: String, CodingKey {
        case preAuthorizedCode = "pre-authorizedCode"
        case txCode = "txCode"
        case authorizationServer = "authorizationServer"
        case interval
    }
}

struct Grant: Codable {
    let authorizationCode: GrantAuthorizationCode?
    let preAuthorizedCode: GrantPreAuthorizedCode?

    // It is assumed that the snake case strategy is configured.
    enum CodingKeys: String, CodingKey {
        case authorizationCode = "authorizationCode"
        case preAuthorizedCode = "urn:ietf:params:oauth:grant-type:pre-authorizedCode"
    }
}

struct CredentialOffer: Codable {
    let credentialIssuer: String
    let credentialConfigurationIds: [String]
    let grants: Grant?

    func isTxCodeRequired() -> Bool {
        if let grants = self.grants,
            let preAuthCodeInfo = grants.preAuthorizedCode,
            let _ = preAuthCodeInfo.txCode
        {
            return true
        }
        else {
            return false
        }
    }

    private static func getCredentialOfferParameter(_ credentialOffer: String) -> String? {
        guard let url = URL(string: credentialOffer),
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
            let queryItems = components.queryItems,
            let credentialOfferValue = queryItems.first(where: { $0.name == "credential_offer" })?
                .value
        else {
            return nil
        }

        return credentialOfferValue
    }
    static func fromString(_ credentialOffer: String) -> CredentialOffer? {
        guard let jsonString = getCredentialOfferParameter(credentialOffer),
            let jsonData = jsonString.data(using: .utf8)
        else {
            return nil
        }
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(CredentialOffer.self, from: jsonData)
        }
        catch {
            return nil
        }
    }
}

struct OAuthTokenRequest: Codable {
    let grantType: String

    // Defined as mandatory in RFC 6749.
    // However, it is not used in the case of pre-authorized_code.
    let code: String?

    // REQUIRED, if the "redirect_uri" parameter was included
    // in the authorization request
    let redirectUri: String?

    // REQUIRED, if the client is not authenticating
    // with the authorization server
    let clientId: String?

    /* Extension parameters to the Token Request used in the Pre-Authorized Code Flow */

    // This parameter MUST be present
    // if the grant_type is urn:ietf:params:oauth:grant-type:pre-authorized_code
    let preAuthorizedCode: String?
    let txCode: String?

    // It is assumed that the snake case strategy is configured.
    enum CodingKeys: String, CodingKey {
        case code
        case grantType = "grantType"
        case redirectUri = "redirectUri"
        case clientId = "clientId"
        case preAuthorizedCode = "pre-authorizedCode"
        case txCode = "txCode"
    }
}

struct OAuthTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let cNonce: String?
    let cNonceExpiresIn: Int?
}

struct CredentialRequestCredentialResponseEncryption: Codable {

    // todo: Add the JWK property with the appropriate data type.
    // let jwk: ...

    let alg: String
    let enc: String
}

struct LdpVpProofClaim: Codable {
    let domain: String

    // REQUIRED when the Credential Issuer has provided a c_nonce. It MUST NOT be used otherwise
    let challenge: String?
}

struct LdpVp: Codable {
    // todo: improve type definition
    let holder: String
    let proof: [LdpVpProofClaim]
}

protocol Proofable: Codable {
    var proofType: String { get }
}

struct JwtProof: Proofable {
    let proofType: String
    let jwt: String
}

struct CwtProof: Proofable {
    let proofType: String
    let cwt: String
}

struct LdpVpProof: Proofable {
    let proofType: String
    let ldpVp: LdpVp
}

// OID4VCI 1.0: New proof structure
struct Proofs: Codable {
    let jwt: [String]?
    let cwt: [String]?
    let ldpVp: [String]?

    enum CodingKeys: String, CodingKey {
        case jwt
        case cwt
        case ldpVp = "ldp_vp"
    }
}

// OID4VCI 1.0: Nonce endpoint response
struct NonceResponse: Codable {
    let cNonce: String
}

// OID4VCI 1.0: Simplified credential request
struct CredentialRequestV1: Codable {
    let credentialConfigurationId: String
    let proofs: Proofs?

    // REQUIRED when credential_identifiers parameter was returned from the Token Response.
    // It MUST NOT be used otherwise
    let credentialIdentifier: String?
    let credentialResponseEncryption: CredentialRequestCredentialResponseEncryption?
}

struct CredentialResponse: Codable {
    let credential: String?  // todo suppoert `ldp_vc`
    let transactionId: String?
    let cNonce: String?
    let cNonceExpiresIn: Int?
    let notificationId: String?
}

// OID4VCI 1.0: Simplified credential request creation
func createCredentialRequest(
    credentialConfigurationId: String,
    proofs: Proofs?
) -> CredentialRequestV1 {
    return CredentialRequestV1(
        credentialConfigurationId: credentialConfigurationId,
        proofs: proofs,
        credentialIdentifier: nil,
        credentialResponseEncryption: nil
    )
}

func postTokenRequest(
    to url: URL, with tokenRequest: OAuthTokenRequest, using session: URLSession = URLSession.shared
) async throws -> OAuthTokenResponse {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

    let encoder = URLEncodedFormEncoder()
    request.httpBody = try encoder.encode(tokenRequest)

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw URLError(.badServerResponse)
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(OAuthTokenResponse.self, from: data)
}

func postCredentialRequest(
    _ credentialRequest: CredentialRequestV1, to url: URL, accessToken: String,
    using session: URLSession = URLSession.shared
) async throws -> CredentialResponse {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

    // OID4VCI 1.0: Simplified request encoding
    let encoder = JSONEncoder()
    encoder.keyEncodingStrategy = .convertToSnakeCase

    let payload = try encoder.encode(credentialRequest)
    request.httpBody = payload

    if let jsonString = String(data: payload, encoding: .utf8) {
        print("Credential Request JSON: \(jsonString)")
    }

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw URLError(.badServerResponse)
    }

    // レスポンスデータをデコード
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(CredentialResponse.self, from: data)
}

// OID4VCI 1.0: Nonce Endpoint (not a protected resource)
func postNonceRequest(
    to url: URL, using session: URLSession = URLSession.shared
) async throws -> NonceResponse {
    var request = URLRequest(url: url)
    request.httpMethod = "POST"

    let (data, response) = try await session.data(for: request)

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw URLError(.badServerResponse)
    }

    // Decode nonce response
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return try decoder.decode(NonceResponse.self, from: data)
}

class VCIClient {

    private var metadata: Metadata
    private var tokenEndpoint: URL
    private var credentialEndpoint: URL
    private(set) var credentialOffer: CredentialOffer

    init(credentialOffer: CredentialOffer, metaData: Metadata) async throws {
        // set `credentialOffer`
        self.credentialOffer = credentialOffer
        // set `metadata`
        self.metadata = metaData
        // set `tokenEndpoint`
        guard let tokenUrlString = metadata.authorizationServerMetadata.tokenEndpoint,
            let tokenUrl = URL(string: tokenUrlString)
        else {
            throw VCIClientError.tokenEndpointIsRequired
        }
        tokenEndpoint = tokenUrl
        // set `credentialEndpoint`
        guard
            let credentialEndpointUrl = URL(
                string: metadata.credentialIssuerMetadata.credentialEndpoint)
        else {
            throw VCIClientError.credentialEndpointIsRequired
        }
        credentialEndpoint = credentialEndpointUrl
    }

    func issueToken(txCode: String?, using session: URLSession = URLSession.shared) async throws
        -> OAuthTokenResponse
    {
        let grants = credentialOffer.grants

        let tokenRequest: OAuthTokenRequest = OAuthTokenRequest(
            grantType: "urn:ietf:params:oauth:grant-type:pre-authorized_code",
            code: nil,
            redirectUri: nil,
            clientId: nil,
            preAuthorizedCode: grants?.preAuthorizedCode?.preAuthorizedCode,
            txCode: txCode
        )

        return try await postTokenRequest(
            to: tokenEndpoint, with: tokenRequest, using: session)
    }

    func issueCredential(
        payload: CredentialRequestV1, accessToken: String,
        using session: URLSession = URLSession.shared
    ) async throws -> CredentialResponse {
        return try await postCredentialRequest(
            payload, to: credentialEndpoint, accessToken: accessToken, using: session)
    }

    // OID4VCI 1.0: Fetch nonce from dedicated nonce endpoint
    func fetchNonce(using session: URLSession = URLSession.shared) async throws -> NonceResponse {
        guard let nonceEndpointString = metadata.credentialIssuerMetadata.nonceEndpoint,
            let nonceEndpointUrl = URL(string: nonceEndpointString)
        else {
            throw VCIClientError.nonceEndpointIsRequired
        }

        return try await postNonceRequest(to: nonceEndpointUrl, using: session)
    }
}
