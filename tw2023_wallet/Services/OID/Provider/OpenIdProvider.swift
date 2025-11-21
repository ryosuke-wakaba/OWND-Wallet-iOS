//
//  OpenIdProvider.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2024/01/03.
//

import Foundation
import JOSESwift

class NoRedirectDelegate: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession, task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest,
        completionHandler: @escaping (URLRequest?) -> Void
    ) {
        // リダイレクトを停止する
        completionHandler(nil)
    }
}

class OpenIdProvider {
    private var option: ProviderOption
    private var secp256k1KeyPair: KeyPairData?  // for sub of id_token
    private var keyBinding: KeyBinding?
    private var jwtVpJsonGenerator: JwtVpJsonGenerator?
    var authRequestProcessedData: ProcessedRequestData?
    var clientId: String?
    var responseType: String?
    var responseMode: ResponseMode?
    var nonce: String?
    var state: String?
    var redirectUri: String?
    var responseUri: String?
    var dcqlQuery: DcqlQuery?

    init(_ option: ProviderOption) {
        self.option = option
    }

    func setSecp256k1KeyPair(keyPair: KeyPairData) {
        self.secp256k1KeyPair = keyPair
    }

    func setKeyBinding(keyBinding: KeyBinding) {
        self.keyBinding = keyBinding
    }

    func setJwtVpJsonGenerator(jwtVpJsonGenerator: JwtVpJsonGenerator) {
        self.jwtVpJsonGenerator = jwtVpJsonGenerator
    }

