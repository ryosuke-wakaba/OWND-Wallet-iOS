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
    private var keyPair: KeyPair?  // for proof of posession for jwt_vc_json presentation
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
    var presentationDefinition: PresentationDefinition?

    init(_ option: ProviderOption) {
        self.option = option
    }

    func setKeyPair(keyPair: KeyPair) {
        self.keyPair = keyPair
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
                    if clientScheme == "x509_san_dns" {
                        let result = JWTUtil.verifyJwtByX5C(jwt: jwt)
                        switch result {
                            case .success(let verifedX5CJwt):
                                print("verify request jwt success")
                                // https://openid.net/specs/openid-4-verifiable-presentations-1_0.html
                                /*
                            the Client Identifier MUST be a DNS name and match a dNSName Subject Alternative Name (SAN) [RFC5280] entry in the leaf certificate passed with the request.
                             */
                                let (decoded, certificates) = verifedX5CJwt

                                guard let url = URL(string: _clientId),
                                    let domainName = url.host
                                else {
                                    return .failure(
                                        .authRequestInputError(
                                            reason: .compliantError(
                                                reason: "Unable to get host name")))
                                }

                                if isDomainInSAN(certificate: certificates[0], domain: domainName) {
                                    print("verify san entry success")
                                }
                                else {
                                    return .failure(
                                        .authRequestInputError(
                                            reason: .compliantError(
                                                reason: "Invalid client_id not in san entry of cert"
                                            )
                                        ))
                                }

                                if let urlString = requestObj?.responseUri
                                    ?? requestObj?.redirectUri,
                                    let url = URL(string: urlString)
                                {
                                    if let clientUrl = URL(string: _clientId),
                                        let urlHost = url.host, let clientIdHost = clientUrl.host,
                                        urlHost == clientIdHost
                                    {

                                        print("verify client_id and url success")
                                    }
                                    else {
                                        return .failure(
                                            .authRequestInputError(
                                                reason: .compliantError(
                                                    reason:
                                                        "Invalid client_id or response_uri(redirect_uri)"
                                                )
                                            ))
                                    }
                                }

                            case .failure(let error):
                                print("\(error)")
                                return .failure(
                                    .authRequestInputError(
                                        reason: .compliantError(
                                            reason: "Invalid client_id or response_uri")
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

                let clientScheme =
                    requestObj?.clientIdScheme ?? authRequest.clientIdScheme ?? "redirect_uri"
                if clientScheme == "redirect_uri" {
                    let responseUri = requestObj?.responseUri ?? authRequest.responseUri
                    if clientId != responseUri {
                        return .failure(
                            .authRequestInputError(
                                reason: .compliantError(reason: "Invalid client_id or response_uri")
                            ))
                    }
                }

                guard let responseType = requestObj?.responseType ?? authRequest.responseType else {
                    return .failure(
                        .authRequestInputError(
                            reason: .compliantError(reason: "can not get response type")))
                }
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
                if responseType.contains("vp_token") {
                    guard let _presentationDefinition = processedRequestData.presentationDefinition
                    else {
                        return .failure(
                            .authRequestInputError(
                                reason: .compliantError(
                                    reason: "can not get presentation definition")))
                    }
                    presentationDefinition = _presentationDefinition
                }
                if responseMode == ResponseMode.directPost {
                    guard let _responseUri = requestObj?.responseUri ?? authRequest.responseUri
                    else {
                        return .failure(
                            .authRequestInputError(
                                reason: .compliantError(reason: "can not get response uri")))
                    }
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

    func respondSIOPResponse(using session: URLSession = URLSession.shared) async -> Result<
        PostResult, Error
    > {
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
        guard let redirectUri = requestObj?.redirectUri ?? authRequest.requestUri else {
            return .failure(OpenIdProviderIllegalStateException.illegalRedirectUriState)
        }

        let prefix = "urn:ietf:params:oauth:jwk-thumbprint:sha-256"
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
            // TODO: support redirect response when response_mode is not `direct_post`
            let formData = ["id_token": idToken]
            print("url: \(redirectUri)")
            print(formData)
            let postResult = try await postFormData(
                formData: formData,
                url: URL(string: redirectUri)!,
                responseMode: ResponseMode.directPost,  // todo: change to appropriate value.
                convert: convertIdTokenResponseResponse,
                using: session
            )
            print("status code: \(postResult.statusCode)")
            if let location = postResult.location {
                print("location: \(location)")
            }
            return .success(postResult)
        }
        catch {
            return .failure(error)
        }
    }

    func convertIdTokenResponseResponse(data: Data, response: HTTPURLResponse, requestURL: URL)
        throws -> PostResult
    {
        //        print("response body of siop response: \(String(data: data, encoding: .utf8) ?? "no utf string value")")
        var cookies: [String]? = nil
        if let setCookieHeader = response.allHeaderFields["Set-Cookie"] as? String {
            // 単一のクッキーを配列に格納
            cookies = [setCookieHeader]
        }
        else if let setCookieHeaders = response.allHeaderFields["Set-Cookie"] as? [String] {
            // 複数のクッキーがある場合はそのまま使用
            cookies = setCookieHeaders
        }
        if response.statusCode == 302 {
            if let locationHeader = response.allHeaderFields["Location"] as? String {
                print("Location Header: \(locationHeader)")
                // `Location`ヘッダーの値が絶対URLかどうかを確認
                let location: String
                if locationHeader.starts(with: "http://") || locationHeader.starts(with: "https://")
                {
                    // 絶対URLの場合はそのまま使用
                    location = locationHeader
                }
                else {
                    // パスのみの場合はスキーム、ホスト、ポート情報を補完
                    let scheme = requestURL.scheme ?? "http"
                    let host = requestURL.host ?? ""
                    let port = requestURL.port.map { ":\($0)" } ?? ""
                    location = "\(scheme)://\(host)\(port)\(locationHeader)"
                    //                    // パスのみの場合はホスト情報を補完
                    //                    guard let base = requestURL.baseURL else {
                    //                        // `requestURL`からベースURLを取得できない場合は`requestURL`自体を使用
                    //                        location = requestURL.scheme! + "://" + requestURL.host! + locationHeader
                    //                        return PostResult(statusCode: response.statusCode, location: location)
                    //                    }
                    //                    // ベースURLを使用して補完
                    //                    location = base.absoluteString + locationHeader
                }
                return PostResult(
                    statusCode: response.statusCode, location: location, cookies: cookies)
            }
            else {
                // `Location`ヘッダーが見つからなかった場合の処理
                throw NetworkError.invalidResponse  // 適切なエラー処理を行う
            }
        }
        else {
            return PostResult(statusCode: response.statusCode, location: nil, cookies: cookies)
        }
    }

    func convertVpTokenResponseResponse(data: Data, response: HTTPURLResponse, requestURL: URL)
        throws -> PostResult
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
                    return PostResult(statusCode: statusCode, location: location, cookies: nil)
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
                return PostResult(
                    statusCode: response.statusCode, location: location, cookies: nil)
            }
            else {
                throw NetworkError.invalidResponse
            }
        }

        return PostResult(statusCode: statusCode, location: nil, cookies: nil)
    }

    func respondVPResponse(
        credentials: [SubmissionCredential], using session: URLSession = URLSession.shared
    ) async -> Result<(PostResult, [SharedContent], [String?]), Error> {
        //        guard let authRequestProcessedData = self.authRequestProcessedData else {
        //            throw OpenIdProviderIllegalStateException.illegalAuthRequestProcessedDataState
        //        }
        //        let authRequest = authRequestProcessedData.authorizationRequest
        //        let requestObj = authRequestProcessedData.requestObject
        guard let clientId = clientId,
            let responseMode = responseMode,
            let nonce = nonce,
            let presentationDefinition = presentationDefinition,
            let responseUri = authRequestProcessedData?.requestObject?.responseUri
                ?? authRequestProcessedData?.authorizationRequest.responseUri
        else {
            return .failure(OpenIdProviderIllegalStateException.illegalState)
        }

        let preparedSubmissionData = try! credentials.compactMap {
            credential -> PreparedSubmissionData? in
            switch credential.format {
                case "vc+sd-jwt":
                    return
                        try credential.createVpTokenForSdJwtVc(
                            clientId: clientId,
                            nonce: nonce,
                            keyBinding: keyBinding)

                case "jwt_vc_json":
                    return
                        try credential.createVpTokenForJwtVc(
                            clientId: clientId,
                            nonce: nonce,
                            jwtVpJsonGenerator: jwtVpJsonGenerator

                        )

                default:
                    throw IllegalArgumentException.badParams
            }
        }

        guard let vpTokenValue = conformToFormData(preparedData: preparedSubmissionData) else {
            return .failure(OpenIdProviderIllegalStateException.illegalJsonState)
        }

        let presentationSubmission = PresentationSubmission(
            id: UUID().uuidString,
            definitionId: presentationDefinition.id,
            descriptorMap: preparedSubmissionData.map { $0.descriptorMap }
        )

        let jsonEncoder = JSONEncoder()
        jsonEncoder.keyEncodingStrategy = .convertToSnakeCase

        // オブジェクトをJSON文字列にエンコード
        let jsonData = try! jsonEncoder.encode(presentationSubmission)
        let jsonString = String(data: jsonData, encoding: .utf8)!

        do {
            var formData = ["vp_token": vpTokenValue, "presentation_submission": jsonString]
            if let state = state {
                formData["state"] = state
            }
            print("url: \(responseUri)")
            let postResult = try await postFormData(
                formData: formData,
                url: URL(string: responseUri)!,
                responseMode: responseMode,
                convert: convertVpTokenResponseResponse,
                using: session
            )
            let sharedContents = preparedSubmissionData.map {
                SharedContent(id: $0.credentialId, sharedClaims: $0.disclosedClaims)
            }
            let purposes = preparedSubmissionData.map { $0.purpose }
            return .success((postResult, sharedContents, purposes))
        }
        catch {
            return .failure(error)
        }
    }
}

