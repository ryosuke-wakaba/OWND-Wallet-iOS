//
//  VCIClientTests.swift
//  tw2023_walletTests
//
//  Created by 若葉良介 on 2023/12/27.
//

import XCTest

final class DecodingCredentialOfferTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDecodeFilledCredentialOffer() throws {
        let jsonData = try loadJsonTestData(fileName: "credential_offer_filled")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let credentialOffer = try decoder.decode(CredentialOffer.self, from: jsonData)

        XCTAssertEqual(credentialOffer.credentialIssuer, "https://datasign-demo-vci.tunnelto.dev")
        XCTAssertFalse(credentialOffer.credentialConfigurationIds.isEmpty)
        XCTAssertEqual(credentialOffer.credentialConfigurationIds[0], "IdentityCredential")

        let grants = credentialOffer.grants
        XCTAssertEqual(grants?.authorizationCode?.issuerState, "eyJhbGciOiJSU0Et...FYUaBy")

        XCTAssertEqual(grants?.preAuthorizedCode?.preAuthorizedCode, "adhjhdjajkdkhjhdj")
        XCTAssertEqual(grants?.preAuthorizedCode?.txCode?.inputMode, "numeric")
        XCTAssertEqual(grants?.preAuthorizedCode?.txCode?.length, 4)
        XCTAssertEqual(grants?.preAuthorizedCode?.txCode?.description, "description")
        XCTAssertEqual(grants?.preAuthorizedCode?.interval, 10)
        XCTAssertEqual(
            grants?.preAuthorizedCode?.authorizationServer, "https://datasign-demo-vci.tunnelto.dev"
        )
    }

    func testDecodeMinimumCredentialOffer() throws {
        let jsonData = try loadJsonTestData(fileName: "credential_offer_minimum")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let credentialOffer = try decoder.decode(CredentialOffer.self, from: jsonData)

        XCTAssertEqual(credentialOffer.credentialIssuer, "https://datasign-demo-vci.tunnelto.dev")
        XCTAssertFalse(credentialOffer.credentialConfigurationIds.isEmpty)
        XCTAssertEqual(credentialOffer.credentialConfigurationIds[0], "IdentityCredential")

        XCTAssertNil(credentialOffer.grants)
    }
    func testDecodeCredentialOfferWithTxCode() throws {
        let jsonData = try loadJsonTestData(fileName: "credential_offer_tx_code_required")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let credentialOffer = try decoder.decode(CredentialOffer.self, from: jsonData)

        XCTAssertTrue(credentialOffer.isTxCodeRequired())
    }

    func testFromStringCredentialOfferFilled() throws {
        let jsonData = try loadJsonTestData(fileName: "credential_offer_filled")
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            XCTFail("unable to convert json data to string")
            return
        }

        let allowedCharacters = NSCharacterSet.alphanumerics.union(.init(charactersIn: "-._~"))
        let url = URL(
            string: jsonString.addingPercentEncoding(withAllowedCharacters: allowedCharacters)!)!
        let offerString = "openid-credential-offer://?credential_offer=\(url.absoluteString)"
        guard let credentialOffer = CredentialOffer.fromString(offerString) else {
            XCTFail("failed to `fromString`")
            return
        }

        XCTAssertEqual(credentialOffer.credentialIssuer, "https://datasign-demo-vci.tunnelto.dev")
        XCTAssertFalse(credentialOffer.credentialConfigurationIds.isEmpty)
        XCTAssertEqual(credentialOffer.credentialConfigurationIds[0], "IdentityCredential")

        let grants = credentialOffer.grants
        XCTAssertEqual(grants?.authorizationCode?.issuerState, "eyJhbGciOiJSU0Et...FYUaBy")

        XCTAssertEqual(grants?.preAuthorizedCode?.preAuthorizedCode, "adhjhdjajkdkhjhdj")
        XCTAssertEqual(grants?.preAuthorizedCode?.txCode?.inputMode, "numeric")
        XCTAssertEqual(grants?.preAuthorizedCode?.txCode?.length, 4)
        XCTAssertEqual(grants?.preAuthorizedCode?.txCode?.description, "description")
        XCTAssertEqual(grants?.preAuthorizedCode?.interval, 10)
        XCTAssertEqual(
            grants?.preAuthorizedCode?.authorizationServer, "https://datasign-demo-vci.tunnelto.dev"
        )
    }
}