    func processAuthRequest(_ url: String, using session: URLSession = URLSession.shared) async
        -> Result<ProcessedRequestData, AuthorizationRequestError>
    {
        print("parseAndResolve")
        let processedRequestDataResult = await parseAndResolve(from: url)
        switch processedRequestDataResult {
            case .success(let processedRequestData):
                let authRequest = processedRequestData.authorizationRequest
                let requestObj = processedRequestData.requestObject
                guard let _clientId = authRequest.clientId else {
                    return .failure(
                        .authRequestInputError(
                            reason: .compliantError(reason: "can not get client id")))
                }
                clientId = _clientId

                if processedRequestData.requestIsSigned {
                    print("verify request jwt")
                    let clientScheme = requestObj!.clientIdScheme
                    let jwt = processedRequestData.requestObjectJwt

                    // OID4VP 1.0: Check Client Identifier Prefix format
                    let isX509SanDns = clientScheme == "x509_san_dns" || _clientId.hasPrefix("x509_san_dns:")
                    let isX509Hash = _clientId.hasPrefix("x509_hash:")

                    if isX509SanDns || isX509Hash {
                        // Skip certificate chain validation for development (self-signed certs)
                        let result = JWTUtil.verifyJwtByX5C(jwt: jwt, verifyCertChain: false)
                        switch result {
                            case .success(let verifedX5CJwt):
                                print("verify request jwt success")
                                let (decoded, certificates) = verifedX5CJwt

                                if isX509SanDns {
                                    // x509_san_dns: Verify SAN DNS name
                                    // Extract domain from client_id (with or without prefix)
                                    let domainName: String
                                    if _clientId.hasPrefix("x509_san_dns:") {
                                        domainName = String(_clientId.dropFirst("x509_san_dns:".count))
                                    } else if let url = URL(string: _clientId), let host = url.host {
                                        domainName = host
                                    } else {
                                        return .failure(
                                            .authRequestInputError(
                                                reason: .compliantError(
                                                    reason: "Unable to get domain name from client_id")))
                                    }

                                    if isDomainInSAN(certificate: certificates[0], domain: domainName) {
                                        print("verify san entry success")
                                    } else {
                                        return .failure(
                                            .authRequestInputError(
                                                reason: .compliantError(
                                                    reason: "Invalid client_id not in san entry of cert"
                                                )
                                            ))
                                    }

                                    // Verify response_uri/redirect_uri host matches client_id domain
                                    if let urlString = requestObj?.responseUri ?? requestObj?.redirectUri,
                                       let url = URL(string: urlString),
                                       let urlHost = url.host {
                                        if urlHost == domainName {
                                            print("verify client_id and url success")
                                        } else {
                                            return .failure(
                                                .authRequestInputError(
                                                    reason: .compliantError(
                                                        reason: "Invalid client_id or response_uri(redirect_uri)"
                                                    )
                                                ))
                                        }
                                    }
                                } else if isX509Hash {
                                    // x509_hash: Verify certificate hash matches client_id
                                    let hashValue = String(_clientId.dropFirst("x509_hash:".count))
                                    let calculatedHash = calculateX509CertificateHash(certificates[0])

                                    if calculatedHash == hashValue {
                                        print("verify x509_hash success")
                                    } else {
                                        print("x509_hash mismatch: expected=\(hashValue), got=\(calculatedHash ?? "nil")")
                                        return .failure(
                                            .authRequestInputError(
                                                reason: .compliantError(
                                                    reason: "Certificate hash does not match client_id"
                                                )
                                            ))
                                    }
                                    // Note: For x509_hash, response_uri/redirect_uri host validation is not required
                                    print("x509_hash client_id verified")
                                }

                            case .failure(let error):
                                print("\(error)")
                                return .failure(
                                    .authRequestInputError(
                                        reason: .compliantError(
                                            reason: "JWT verification failed")
                                    ))
                        }
                    }
                    else {
                        let clientMetadata = processedRequestData.clientMetadata
                        let result = await verifyRequestObject(
                            jwt: jwt, clientMetadata: clientMetadata)
                        switch result {
                            case .success:
                                print("verify request jwt success")
                            case .failure(let error):
                                return .failure(error)
                        }
                    }
                }

                // OID4VP 1.0: Determine client scheme from client_id prefix or client_id_scheme
                let clientScheme: String
                if _clientId.hasPrefix("x509_san_dns:") {
                    clientScheme = "x509_san_dns"
                } else if _clientId.hasPrefix("x509_hash:") {
                    clientScheme = "x509_hash"
                } else if _clientId.hasPrefix("redirect_uri:") {
                    clientScheme = "redirect_uri"
                } else {
                    clientScheme = requestObj?.clientIdScheme ?? authRequest.clientIdScheme ?? "redirect_uri"
                }

                if clientScheme == "redirect_uri" {
                    // For redirect_uri scheme, client_id must match response_uri
                    let responseUri = requestObj?.responseUri ?? authRequest.responseUri
                    let clientIdValue = _clientId.hasPrefix("redirect_uri:")
                        ? String(_clientId.dropFirst("redirect_uri:".count))
                        : _clientId
                    if clientIdValue != responseUri {
                        return .failure(
                            .authRequestInputError(
                                reason: .compliantError(reason: "Invalid client_id or response_uri")
                            ))
                    }
                }
                // Note: x509_san_dns and x509_hash schemes are already validated above

                guard let _responseType = requestObj?.responseType ?? authRequest.responseType
                else {
                    return .failure(
                        .authRequestInputError(
                            reason: .compliantError(reason: "can not get response type")))
                }
                responseType = _responseType

                // https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#section-5-11.6
                // response_mode:
                // OPTIONAL. Defined in [OAuth.Responses]. This parameter is used (through the new Response Mode direct_post) to ask the Wallet to send the response to the Verifier via an HTTPS connection (see Section 6.2 for more details). It is also used to request signing and encrypting (see Section 6.3 for more details). If the parameter is not present, the default value is fragment.
                if let _responseMode = requestObj?.responseMode ?? authRequest.responseMode {
                    responseMode = _responseMode
                }
                else {
                    responseMode = ResponseMode.fragment
                }
                guard let _nonce = requestObj?.nonce ?? authRequest.nonce else {
                    return .failure(
                        .authRequestInputError(reason: .compliantError(reason: "can not get nonce"))
                    )
                }
                nonce = _nonce
                state = requestObj?.state ?? authRequest.state ?? ""
                if _responseType.contains("vp_token") {
                    guard let _dcqlQuery = processedRequestData.dcqlQuery
                    else {
                        return .failure(
                            .authRequestInputError(
                                reason: .compliantError(
                                    reason: "can not get dcql query")))
                    }
                    dcqlQuery = _dcqlQuery
                }
                if responseMode == ResponseMode.directPost
                    || responseMode == ResponseMode.directPostJwt
                    || responseMode == ResponseMode.post
                {
                    guard let _responseUri = requestObj?.responseUri ?? authRequest.responseUri
                    else {
                        return .failure(
                            .authRequestInputError(
                                reason: .compliantError(reason: "can not get response uri")))
                    }
                    responseUri = _responseUri
                }
                else {
                    guard let _redirectUri = requestObj?.redirectUri ?? authRequest.redirectUri
                    else {
                        return .failure(
                            .authRequestInputError(
                                reason: .compliantError(reason: "can not get redirect uri")))
                    }
                    redirectUri = _redirectUri
                }
                self.authRequestProcessedData = processedRequestData
                return .success(processedRequestData)
            case .failure(let error):
                return .failure(error)
        }
    }

    func respondToken(
        credentials: [SubmissionCredential]?,
        using session: URLSession = URLSession.shared
    ) async -> Result<
        TokenSendResult, Error
    > {
        guard let responseType = responseType else {
            print("responseType is not setup")
            return .failure(OpenIdProviderIllegalStateException.illegalResponseTypeState)
        }

        guard let responseMode = responseMode else {
            return .failure(OpenIdProviderIllegalStateException.illegalResponseModeState)
        }

        let requireIdToken = responseType.contains("id_token")
        let requireVpToken = responseType.contains("vp_token")

        if !requireIdToken && !requireVpToken {
            print("Both or either `id_token` and `vp_token` are required.")
            return .failure(OpenIdProviderIllegalStateException.illegalResponseTypeState)
        }

        var idTokenFormData: [String: String]? = nil
        var vpTokenFormData: [String: String]? = nil

        var idTokenForHistory: String? = nil
        var vpForHistory: [SharedCredential]? = nil

        if requireIdToken {
            let created = createSiopIdToken()
            switch created {
                case .success(let (successData, rawIdToken)):
                    idTokenFormData = successData
                    idTokenForHistory = rawIdToken
                case .failure(let errorData):
                    return .failure(errorData)
            }
        }
        if requireVpToken {
            guard let creds = credentials else {
                return .failure(OpenIdProviderIllegalInputException.illegalCredentialInput)
            }
            let created = createVpToken(credentials: creds)
            switch created {
                case .success(let (successData, sharedCredentials)):
                    vpTokenFormData = successData
                    vpForHistory = sharedCredentials
                case .failure(let errorData):
                    return .failure(errorData)
            }
        }

        let mergedFormData = (idTokenFormData ?? [:]).merging(vpTokenFormData ?? [:]) { (_, new) in
            new
        }

        var uri: String? = nil
        switch responseMode {
            case .directPost, .directPostJwt, .post:
                uri = responseUri
            default:
                uri = redirectUri
        }
        guard let whereToRespond = uri else {
            return .failure(OpenIdProviderIllegalStateException.illegalRedirectUriState)
        }

        do {
            let (data, httpResponse, uri) = try await sendFormData(
                formData: mergedFormData,
                url: URL(string: whereToRespond)!,
                responseMode: responseMode,
                clientMetadata: authRequestProcessedData?.clientMetadata,
                using: session
            )

            let (statusCode, location, cookies) = try convertVerifierResponse(
                data: data, response: httpResponse, requestURL: uri)

            print("status code: \(statusCode)")
            return .success(
                TokenSendResult(
                    statusCode: statusCode, location: location, cookies: cookies,
                    sharedIdToken: idTokenForHistory,
                    sharedCredentials: vpForHistory))
        }
        catch {
            return .failure(error)
        }

    }