final class DecodingCredentialResponseTests: XCTestCase {
    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDecodeJwtVcJsonResponse() throws {
        let jsonData = try loadJsonTestData(fileName: "credential_response_jwt_vc_json")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let credentialResponseJwtVcJson = try decoder.decode(
            CredentialResponse.self, from: jsonData)

        guard let credential = credentialResponseJwtVcJson.credential else {
            XCTFail("credential is required")
            return
        }

        let (_, _, signature) = try JWTUtil.decodeJwt(jwt: credential)
        XCTAssertEqual(
            signature,
            "z5vgMTK1nfizNCg5N-niCOL3WUIAL7nXy-nGhDZYO_-PNGeE-0djCpWAMH8fD8eWSID5PfkPBYkx_dfLJnQ7NA"
        )
    }

    func testDecodeVcSdJwtResponse() throws {
        let jsonData = try loadJsonTestData(fileName: "credential_response_vc_sd_jwt")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let credentialResponseVcSdJwt = try decoder.decode(CredentialResponse.self, from: jsonData)

        guard let credential = credentialResponseVcSdJwt.credential else {
            XCTFail("credential is required")
            return
        }

        let divided = try SDJwtUtil.divideSDJwt(sdJwt: credential)
        XCTAssertTrue(divided.disclosures.count > 0)
    }

    func testDeferredResponse() throws {
        let jsonData = try loadJsonTestData(fileName: "credential_response_deferred")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let deferredResponse = try decoder.decode(CredentialResponse.self, from: jsonData)

        XCTAssertEqual(deferredResponse.transactionId, "12345")
        XCTAssertNil(deferredResponse.credential)
    }

    func testNotificationResponse() throws {
        let jsonData = try loadJsonTestData(fileName: "credential_response_notification")
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let deferredResponse = try decoder.decode(CredentialResponse.self, from: jsonData)

        XCTAssertEqual(deferredResponse.notificationId, "12345")
        XCTAssertEqual(deferredResponse.credential, "example-credential")
    }
}

final class VCIClientTests: XCTestCase {

    private var issuer = ""
    private var credentialOffer: CredentialOffer? = nil

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
        issuer = "https://datasign-demo-vci.tunnelto.dev"
        credentialOffer = CredentialOffer.fromString(
            "openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Fdatasign-demo-vci.tunnelto.dev%22%2C%22credential_configuration_ids%22%3A%5B%22IdentityCredential%22%5D%2C%22grants%22%3A%7B%22urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Apre-authorized_code%22%3A%7B%22pre-authorized_code%22%3A%22SplxlOBeZQQYbYS6WxSbIA%22%2C%22tx_code%22%3A%7B%7D%7D%7D%7D"
        )

    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testPostTokenRequest() {
        runAsyncTest {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            let mockSession = URLSession(configuration: configuration)

            let testURL = URL(string: "https://example.com/token")!
            guard let mockData = try? loadJsonTestData(fileName: "token_response")
            else {
                XCTFail("Cannot read token_response.json")
                return
            }
            let response = HTTPURLResponse(
                url: testURL.absoluteURL, statusCode: 200, httpVersion: nil, headerFields: nil)
            MockURLProtocol.mockResponses[testURL.absoluteString] = (mockData, response)
            do {
                let tokenRequest = OAuthTokenRequest(
                    grantType: "urn:ietf:params:oauth:grant-type:pre-authorized_code", code: nil,
                    redirectUri: nil, clientId: nil, preAuthorizedCode: "SplxlOBeZQQYbYS6WxSbIA",
                    txCode: "493536"
                )
                let tokenResponse = try await postTokenRequest(
                    to: testURL, with: tokenRequest, using: mockSession)
                XCTAssertEqual(tokenResponse.accessToken, "example-access-token")
                XCTAssertEqual(tokenResponse.cNonce, "example-c-nonce")
            }
            catch {
                XCTFail("Request should not fail")
            }
        }
    }

    func testPostCredentialRequest() {
        runAsyncTest {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            let mockSession = URLSession(configuration: configuration)

            // テスト用URLとモックレスポンスデータの設定
            let testURL = URL(string: "https://example.com/credential")!
            guard
                let mockData = try? loadJsonTestData(fileName: "credential_response_mock")
            else {
                XCTFail("Cannot read credential_response.json")
                return
            }
            let response = HTTPURLResponse(
                url: testURL.absoluteURL, statusCode: 200, httpVersion: nil, headerFields: nil)
            MockURLProtocol.mockResponses[testURL.absoluteString] = (mockData, response)

            // OID4VCI 1.0: CredentialRequestのインスタンスを作成
            let proofs = Proofs(jwt: ["example-jwt"], cwt: nil, ldpVp: nil)
            let credentialRequest = createCredentialRequest(
                credentialConfigurationId: "IdentityCredential",
                proofs: proofs
            )

            // postCredentialRequest関数のテスト
            do {
                let credentialResponse = try await postCredentialRequest(
                    credentialRequest, to: testURL, accessToken: "example-access-token",
                    using: mockSession)
                XCTAssertEqual(credentialResponse.cNonce, "example-c-nonce")
            }
            catch {
                XCTFail("Request should not fail")
            }
        }
    }