    func createSiopIdToken() -> Result<([String: String], String), Error> {
        guard let authRequestProcessedData = self.authRequestProcessedData else {
            return .failure(
                OpenIdProviderIllegalStateException.illegalAuthRequestProcessedDataState)
        }
        let authRequest = authRequestProcessedData.authorizationRequest
        let requestObj = authRequestProcessedData.requestObject
        guard let clientId = requestObj?.clientId ?? authRequest.clientId else {
            return .failure(OpenIdProviderIllegalStateException.illegalClientIdState)
        }
        guard let nonce = requestObj?.nonce ?? authRequest.nonce else {
            return .failure(OpenIdProviderIllegalStateException.illegalNonceState)
        }

        // TODO: ProviderOptionのアルゴリズムで分岐可能にする
        guard let keyPair = secp256k1KeyPair else {
            return .failure(OpenIdProviderIllegalStateException.illegalKeypairState)
        }
        let x = keyPair.publicKey.0.base64URLEncodedString()
        let y = keyPair.publicKey.1.base64URLEncodedString()
        let jwk = ECPublicJwk(kty: "EC", crv: "secp256k1", x: x, y: y)
        guard let jwkThumbprint = SignatureUtil.toJwkThumbprint(jwk: jwk) else {
            return .failure(OpenIdProviderIllegalStateException.illegalJwkThumbprintState)
        }

        let prefix = "urn:ietf:params:oauth:jwk-thumbprint:sha-256"
        let sub = "\(prefix):\(jwkThumbprint)"
        let currentMilliseconds = Int64(Date().timeIntervalSince1970 * 1000)

        let idTokenPayload = IDTokenPayloadImpl(
            iss: sub,
            sub: sub,
            aud: clientId,
            iat: currentMilliseconds / 1000,
            exp: (currentMilliseconds / 1000) + option.expiresIn,
            nonce: nonce,
            subJwk: [
                "crv": jwk.crv,
                "kty": jwk.kty,
                "x": jwk.x,
                "y": jwk.y,
            ]
        )
        do {
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let jsonData = try encoder.encode(idTokenPayload)
            let payload = String(data: jsonData, encoding: .utf8)!
            let idToken = try ES256K.createJws(key: keyPair.privateKey, payload: payload)
            let formData = ["id_token": idToken]

            return .success((formData, idToken))
        }
        catch {
            return .failure(error)
        }
    }

    func createVpToken(
        credentials: [SubmissionCredential],
        using session: URLSession = URLSession.shared
    ) -> Result<([String: String], [SharedCredential]), Error> {

        guard let clientId = clientId,
            let responseMode = responseMode,
            let nonce = nonce
        else {
            print("[createVpToken] illegalState - clientId: \(String(describing: self.clientId)), responseMode: \(String(describing: self.responseMode)), nonce: \(String(describing: self.nonce))")
            return .failure(OpenIdProviderIllegalStateException.illegalState)
        }

        let isMultipleVpTokens = credentials.count > 1
        let preparedSubmissionData = try! credentials.enumerated().compactMap {
            (index, credential) -> PreparedSubmissionData? in
            let tokenIndex = isMultipleVpTokens ? index : index - 1
            let credentialFormat = CredentialFormat(formatString: credential.format)

            if credentialFormat?.isSDJWT == true {
                return
                    try credential.createVpTokenForSdJwtVc(
                        clientId: clientId,
                        nonce: nonce,
                        tokenIndex: index,
                        keyBinding: keyBinding)
            }
            else if credentialFormat == .jwtVCJson {
                return
                    try credential.createVpTokenForJwtVc(
                        clientId: clientId,
                        nonce: nonce,
                        tokenIndex: index,
                        jwtVpJsonGenerator: jwtVpJsonGenerator

                    )
            }
            else {
                    throw IllegalArgumentException.badParams
            }
        }

        guard let vpTokenValue = conformToFormData(preparedData: preparedSubmissionData) else {
            return .failure(OpenIdProviderIllegalStateException.illegalJsonState)
        }

        let sharedCredentials = preparedSubmissionData.map {
            SharedCredential(
                id: $0.credentialId,
                purposeForSharing: $0.purpose,
                sharedClaims: $0.disclosedClaims)
        }

        // OID4VP 1.0: vp_token only, no presentation_submission
        var formData = ["vp_token": vpTokenValue]
        if let state = state {
            formData["state"] = state
        }

        return .success((formData, sharedCredentials))
    }