    // OID4VCI 1.0: Test nonce endpoint request function
    func testPostNonceRequest() {
        runAsyncTest {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            let mockSession = URLSession(configuration: configuration)

            let testURL = URL(string: "https://example.com/nonce")!

            // Create mock nonce response (OID4VCI 1.0: only c_nonce, no expires_in)
            let mockNonceResponse = """
            {
                "c_nonce": "example-nonce-value"
            }
            """.data(using: .utf8)!

            let response = HTTPURLResponse(
                url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)
            MockURLProtocol.mockResponses[testURL.absoluteString] = (mockNonceResponse, response)

            do {
                let nonceResponse = try await postNonceRequest(to: testURL, using: mockSession)
                XCTAssertEqual(nonceResponse.cNonce, "example-nonce-value")
            }
            catch {
                XCTFail("Request should not fail: \(error)")
            }
        }
    }

    // OID4VCI 1.0: Test VCIClient.fetchNonce method
    func testFetchNonce() {
        runAsyncTest {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            let mockSession = URLSession(configuration: configuration)

            let issuer = "https://datasign-demo-vci.tunnelto.dev"
            let nonceUrl = URL(string: "\(issuer)/nonce")!

            // Mock nonce endpoint response
            let mockNonceResponse = """
            {
                "c_nonce": "fetched-nonce-value"
            }
            """.data(using: .utf8)!

            MockURLProtocol.mockResponses[nonceUrl.absoluteString] = (
                mockNonceResponse,
                HTTPURLResponse(
                    url: nonceUrl,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)
            )

            // Setup metadata with nonce endpoint
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard
                let jsonIssuerMetaData = try? loadJsonTestData(
                    fileName: "credential_issuer_metadata_jwt_vc"),
                let jsonAuthorizationServerData = try? loadJsonTestData(
                    fileName: "authorization_server")
            else {
                XCTFail("Cannot read resource json")
                return
            }
            let credentialIssuerMetadata = try decoder.decode(
                CredentialIssuerMetadata.self, from: jsonIssuerMetaData)
            let authorizationServerMetadata = try decoder.decode(
                AuthorizationServerMetadata.self, from: jsonAuthorizationServerData)
            let metadata = Metadata(
                credentialIssuerMetadata: credentialIssuerMetadata,
                authorizationServerMetadata: authorizationServerMetadata)

            guard let offer = self.credentialOffer else {
                XCTFail("credential offer is not initialized properly")
                return
            }

            do {
                let vciClient = try await VCIClient(credentialOffer: offer, metaData: metadata)
                let nonceResponse = try await vciClient.fetchNonce(using: mockSession)
                XCTAssertEqual(nonceResponse.cNonce, "fetched-nonce-value")
            }
            catch {
                XCTFail("Request should not fail: \(error)")
            }
        }
    }

    func testIssueToken() {
        runAsyncTest {
            // setup mock for `/token`
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            let mockSession = URLSession(configuration: configuration)
            let tokenUrl = URL(string: "\(self.issuer)/token")!
            guard
                let mockData = try? loadJsonTestData(fileName: "token_response")
            else {
                XCTFail("Cannot read resource json")
                return
            }
            let response = HTTPURLResponse(
                url: tokenUrl, statusCode: 200, httpVersion: nil, headerFields: nil)
            MockURLProtocol.mockResponses[tokenUrl.absoluteString] = (mockData, response)

            // setup metadata
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard
                let jsonIssuerMetaData = try? loadJsonTestData(
                    fileName: "credential_issuer_metadata_jwt_vc"),
                let jsonAuthorizationServerData = try? loadJsonTestData(
                    fileName: "authorization_server")
            else {
                XCTFail("Cannot read resource json")
                return

            }
            let credentialIssuerMetadata = try decoder.decode(
                CredentialIssuerMetadata.self, from: jsonIssuerMetaData)
            let authorizationServerMetadata = try decoder.decode(
                AuthorizationServerMetadata.self, from: jsonAuthorizationServerData)
            let metadata = Metadata(
                credentialIssuerMetadata: credentialIssuerMetadata,
                authorizationServerMetadata: authorizationServerMetadata)

            // create credential offer
            guard let offer = self.credentialOffer else {
                XCTFail("credential offer is not initialized properly")
                return
            }

            do {
                // TokenIssuerのインスタンス生成とissueTokenのテスト
                let vciClient = try await VCIClient(
                    credentialOffer: offer, metaData: metadata)
                let token = try await vciClient.issueToken(txCode: "493536", using: mockSession)
                XCTAssertEqual(token.accessToken, "example-access-token")
                XCTAssertEqual(token.cNonce, "example-c-nonce")
            }
            catch {
                XCTFail("Request should not fail: \(error)")
            }
        }
    }