    func convertVerifierResponse(data: Data, response: HTTPURLResponse, requestURL: URL)
        throws -> (Int, String?, [String]?)
    {
        let statusCode = response.statusCode
        if statusCode == 200 {
            if let contentType = response.allHeaderFields["Content-Type"] as? String {
                if contentType.hasPrefix("application/json") {
                    guard
                        let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                        let jsonDict = jsonObject as? [String: Any]
                    else {
                        throw AuthorizationError.invalidData
                    }
                    let location = jsonDict["redirect_uri"] as? String
                    return (statusCode, location, nil)
                }
            }
        }
        return (statusCode, nil, nil)
    }

    /*

    The following code contains an implementation that is contrary to the current specification.
    During initial development, a special implementation was required for the purpose of connecting to Matrix's Synapse server.
    The following code needs to be removed at an appropriate time.

    Specification:

     https://openid.net/specs/openid-4-verifiable-presentations-1_0-ID2.html#section-6.2
     If the Response Endpoint has successfully processed the request, it MUST respond with HTTPS status code 200.

     https://openid.net/specs/openid-connect-self-issued-v2-1_0.html#section-10.2
     The Self-Issued OP MUST NOT follow redirects on this request


    func convertIdTokenResponseResponse(data: Data, response: HTTPURLResponse, requestURL: URL)
        throws -> (Int, String?, [String]?)
    {
        //        print("response body of siop response: \(String(data: data, encoding: .utf8) ?? "no utf string value")")
        var cookies: [String]? = nil
        if let setCookieHeader = response.allHeaderFields["Set-Cookie"] as? String {
            cookies = [setCookieHeader]
        }
        else if let setCookieHeaders = response.allHeaderFields["Set-Cookie"] as? [String] {
            cookies = setCookieHeaders
        }
        if response.statusCode == 302 {
            if let locationHeader = response.allHeaderFields["Location"] as? String {
                print("Location Header: \(locationHeader)")
                let location: String
                if locationHeader.starts(with: "http://") || locationHeader.starts(with: "https://")
                {
                    location = locationHeader
                }
                else {
                    let scheme = requestURL.scheme ?? "http"
                    let host = requestURL.host ?? ""
                    let port = requestURL.port.map { ":\($0)" } ?? ""
                    location = "\(scheme)://\(host)\(port)\(locationHeader)"
                }
                return (response.statusCode, location, cookies)
            }
            else {
                throw NetworkError.invalidResponse  // 適切なエラー処理を行う
            }
        }
        else {
            return (response.statusCode, nil, cookies)
        }
    }

    func convertVpTokenResponseResponse(data: Data, response: HTTPURLResponse, requestURL: URL)
        throws -> (Int, String?, [String]?)
    {
        let statusCode = response.statusCode
        if statusCode == 200 {
            if let contentType = response.allHeaderFields["Content-Type"] as? String {
                if contentType.hasPrefix("application/json") {
                    guard
                        let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
                        let jsonDict = jsonObject as? [String: Any]
                    else {
                        throw AuthorizationError.invalidData
                    }
                    let location = jsonDict["redirect_uri"] as? String
                    return (statusCode, location, nil)
                }
            }
        }
        if response.statusCode == 302 {
            if let locationHeader = response.allHeaderFields["Location"] as? String {
                var location: String? = nil
                if locationHeader.starts(with: "http://") || locationHeader.starts(with: "https://")
                {
                    location = locationHeader
                }
                else {
                    let scheme = requestURL.scheme ?? "http"
                    let host = requestURL.host ?? ""
                    let port = requestURL.port.map { ":\($0)" } ?? ""
                    location = "\(scheme)://\(host)\(port)\(locationHeader)"
                }
                return (response.statusCode, location, nil)
            }
            else {
                throw NetworkError.invalidResponse
            }
        }

        return (statusCode, nil, nil)
    }
     */

}