    func testIssueCredential() {
        runAsyncTest {
            // setup mock for `/credentials`
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            let mockSession = URLSession(configuration: configuration)

            let issuer = "https://datasign-demo-vci.tunnelto.dev"
            let credentialUrl = URL(string: "\(issuer)/credentials")!
            guard
                let mockData = try? loadJsonTestData(fileName: "credential_response_mock")
            else {
                XCTFail("Cannot read resource json")
                return
            }
            let response = HTTPURLResponse(
                url: credentialUrl, statusCode: 200, httpVersion: nil, headerFields: nil)
            MockURLProtocol.mockResponses[credentialUrl.absoluteString] = (mockData, response)

            // setup metadata
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            guard
                let jsonIssuerMetaData = try? loadJsonTestData(
                    fileName: "credential_issuer_metadata_sd_jwt"),
                let jsonAuthorizationServerData = try? loadJsonTestData(
                    fileName: "authorization_server")
            else {
                XCTFail("Cannot read resource json")
                return
            }
            let credentialIssuerMetadata = try decoder.decode(
                CredentialIssuerMetadata.self, from: jsonIssuerMetaData)
            let authorizationServerMetadata = try decoder.decode(
                AuthorizationServerMetadata.self, from: jsonAuthorizationServerData)
            let metadata = Metadata(
                credentialIssuerMetadata: credentialIssuerMetadata,
                authorizationServerMetadata: authorizationServerMetadata)

            // OID4VCI 1.0: payload generation
            let proofs = Proofs(jwt: ["dummy-proof"], cwt: nil, ldpVp: nil)
            let payload = createCredentialRequest(
                credentialConfigurationId: "UniversityDegreeCredential",
                proofs: proofs)

            do {
                guard let offer = self.credentialOffer else {
                    XCTFail("credential offer is not initialized properly")
                    return
                }

                let vciClient = try await VCIClient(
                    credentialOffer: offer, metaData: metadata)
                let credentialResponse = try await vciClient.issueCredential(
                    payload: payload, accessToken: "dummy-token", using: mockSession)
                XCTAssertEqual(credentialResponse.credential, "example-credential")
                XCTAssertEqual(credentialResponse.cNonce, "example-c-nonce")
                XCTAssertEqual(credentialResponse.cNonceExpiresIn, 86400)
            }
            catch {
                XCTFail("Request should not fail: \(error)")
            }
        }
    }

    // Integration test: Full credential issuance flow from Credential Offer URL
    func testFullCredentialIssuanceFlow() {
        runAsyncTest {
            // Step 1: Parse Credential Offer URL
            let credentialOfferUrl = "openid-credential-offer://?credential_offer=%7B%22credential_issuer%22%3A%22https%3A%2F%2Fdatasign-demo-vci.tunnelto.dev%22%2C%22credential_configuration_ids%22%3A%5B%22IdentityCredential%22%5D%2C%22grants%22%3A%7B%22urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Apre-authorized_code%22%3A%7B%22pre-authorized_code%22%3A%22SplxlOBeZQQYbYS6WxSbIA%22%2C%22tx_code%22%3A%7B%7D%7D%7D%7D"

            guard let offer = CredentialOffer.fromString(credentialOfferUrl) else {
                XCTFail("Failed to parse credential offer URL")
                return
            }

            // Verify parsed credential offer
            XCTAssertEqual(offer.credentialIssuer, "https://datasign-demo-vci.tunnelto.dev")
            XCTAssertEqual(offer.credentialConfigurationIds.first, "IdentityCredential")
            XCTAssertNotNil(offer.grants?.preAuthorizedCode)

            let issuer = offer.credentialIssuer

            // Setup mock session
            let configuration = URLSessionConfiguration.ephemeral
            configuration.protocolClasses = [MockURLProtocol.self]
            let mockSession = URLSession(configuration: configuration)

            // Step 2: Mock metadata endpoints
            let issuerMetadataUrl = URL(string: "\(issuer)/.well-known/openid-credential-issuer")!
            let authServerMetadataUrl = URL(string: "\(issuer)/.well-known/oauth-authorization-server")!

            guard
                let mockIssuerMetadata = try? loadJsonTestData(
                    fileName: "credential_issuer_metadata_jwt_vc"),
                let mockAuthServerMetadata = try? loadJsonTestData(
                    fileName: "authorization_server")
            else {
                XCTFail("Cannot read metadata json files")
                return
            }

            MockURLProtocol.mockResponses[issuerMetadataUrl.absoluteString] = (
                mockIssuerMetadata,
                HTTPURLResponse(
                    url: issuerMetadataUrl,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)
            )

            MockURLProtocol.mockResponses[authServerMetadataUrl.absoluteString] = (
                mockAuthServerMetadata,
                HTTPURLResponse(
                    url: authServerMetadataUrl,
                    statusCode: 200,
                    httpVersion: nil,
                    headerFields: nil)
            )

            // Step 3: Retrieve all metadata
            do {
                let metadata = try await retrieveAllMetadata(issuer: issuer, using: mockSession)

                // Verify metadata
                XCTAssertEqual(metadata.credentialIssuerMetadata.credentialIssuer, issuer)
                XCTAssertNotNil(metadata.authorizationServerMetadata.tokenEndpoint)
                // OID4VCI 1.0: Verify nonce_endpoint is present
                XCTAssertEqual(metadata.credentialIssuerMetadata.nonceEndpoint, "\(issuer)/nonce")

                // Step 4: Mock token endpoint
                let tokenUrl = URL(string: "\(issuer)/token")!
                guard let mockTokenResponse = try? loadJsonTestData(fileName: "token_response")
                else {
                    XCTFail("Cannot read token_response.json")
                    return
                }

                MockURLProtocol.mockResponses[tokenUrl.absoluteString] = (
                    mockTokenResponse,
                    HTTPURLResponse(
                        url: tokenUrl,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil)
                )

                // Step 5: Issue token
                let vciClient = try await VCIClient(credentialOffer: offer, metaData: metadata)
                let token = try await vciClient.issueToken(txCode: "493536", using: mockSession)

                // Verify token response
                XCTAssertEqual(token.accessToken, "example-access-token")

                // Step 6: OID4VCI 1.0 - Mock and fetch nonce from nonce endpoint
                let nonceUrl = URL(string: "\(issuer)/nonce")!
                let mockNonceResponse = """
                {
                    "c_nonce": "nonce-from-endpoint"
                }
                """.data(using: .utf8)!

                MockURLProtocol.mockResponses[nonceUrl.absoluteString] = (
                    mockNonceResponse,
                    HTTPURLResponse(
                        url: nonceUrl,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil)
                )

                let nonceResponse = try await vciClient.fetchNonce(using: mockSession)
                XCTAssertEqual(nonceResponse.cNonce, "nonce-from-endpoint")

                // Step 7: Mock credential endpoint
                let credentialUrl = URL(string: "\(issuer)/credentials")!
                guard
                    let mockCredentialResponse = try? loadJsonTestData(
                        fileName: "credential_response_mock")
                else {
                    XCTFail("Cannot read credential_response_mock.json")
                    return
                }

                MockURLProtocol.mockResponses[credentialUrl.absoluteString] = (
                    mockCredentialResponse,
                    HTTPURLResponse(
                        url: credentialUrl,
                        statusCode: 200,
                        httpVersion: nil,
                        headerFields: nil)
                )

                // Step 8: Issue credential with proof (using nonce from nonce endpoint)
                let proofs = Proofs(jwt: ["example-jwt-proof"], cwt: nil, ldpVp: nil)
                let credentialRequest = createCredentialRequest(
                    credentialConfigurationId: "IdentityCredential",
                    proofs: proofs
                )

                let credentialResponse = try await vciClient.issueCredential(
                    payload: credentialRequest,
                    accessToken: token.accessToken,
                    using: mockSession
                )

                // Verify credential response
                XCTAssertNotNil(credentialResponse.credential)
                XCTAssertEqual(credentialResponse.credential, "example-credential")
                XCTAssertEqual(credentialResponse.cNonce, "example-c-nonce")

                // Success: Full flow completed
                print("✅ Full credential issuance flow completed successfully")
            }
            catch {
                XCTFail("Full credential issuance flow failed: \(error)")
            }
        }
    }

}
