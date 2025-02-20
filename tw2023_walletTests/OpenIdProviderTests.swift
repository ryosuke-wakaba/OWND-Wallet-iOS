//
//  OpenIdProviderTests.swift
//  tw2023_walletTests
//
//  Created by 若葉良介 on 2024/01/05.
//

import XCTest

@testable import tw2023_wallet

class ConvertVpTokenResponseResponseTests: XCTestCase {
    var idProvider: OpenIdProvider!

    override func setUp() {
        super.setUp()
        idProvider = OpenIdProvider(ProviderOption())
    }

    func testConvertVpTokenResponseResponse_withValid200JSONResponse() throws {
        // Given
        let json = """
            {
                "redirect_uri": "https://example.com"
            }
            """.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let requestURL = URL(string: "https://example.com")!

        // When
        let (statusCode, location, cookies) = try idProvider.convertVerifierResponse(
            data: json, response: response, requestURL: requestURL)

        // Then
        XCTAssertEqual(statusCode, 200)
        XCTAssertEqual(location, "https://example.com")
        XCTAssertNil(cookies)
    }

    func testConvertVpTokenResponseResponse_withInvalid200JSONResponse() throws {
        // Given
        let json = """
            {
                "invalid_key": "invalid_value"
            }
            """.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        let requestURL = URL(string: "https://example.com")!

        // Then
        let (statusCode, location, cookies) = try idProvider.convertVerifierResponse(
            data: json, response: response, requestURL: requestURL)
        XCTAssertEqual(statusCode, 200)
        XCTAssertNil(location)
        XCTAssertNil(cookies)

    }

    func testConvertVpTokenResponseResponse_with302RedirectAbsoluteURL() throws {
        // Given
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://example.com"]
        )!
        let requestURL = URL(string: "https://example.com")!

        // When
        let (statusCode, location, cookies) = try idProvider.convertVerifierResponse(
            data: Data(), response: response, requestURL: requestURL)

        // Then
        XCTAssertEqual(statusCode, 302)
        XCTAssertNil(location)
        XCTAssertNil(cookies)
    }

    func testConvertVpTokenResponseResponse_with302RedirectRelativeURL() throws {
        // Given
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "/path/to/resource"]
        )!
        let requestURL = URL(string: "https://example.com")!

        // When
        let (statusCode, location, cookies) = try idProvider.convertVerifierResponse(
            data: Data(), response: response, requestURL: requestURL)

        // Then
        XCTAssertEqual(statusCode, 302)
        XCTAssertNil(location)
        XCTAssertNil(cookies)
    }

    func testConvertVpTokenResponseResponse_with302RedirectMissingLocationHeader() throws {
        // Given
        let response = HTTPURLResponse(
            url: URL(string: "https://example.com")!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: [:]
        )!
        let requestURL = URL(string: "https://example.com")!

        // Then
        let (statusCode, location, cookies) =
            try idProvider.convertVerifierResponse(
                data: Data(), response: response, requestURL: requestURL)
        XCTAssertEqual(statusCode, 302)
        XCTAssertNil(location)
        XCTAssertNil(cookies)

    }
}

final class OpenIdProviderTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    // テスト用のモック関数
    func mockDecodeDisclosure(disclosures: [String]) -> [Disclosure] {
        return disclosures.map { Disclosure(disclosure: $0, key: "mockKey", value: "mockValue") }
    }
    func mockDecodeDisclosure0(disclosures: [String]) -> [Disclosure] {
        return []
    }

    func mockDecodeDisclosure1Records(disclosures: [String]) -> [Disclosure] {
        return [
            Disclosure(disclosure: "claim1-digest", key: "claim1", value: "foo")
        ]
    }

    func mockDecodeDisclosure2Records(disclosures: [String]) -> [Disclosure] {
        return [
            Disclosure(disclosure: "claim1-digest", key: "claim1", value: "foo"),
            Disclosure(disclosure: "claim2-digest", key: "claim2", value: "bar"),
        ]
    }

    func testExample() throws {
        decodeDisclosureFunction = mockDecodeDisclosure

        let mockDecoded = decodeDisclosureFunction(["dummy"])
        XCTAssertEqual(mockDecoded[0].key, "mockKey")
    }

    let presentationDefinition1 = """
        {
          "id": "12345",
          "input_descriptors": [
            {
              "id": "input1",
              "format": {
                "vc+sd-jwt": {}
              },
              "constraints": {
                "limit_disclosure": "required",
                "fields": [
                  {
                    "path": ["$.claim1"],
                    "filter": {"type": "string"}
                  }
                ]
              }
            }
          ],
          "submission_requirements": []
        }
        """
    let presentationDefinition2 = """
        {
          "id": "12345",
          "input_descriptors": [
            {
              "id": "input1",
              "format": {
                "vc+sd-jwt": {}
              },
              "constraints": {
                "limit_disclosure": "required",
                "fields": [
                  {
                    "path": ["$.claim2"],
                    "filter": {"type": "string"}
                  }
                ]
              }
            }
          ],
          "submission_requirements": []
        }
        """

    let presentationDefinition3 = """
            {
              "id": "12345",
              "input_descriptors": [
                {
                  "id": "input1",
                  "format": {
                    "vc+sd-jwt": {}
                  },
                  "constraints": {
                    "limit_disclosure": "required",
                    "fields": [
                      {
                        "path": ["$.claim1"],
                        "filter": {"type": "string"}
                      },
                      {
                        "path": ["$.claim2"],
                        "filter": {"type": "string"},
                      }
                    ]
                  }
                }
              ],
              "submission_requirements": []
            }
        """

    let presentationDefinition4 = """
            {
              "id": "12345",
              "input_descriptors": [
                {
                  "id": "input1",
                  "format": {
                    "vc+sd-jwt": {}
                  },
                  "constraints": {
                    "limit_disclosure": "required",
                    "fields": [
                      {
                        "path": ["$.claim1"],
                        "filter": {"type": "string"}
                      },
                      {
                        "path": ["$.claim2"],
                        "filter": {"type": "string"},
                        "optional": true
                      }
                    ]
                  }
                }
              ],
              "submission_requirements": []
            }
        """

    let presentationDefinition5 = """
            {
              "id": "12345",
              "input_descriptors": [
                {
                  "id": "input1",
                  "format": {
                    "vc+sd-jwt": {}
                  },
                  "constraints": {
                    "limit_disclosure": "required",
                    "fields": [
                      {
                        "path": ["$.claim1"],
                        "filter": {"type": "string"},
                      },
                      {
                        "path": ["$.claim2"],
                        "filter": {"type": "string"},
                        "optional": false
                      }
                    ]
                  }
                }
              ],
              "submission_requirements": []
            }
        """

    let presentationDefinition6 = """
            {
              "id": "12345",
              "input_descriptors": [
                {
                  "id": "input1",
                  "format": {
                    "vc+sd-jwt": {}
                  },
                  "constraints": {
                    "limit_disclosure": "required",
                    "fields": [
                      {
                        "path": ["$.claim1"],
                        "filter": {"type": "string"},
                        "optional": true
                      },
                      {
                        "path": ["$.claim2"],
                        "filter": {"type": "string"},
                        "optional": true
                      }
                    ]
                  }
                }
              ],
              "submission_requirements": []
            }
        """

    let presentationDefinition7 = """
        {
          "id": "12345",
          "submission_requirements": [
            {
              "name": "Citizenship Information",
              "rule": "pick",
              "count": 2,
              "from": "A"
            }
          ],
          "input_descriptors": [
            {
              "id": "input1",
              "group": [
                "A"
              ],
              "format": {
                "vc+sd-jwt": {}
              },
              "constraints": {
                "limit_disclosure": "required",
                "fields": [
                  {
                    "path": [
                      "$.claim1"
                    ],
                    "filter": {
                      "type": "string"
                    },
                    "optional": false
                  },
                  {
                    "path": [
                      "$.claim2"
                    ],
                    "filter": {
                      "type": "string"
                    },
                    "optional": true
                  }
                ]
              }
            },
            {
              "id": "input2",
              "group": [
                "A"
              ],
              "format": {
                "vc+sd-jwt": {}
              },
              "constraints": {
                "fields": [
                  {
                    "path": [
                      "$.claim3"
                    ],
                    "filter": {
                      "type": "string"
                    }
                  },
                  {
                    "path": [
                      "$.claim4"
                    ],
                    "filter": {
                      "type": "string"
                    },
                    "optional": false
                  }
                ]
              }
            }
          ]
        }

        """

    let presentationDefinition8 = """
        {
          "id": "12345",
          "submission_requirements": [
            {
              "name": "Comment submission",
              "rule": "pick",
              "count": 1,
              "from": "COMMENT"
            },
            {
              "name": "Affiliation info for your comment",
              "rule": "pick",
              "max": 1,
              "from": "AFFILIATION"
            }
          ],
          "input_descriptors": [
            {
              "id": "comment_input",
              "group": [
                "COMMENT"
              ],
              "format": {
                "jwt_vc_json": {
                  "proof_type": [
                    "JsonWebSignature2020"
                  ]
                }
              },
              "constraints": {
                "limit_disclosure": "required",
                "fields": [
                  {
                    "path": [
                      "$.vc.type"
                    ],
                    "filter": {
                      "type": "array",
                      "contains": {
                        "const": "CommentCredential"
                      }
                    }
                  },
                  {
                    "path": [
                      "$.vc.credentialSubject.comment"
                    ],
                    "filter": {
                      "type": "string",
                      "const": "This is comment"
                    }
                  },
                  {
                    "path": [
                      "$.vc.credentialSubject.url"
                    ],
                    "filter": {
                      "type": "string",
                      "const": "https://example.com/"
                    }
                  },
                  {
                    "path": [
                      "$.vc.credentialSubject.bool_value"
                    ],
                    "filter": {
                      "type": "string",
                      "pattern": "^[012]$"
                    }
                  }
                ]
              }
            },
            {
              "id": "affiliation_input",
              "group": [
                "AFFILIATION"
              ],
              "format": {
                "vc+sd-jwt": {}
              },
              "constraints": {
                "fields": [
                  {
                    "path": [
                      "$.vct"
                    ],
                    "filter": {
                      "type": "string",
                      "const": "affiliation_credential"
                    }
                  },
                  {
                    "path": [
                      "$.organization_name"
                    ]
                  },
                  {
                    "path": [
                      "$.family_name"
                    ]
                  },
                  {
                    "path": [
                      "$.given_name"
                    ]
                  }
                ]
              }
            }
          ]
        }
        """

    func testSelectDisclosureNoSelected() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure0

        let sdJwt = "issuer-jwt~dummy-claim1~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition1.data(using: .utf8)!)
        let selected = presentationDefinition.firstMatchedInputDescriptor(
            sdJwt: sdJwt)
        XCTAssertNil(selected)
    }

    func testSelectDisclosureSelectedFirst() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records

        let sdJwt = "issuer-jwt~dummy-claim1~dummy-claim2~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition1.data(using: .utf8)!)
        let selected = presentationDefinition.firstMatchedInputDescriptor(
            sdJwt: sdJwt)
        if let (inputDescriptor, disclosures) = selected {
            XCTAssertEqual(inputDescriptor.id, "input1")
            XCTAssertEqual(disclosures.count, 2)
            for d in disclosures {
                if d.disclosure.key == "claim2" {
                    XCTAssertEqual(d.disclosure.key, "claim2")
                    XCTAssertEqual(d.disclosure.value, "bar")
                    XCTAssertTrue(!d.isSubmit)
                    XCTAssertTrue(!d.isUserSelectable)
                }
                if d.disclosure.key == "claim1" {
                    XCTAssertEqual(d.disclosure.key, "claim1")
                    XCTAssertEqual(d.disclosure.value, "foo")
                    XCTAssertTrue(d.isSubmit)
                    XCTAssertTrue(!d.isUserSelectable)
                }
            }
        }
        else {
            XCTFail()
        }
    }

    func testSelectDisclosureSelectedSecond() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records

        let sdJwt = "issuer-jwt~dummy-claim1~dummy-claim2~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition2.data(using: .utf8)!)
        let selected = presentationDefinition.firstMatchedInputDescriptor(
            sdJwt: sdJwt)
        if let (inputDescriptor, disclosures) = selected {
            XCTAssertEqual(inputDescriptor.id, "input1")
            XCTAssertEqual(disclosures.count, 2)
            for d in disclosures {
                if d.disclosure.key == "claim2" {
                    XCTAssertEqual(d.disclosure.key, "claim2")
                    XCTAssertEqual(d.disclosure.value, "bar")
                    XCTAssertTrue(d.isSubmit)
                    XCTAssertTrue(!d.isUserSelectable)
                }
                if d.disclosure.key == "claim1" {
                    XCTAssertEqual(d.disclosure.key, "claim1")
                    XCTAssertEqual(d.disclosure.value, "foo")
                    XCTAssertTrue(!d.isSubmit)
                    XCTAssertTrue(!d.isUserSelectable)
                }
            }
        }
        else {
            XCTFail()
        }
    }

    func testSelectDisclosureBothSelected() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records

        let sdJwt = "issuer-jwt~dummy-claim1~dummy-claim2~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition3.data(using: .utf8)!)
        let selected = presentationDefinition.firstMatchedInputDescriptor(
            sdJwt: sdJwt)
        if let (inputDescriptor, disclosures) = selected {
            XCTAssertEqual(inputDescriptor.id, "input1")
            XCTAssertEqual(disclosures.count, 2)
            for d in disclosures {
                if d.disclosure.key == "claim2" {
                    XCTAssertEqual(d.disclosure.key, "claim2")
                    XCTAssertEqual(d.disclosure.value, "bar")
                    XCTAssertTrue(d.isSubmit)
                    XCTAssertTrue(!d.isUserSelectable)
                }
                if d.disclosure.key == "claim1" {
                    XCTAssertEqual(d.disclosure.key, "claim1")
                    XCTAssertEqual(d.disclosure.value, "foo")
                    XCTAssertTrue(d.isSubmit)
                    XCTAssertTrue(!d.isUserSelectable)
                }
            }
        }
        else {
            XCTFail()
        }
    }

    func testSelectDisclosureClaim2Optional() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records

        let sdJwt = "issuer-jwt~dummy-claim1~dummy-claim2~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition4.data(using: .utf8)!)
        let selected = presentationDefinition.firstMatchedInputDescriptor(
            sdJwt: sdJwt)
        if let (inputDescriptor, disclosures) = selected {
            XCTAssertEqual(inputDescriptor.id, "input1")
            XCTAssertEqual(disclosures.count, 2)
            for d in disclosures {
                if d.disclosure.key == "claim2" {
                    XCTAssertEqual(d.disclosure.key, "claim2")
                    XCTAssertEqual(d.disclosure.value, "bar")
                    XCTAssertTrue(!d.isSubmit)
                    XCTAssertTrue(d.isUserSelectable)
                }
                if d.disclosure.key == "claim1" {
                    XCTAssertEqual(d.disclosure.key, "claim1")
                    XCTAssertEqual(d.disclosure.value, "foo")
                    XCTAssertTrue(d.isSubmit)
                    XCTAssertTrue(!d.isUserSelectable)
                }
            }
        }
        else {
            XCTFail()
        }
    }

    func testSelectDisclosureClaim2Optional2() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure1Records

        let sdJwt = "issuer-jwt~dummy-claim1~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition4.data(using: .utf8)!)
        let selected = presentationDefinition.firstMatchedInputDescriptor(
            sdJwt: sdJwt)
        if let (inputDescriptor, disclosures) = selected {
            XCTAssertEqual(inputDescriptor.id, "input1")
            XCTAssertEqual(disclosures.count, 1)
            for d in disclosures {
                if d.disclosure.key == "claim1" {
                    XCTAssertEqual(d.disclosure.key, "claim1")
                    XCTAssertEqual(d.disclosure.value, "foo")
                    XCTAssertTrue(d.isSubmit)
                    XCTAssertTrue(!d.isUserSelectable)
                }
            }
        }
        else {
            XCTFail()
        }
    }

    func testSelectDisclosureBothSelected2() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records

        let sdJwt = "issuer-jwt~dummy-claim1~dummy-claim2~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition5.data(using: .utf8)!)
        let selected = presentationDefinition.firstMatchedInputDescriptor(
            sdJwt: sdJwt)
        if let (inputDescriptor, disclosures) = selected {
            XCTAssertEqual(inputDescriptor.id, "input1")
            XCTAssertEqual(disclosures.count, 2)
            for d in disclosures {
                if d.disclosure.key == "claim2" {
                    XCTAssertEqual(d.disclosure.key, "claim2")
                    XCTAssertEqual(d.disclosure.value, "bar")
                    XCTAssertTrue(d.isSubmit)
                    XCTAssertTrue(!d.isUserSelectable)
                }
                if d.disclosure.key == "claim1" {
                    XCTAssertEqual(d.disclosure.key, "claim1")
                    XCTAssertEqual(d.disclosure.value, "foo")
                    XCTAssertTrue(d.isSubmit)
                    XCTAssertTrue(!d.isUserSelectable)
                }
            }
        }
        else {
            XCTFail()
        }
    }

    func testSelectDisclosureBothOptional() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records

        let sdJwt = "issuer-jwt~dummy-claim1~dummy-claim2~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition6.data(using: .utf8)!)
        let selected = presentationDefinition.firstMatchedInputDescriptor(
            sdJwt: sdJwt)
        if let (inputDescriptor, disclosures) = selected {
            XCTAssertEqual(inputDescriptor.id, "input1")
            XCTAssertEqual(disclosures.count, 2)
            for d in disclosures {
                if d.disclosure.key == "claim2" {
                    XCTAssertEqual(d.disclosure.key, "claim2")
                    XCTAssertEqual(d.disclosure.value, "bar")
                    XCTAssertTrue(!d.isSubmit)
                    XCTAssertTrue(d.isUserSelectable)
                }
                if d.disclosure.key == "claim1" {
                    XCTAssertEqual(d.disclosure.key, "claim1")
                    XCTAssertEqual(d.disclosure.value, "foo")
                    XCTAssertTrue(!d.isSubmit)
                    XCTAssertTrue(d.isUserSelectable)
                }
            }
        }
        else {
            XCTFail()
        }
    }

    func testCreatePresentationSubmissionSdJwtVc() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records

        let sdJwt = "issuer-jwt~dummy-claim1~dummy-claim2~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition1.data(using: .utf8)!)

        let credential = SubmissionCredential(
            id: "internal-id-1", format: "vc+sd-jwt", types: [], credential: sdJwt,
            inputDescriptor: presentationDefinition.inputDescriptors[0],
            discloseClaims: [
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(disclosure: "claim1-digest", key: "claim1", value: "foo"),
                    isSubmit: true, isUserSelectable: false)
            ]
        )
        let idProvider = OpenIdProvider(ProviderOption())

        try KeyPairUtil.generateSignVerifyKeyPair(alias: Constants.Cryptography.KEY_BINDING)
        let keyBinding = KeyBindingImpl(keyAlias: Constants.Cryptography.KEY_BINDING)
        idProvider.setKeyBinding(keyBinding: keyBinding)

        let preparedData = try credential.createVpTokenForSdJwtVc(
            clientId: "https://rp.example.com",
            nonce: "dummy-nonce",
            tokenIndex: -1,
            keyBinding: keyBinding
        )
        let parts = preparedData.vpToken.split(separator: "~").map(String.init)
        XCTAssertEqual(parts.count, 3)
        XCTAssertEqual(parts[0], "issuer-jwt")
        XCTAssertEqual(parts[1], "claim1-digest")
        XCTAssertEqual(preparedData.descriptorMap.format, "vc+sd-jwt")
        XCTAssertEqual(preparedData.descriptorMap.path, "$")
        XCTAssertEqual(preparedData.disclosedClaims.count, 1)
        XCTAssertEqual(preparedData.disclosedClaims[0].id, "internal-id-1")
        XCTAssertEqual(preparedData.disclosedClaims[0].name, "claim1")
    }

    func testCreatePresentationSubmissionSdJwtVcBothSubmit() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records

        let sdJwt = "issuer-jwt~dummy-claim1~dummy-claim2~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition3.data(using: .utf8)!)

        let credential = SubmissionCredential(
            id: "internal-id-1", format: "vc+sd-jwt", types: [], credential: sdJwt,
            inputDescriptor: presentationDefinition.inputDescriptors[0],
            discloseClaims: [
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(disclosure: "claim1-digest", key: "claim1", value: "foo"),
                    isSubmit: true, isUserSelectable: false),
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(disclosure: "claim2-digest", key: "claim2", value: "bar"),
                    isSubmit: true, isUserSelectable: false),

            ]
        )
        let idProvider = OpenIdProvider(ProviderOption())

        try KeyPairUtil.generateSignVerifyKeyPair(alias: Constants.Cryptography.KEY_BINDING)
        let keyBinding = KeyBindingImpl(keyAlias: Constants.Cryptography.KEY_BINDING)
        idProvider.setKeyBinding(keyBinding: keyBinding)

        let preparedData = try credential.createVpTokenForSdJwtVc(
            clientId: "https://rp.example.com",
            nonce: "dummy-nonce",
            tokenIndex: -1,
            keyBinding: keyBinding
        )
        let parts = preparedData.vpToken.split(separator: "~").map(String.init)
        XCTAssertEqual(parts.count, 4)
        XCTAssertEqual(parts[0], "issuer-jwt")
        XCTAssertEqual(parts[1], "claim1-digest")
        XCTAssertEqual(parts[2], "claim2-digest")
        XCTAssertEqual(preparedData.descriptorMap.format, "vc+sd-jwt")
        XCTAssertEqual(preparedData.descriptorMap.path, "$")
        XCTAssertEqual(preparedData.disclosedClaims.count, 2)
        XCTAssertEqual(preparedData.disclosedClaims[0].id, "internal-id-1")
        XCTAssertEqual(preparedData.disclosedClaims[0].name, "claim1")
        XCTAssertEqual(preparedData.disclosedClaims[1].id, "internal-id-1")
        XCTAssertEqual(preparedData.disclosedClaims[1].name, "claim2")
    }

    func testCreatePresentationSubmissionJwtVpJson() throws {

        let tag = "jwt_signing_key"
        XCTAssertNoThrow(try! KeyPairUtil.generateSignVerifyKeyPair(alias: tag))
        let (_, publicKey) = KeyPairUtil.getKeyPair(alias: tag)!

        let header = [
            "typ": "JWT",
            "alg": "ES256",
        ]
        let credentialSubject: [String: String] = ["claim1": "foo"]
        let vc: [String: Any] = ["credentialSubject": credentialSubject]
        let payload: [String: Any] = ["vc": vc]

        let tmp = JWTUtil.sign(keyAlias: tag, header: header, payload: payload)

        guard let vcJwt = try? tmp.get() else {
            XCTFail()
            return
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition1.data(using: .utf8)!)

        let credential = SubmissionCredential(
            id: "internal-id-1", format: "jwt_vp_json", types: [], credential: vcJwt,
            inputDescriptor: presentationDefinition.inputDescriptors[0],
            discloseClaims: []
        )
        let idProvider = OpenIdProvider(ProviderOption())

        try KeyPairUtil.generateSignVerifyKeyPair(
            alias: Constants.Cryptography.KEY_PAIR_ALIAS_FOR_KEY_JWT_VP_JSON)
        let jwtVpJsonGenerator = JwtVpJsonGeneratorImpl(
            keyAlias: Constants.Cryptography.KEY_PAIR_ALIAS_FOR_KEY_JWT_VP_JSON)
        idProvider.setJwtVpJsonGenerator(jwtVpJsonGenerator: jwtVpJsonGenerator)

        let preparedData = try credential.createVpTokenForJwtVc(
            clientId: "https://rp.example.com",
            nonce: "dummy-nonce",
            tokenIndex: -1,
            jwtVpJsonGenerator: jwtVpJsonGenerator
        )
        do {
            let decodedJwt = try JWTUtil.decodeJwt(jwt: preparedData.vpToken)
            let jwk = decodedJwt.0["jwk"]
            //            let payload = decodedJwt.1
            let publicKey = try! KeyPairUtil.createPublicKey(jwk: jwk as! [String: String])
            let result = JWTUtil.verifyJwt(jwt: preparedData.vpToken, publicKey: publicKey)
            switch result {
                case .success(let verifiedJwt):
                    let decodedPayload = verifiedJwt.body
                    let vp = decodedPayload["vp"]
                    XCTAssertNotNil(vp, "vp should not be nil")
                    if let vpObject = vp as? [String: Any] {
                        let verifiableCredential = vpObject["verifiableCredential"]
                        if let vpArray = verifiableCredential as? [String] {
                            // アサート: vpの件数が1件であること
                            XCTAssertEqual(
                                vpArray.count, 1, "vp array should contain exactly one element")
                            //
                            let jwtVc = vpArray[0]
                            let decodedJwtVc = try JWTUtil.decodeJwt(jwt: jwtVc)
                            print(decodedJwtVc.1)
                            let vc = decodedJwtVc.1["vc"] as? [String: Any]
                            let credentialSubject = vc!["credentialSubject"] as? [String: String]
                            XCTAssertEqual(credentialSubject!["claim1"], "foo")
                        }
                        else {
                            XCTFail("vp should be an array of dictionaries")
                        }
                    }
                    else {
                        XCTFail("vp should be an dictionaries")
                    }
                case .failure(let error):
                    print(error)
                    XCTFail("Error verify vp_token: \(error)")
            }
        }
        catch {
            XCTFail("Error generating JWT: \(error)")
        }
        XCTAssertEqual(preparedData.descriptorMap.format, "jwt_vp_json")
        XCTAssertEqual(preparedData.descriptorMap.path, "$")
        XCTAssertEqual(preparedData.descriptorMap.pathNested?.format, "jwt_vc_json")
        XCTAssertEqual(preparedData.descriptorMap.pathNested?.path, "$.vp.verifiableCredential[0]")
        XCTAssertEqual(preparedData.disclosedClaims.count, 1)
        XCTAssertEqual(preparedData.disclosedClaims[0].id, "internal-id-1")
        XCTAssertEqual(preparedData.disclosedClaims[0].name, "claim1")
        XCTAssertEqual(preparedData.disclosedClaims[0].value, "foo")
    }

    func testDirectPostSingleVpToken() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records
        let requestObject = RequestObjectPayloadImpl(
            responseType: "vp_token",
            clientId: "https://rp.example.com",
            redirectUri: "https://rp.example.com/cb",
            nonce: "dummy-nonce",
            responseMode: ResponseMode.directPost,
            responseUri: "https://rp.example.com/cb"
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: configuration)

        let urlString = "https://rp.example.com/cb"
        let testURL = URL(string: urlString)!
        let mockData = "dummy response".data(using: .utf8)
        let response = HTTPURLResponse(
            url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockURLProtocol.mockResponses[testURL.absoluteString] = (mockData, response)

        let sdJwt = "issuer-jwt~dummy-claim1~dummy-claim2~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition1.data(using: .utf8)!)

        let credential = SubmissionCredential(
            id: "internal-id-1", format: "vc+sd-jwt", types: [], credential: sdJwt,
            inputDescriptor: presentationDefinition.inputDescriptors[0],
            discloseClaims: [
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(disclosure: "claim1-digest", key: "claim1", value: "foo"),
                    isSubmit: true, isUserSelectable: false)
            ]
        )

        let authRequestProcessedData = ProcessedRequestData(
            authorizationRequest: AuthorizationRequestPayloadImpl(),
            requestObjectJwt: "dummy-jwt",
            requestObject: requestObject,
            clientMetadata: RPRegistrationMetadataPayload(),
            presentationDefinition: presentationDefinition,
            requestIsSigned: false
        )

        runAsyncTest {
            let idProvider = OpenIdProvider(ProviderOption())
            idProvider.authRequestProcessedData = authRequestProcessedData

            let requestObj = authRequestProcessedData.requestObject
            let authRequest = authRequestProcessedData.authorizationRequest
            idProvider.clientId = requestObj?.clientId ?? authRequest.clientId
            idProvider.responseMode = requestObj?.responseMode ?? authRequest.responseMode
            idProvider.responseType = requestObj?.responseType ?? authRequest.responseType
            idProvider.responseUri = requestObj?.responseUri ?? authRequest.responseUri
            idProvider.nonce = requestObj?.nonce ?? authRequest.nonce
            idProvider.presentationDefinition = authRequestProcessedData.presentationDefinition

            try KeyPairUtil.generateSignVerifyKeyPair(alias: Constants.Cryptography.KEY_BINDING)
            let keyBinding = KeyBindingImpl(keyAlias: Constants.Cryptography.KEY_BINDING)
            idProvider.setKeyBinding(keyBinding: keyBinding)

            let result = await idProvider.respondToken(
                credentials: [credential], using: mockSession)

            switch result {
                case .success(let data):

                    if let lastRequestData = MockURLProtocol.lastRequestBody,
                        let postBodyString = String(data: lastRequestData, encoding: .utf8),
                        let components = URLComponents(string: "?\(postBodyString)"),
                        let parsed = components.queryItems?.reduce(
                            into: [String: String](),
                            { result, item in
                                result[item.name] = item.value
                            }),
                        let vpToken = parsed["vp_token"],
                        let rawPresentationSubmission = parsed["presentation_submission"],
                        let presentationSubmissionData = rawPresentationSubmission.data(
                            using: .utf8),
                        let presentationSubmission = try? JSONSerialization.jsonObject(
                            with: presentationSubmissionData, options: []) as? [String: Any],
                        let descriptorMap = presentationSubmission["descriptor_map"]
                            as? [[String: Any]]
                    {
                        XCTAssertTrue(vpToken.hasPrefix("issuer-jwt"))
                        XCTAssertTrue(descriptorMap.count == 1)
                    }
                    else {
                        XCTFail()
                    }

                    if let sharedContents = data.sharedCredentials {
                        XCTAssertEqual(sharedContents.count, 1)
                        XCTAssertEqual(sharedContents[0].id, "internal-id-1")
                        XCTAssertEqual(sharedContents[0].sharedClaims.count, 1)
                        XCTAssertEqual(sharedContents[0].sharedClaims[0].name, "claim1")

                        if let lastRequest = MockURLProtocol.lastRequest {
                            XCTAssertEqual(lastRequest.httpMethod, "POST")
                            XCTAssertEqual(lastRequest.url, testURL)
                        }
                        else {
                            XCTFail("No request was made")
                        }

                    }
                    else {
                        XCTFail("sharedContents must be exist")
                    }
                    XCTAssertNil(data.sharedIdToken)
                case .failure(let error):
                    print(error)
                    XCTFail()
            }
        }
    }

    func testDirectPostMultipleVpToken() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records
        let requestObject = RequestObjectPayloadImpl(
            responseType: "vp_token",
            clientId: "https://rp.example.com",
            redirectUri: "https://rp.example.com/cb",
            nonce: "dummy-nonce",
            responseMode: ResponseMode.directPost,
            responseUri: "https://rp.example.com/cb"
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: configuration)

        let urlString = "https://rp.example.com/cb"
        let testURL = URL(string: urlString)!
        let mockData = "dummy response".data(using: .utf8)
        let response = HTTPURLResponse(
            url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockURLProtocol.mockResponses[testURL.absoluteString] = (mockData, response)

        let sdJwt1 = "issuer-jwt~dummy-claim1-digest~dummy-claim2-digest~"
        let sdJwt2 = "issuer-jwt~dummy-claim3-digest~dummy-claim4-digest~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition7.data(using: .utf8)!)

        let credential1 = SubmissionCredential(
            id: "internal-id-1", format: "vc+sd-jwt", types: [], credential: sdJwt1,
            inputDescriptor: presentationDefinition.inputDescriptors[0],
            discloseClaims: [
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(
                            disclosure: "claim1-digest", key: "claim1", value: "claim1-value"),
                    isSubmit: true, isUserSelectable: false)
            ]
        )

        let credential2 = SubmissionCredential(
            id: "internal-id-2", format: "vc+sd-jwt", types: [], credential: sdJwt2,
            inputDescriptor: presentationDefinition.inputDescriptors[1],
            discloseClaims: [
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(
                            disclosure: "claim3-digest", key: "claim3", value: "claim3-value"),
                    isSubmit: true, isUserSelectable: false),
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(
                            disclosure: "claim4-digest", key: "claim4", value: "claim4-value"),
                    isSubmit: true, isUserSelectable: false),

            ]
        )

        let authRequestProcessedData = ProcessedRequestData(
            authorizationRequest: AuthorizationRequestPayloadImpl(),
            requestObjectJwt: "dummy-jwt",
            requestObject: requestObject,
            clientMetadata: RPRegistrationMetadataPayload(),
            presentationDefinition: presentationDefinition,
            requestIsSigned: false
        )

        runAsyncTest {
            let idProvider = OpenIdProvider(ProviderOption())
            idProvider.authRequestProcessedData = authRequestProcessedData

            let requestObj = authRequestProcessedData.requestObject
            let authRequest = authRequestProcessedData.authorizationRequest
            idProvider.clientId = requestObj?.clientId ?? authRequest.clientId
            idProvider.responseType = requestObj?.responseType ?? authRequest.responseType
            idProvider.responseUri = requestObj?.responseUri ?? authRequest.responseUri
            idProvider.responseMode = requestObj?.responseMode ?? authRequest.responseMode
            idProvider.nonce = requestObj?.nonce ?? authRequest.nonce
            idProvider.presentationDefinition = authRequestProcessedData.presentationDefinition

            try KeyPairUtil.generateSignVerifyKeyPair(alias: Constants.Cryptography.KEY_BINDING)
            let keyBinding = KeyBindingImpl(keyAlias: Constants.Cryptography.KEY_BINDING)
            idProvider.setKeyBinding(keyBinding: keyBinding)
            let result = await idProvider.respondToken(
                credentials: [credential1, credential2], using: mockSession)
            switch result {
                case .success(let data):
                    if let lastRequestData = MockURLProtocol.lastRequestBody,
                        let postBodyString = String(data: lastRequestData, encoding: .utf8)
                    {
                        XCTAssertFalse(postBodyString.contains("id_token="))
                        XCTAssertTrue(postBodyString.contains("vp_token="))
                    }
                    else {
                        XCTFail()
                    }
                    if let sharedContents = data.sharedCredentials {
                        XCTAssertEqual(sharedContents.count, 2)
                        XCTAssertEqual(sharedContents[0].id, "internal-id-1")
                        XCTAssertEqual(sharedContents[0].sharedClaims.count, 1)
                        XCTAssertEqual(sharedContents[0].sharedClaims[0].name, "claim1")

                        XCTAssertEqual(sharedContents[1].id, "internal-id-2")
                        XCTAssertEqual(sharedContents[1].sharedClaims.count, 2)
                        XCTAssertEqual(sharedContents[1].sharedClaims[0].name, "claim3")
                        XCTAssertEqual(sharedContents[1].sharedClaims[1].name, "claim4")

                        if let lastRequest = MockURLProtocol.lastRequest {
                            XCTAssertEqual(lastRequest.httpMethod, "POST")
                            XCTAssertEqual(lastRequest.url, testURL)
                        }
                        else {
                            XCTFail("No request was made")
                        }

                    }
                    else {
                        XCTFail("sharedContents must be exist")
                    }
                    XCTAssertNil(data.sharedIdToken)
                case .failure(let error):
                    XCTFail()
            }
        }
    }

    func testDirectPostJwtVcJsonAndSdJwt() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records
        let requestObject = RequestObjectPayloadImpl(
            responseType: "vp_token id_token",
            clientId: "https://rp.example.com",
            redirectUri: "https://rp.example.com/cb",
            nonce: "dummy-nonce",
            responseMode: ResponseMode.directPost,
            responseUri: "https://rp.example.com/cb"
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: configuration)

        let urlString = "https://rp.example.com/cb"
        let testURL = URL(string: urlString)!
        let mockData = "dummy response".data(using: .utf8)
        let response = HTTPURLResponse(
            url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockURLProtocol.mockResponses[testURL.absoluteString] = (mockData, response)

        let vc1 =
            "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiI8aWRfdG9rZW4ncyBzdWI-Iiwic3ViIjoiPGlkX3Rva2VuJ3Mgc3ViPiIsIm5iZiI6MTI2MjMwNDAwMCwidmMiOnsiQGNvbnRleHQiOlsiaHR0cHM6Ly93d3cudzMub3JnLzIwMTgvY3JlZGVudGlhbHMvdjEiXSwidHlwZSI6WyJWZXJpZmlhYmxlQ3JlZGVudGlhbCIsIkNvbW1lbnRDcmVkZW50aWFsIl0sImNyZWRlbnRpYWxTdWJqZWN0Ijp7InVybCI6Imh0dHBzOi8vZXhhbXBsZS5jb20iLCJjb21tZW50Ijoi44GT44Gu44K144Kk44OI44Gv56eB5pys5Lq644GuWOOCouOCq-OCpuODs-ODiOOBp-OBmSIsImJvb2xfdmFsdWUiOjF9fX0.6EPvpqZS2QQwVFp5rqa8Mh6QdP6mUyjKFGvvnZxE180"
        let vc2 = "issuer-jwt~dummy-claim3-digest~dummy-claim4-digest~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition8.data(using: .utf8)!)

        let credential1 = SubmissionCredential(
            id: "internal-id-1",
            format: "jwt_vc_json",
            types: [],
            credential: vc1,
            inputDescriptor: presentationDefinition.inputDescriptors[0],
            discloseClaims: jwtVcJsonClaimsTobeDisclosed(jwt: vc1).map {
                return DisclosureWithOptionality(
                    disclosure: Disclosure(
                        disclosure: $0.disclosure, key: $0.key, value: $0.value),
                    isSubmit: true, isUserSelectable: false)
            }
        )

        let credential2 = SubmissionCredential(
            id: "internal-id-2",
            format: "vc+sd-jwt",
            types: [],
            credential: vc2,
            inputDescriptor: presentationDefinition.inputDescriptors[1],
            discloseClaims: [
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(
                            disclosure: "organization-name-digest", key: "organization_name",
                            value: "org name"),
                    isSubmit: true, isUserSelectable: false),
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(
                            disclosure: "family-name-digest", key: "family_name",
                            value: "family name"),
                    isSubmit: true, isUserSelectable: false),
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(
                            disclosure: "given-name-digest", key: "given_name", value: "given_name"),
                    isSubmit: true, isUserSelectable: false),

            ]
        )

        let authRequestProcessedData = ProcessedRequestData(
            authorizationRequest: AuthorizationRequestPayloadImpl(),
            requestObjectJwt: "dummy-jwt",
            requestObject: requestObject,
            clientMetadata: RPRegistrationMetadataPayload(),
            presentationDefinition: presentationDefinition,
            requestIsSigned: false
        )

        runAsyncTest {
            let idProvider = OpenIdProvider(ProviderOption())
            idProvider.authRequestProcessedData = authRequestProcessedData

            let requestObj = authRequestProcessedData.requestObject
            let authRequest = authRequestProcessedData.authorizationRequest
            idProvider.clientId = requestObj?.clientId ?? authRequest.clientId
            idProvider.responseType = requestObj?.responseType ?? authRequest.responseType
            idProvider.responseUri = requestObj?.responseUri ?? authRequest.responseUri
            idProvider.responseMode = requestObj?.responseMode ?? authRequest.responseMode
            idProvider.nonce = requestObj?.nonce ?? authRequest.nonce
            idProvider.presentationDefinition = authRequestProcessedData.presentationDefinition

            try KeyPairUtil.generateSignVerifyKeyPair(alias: Constants.Cryptography.KEY_BINDING)
            let keyBinding = KeyBindingImpl(keyAlias: Constants.Cryptography.KEY_BINDING)
            idProvider.setKeyBinding(keyBinding: keyBinding)

            guard let accountManager = PairwiseAccount(mnemonicWords: nil) else {
                XCTFail("unable to create account manager")
                return
            }
            let newAccount = accountManager.nextAccount()

            let publicKey = accountManager.getPublicKey(index: newAccount.index)
            let privateKey = accountManager.getPrivateKey(index: newAccount.index)
            let keyPair = KeyPairData(publicKey: publicKey, privateKey: privateKey)
            idProvider.setSecp256k1KeyPair(keyPair: keyPair)

            let jwtVpJsonGenerator = JwtVpJsonGeneratorImpl(
                keyAlias: Constants.Cryptography.KEY_PAIR_ALIAS_FOR_KEY_JWT_VP_JSON)
            idProvider.setJwtVpJsonGenerator(jwtVpJsonGenerator: jwtVpJsonGenerator)

            let result = await idProvider.respondToken(
                credentials: [credential1, credential2], using: mockSession)
            switch result {
                case .success(let data):
                    if let lastRequestData = MockURLProtocol.lastRequestBody,
                        let postBodyString = String(data: lastRequestData, encoding: .utf8),
                        let components = URLComponents(string: "?\(postBodyString)"),
                        let parsed = components.queryItems?.reduce(
                            into: [String: String](),
                            { result, item in
                                result[item.name] = item.value
                            }),
                        let idToken = parsed["id_token"],
                        let vpToken = parsed["vp_token"],
                        let rawPresentationSubmission = parsed["presentation_submission"],
                        let presentationSubmissionData = rawPresentationSubmission.data(
                            using: .utf8),
                        let presentationSubmission = try? JSONSerialization.jsonObject(
                            with: presentationSubmissionData, options: []) as? [String: Any],
                        let descriptorMap = presentationSubmission["descriptor_map"]
                            as? [[String: Any]]
                    {
                        XCTAssertTrue(idToken.hasPrefix("eyJ"))
                        XCTAssertTrue(vpToken.hasPrefix("["))
                        XCTAssertTrue(descriptorMap.count == 2)

                        let firstDescriptorMap = descriptorMap[0]
                        guard let path1 = firstDescriptorMap["path"] as? String else {
                            XCTFail()
                            return
                        }
                        XCTAssertEqual(path1, "$[0]")

                        let secondDescriptorMap = descriptorMap[1]
                        guard let path2 = secondDescriptorMap["path"] as? String else {
                            XCTFail()
                            return
                        }
                        XCTAssertEqual(path2, "$[1]")

                        // add more test for "nested_path"."path"
                    }
                    else {
                        XCTFail()
                    }
                    if let sharedContents = data.sharedCredentials {
                        XCTAssertEqual(sharedContents.count, 2)
                        XCTAssertEqual(sharedContents[0].id, "internal-id-1")
                        XCTAssertEqual(sharedContents[0].sharedClaims.count, 3)

                        for claim in sharedContents[0].sharedClaims {
                            XCTAssertTrue(["comment", "url", "bool_value"].contains(claim.name))
                        }

                        XCTAssertEqual(sharedContents[1].id, "internal-id-2")
                        XCTAssertEqual(sharedContents[1].sharedClaims.count, 3)
                        for claim in sharedContents[1].sharedClaims {
                            XCTAssertTrue(
                                ["organization_name", "given_name", "family_name"].contains(
                                    claim.name))
                        }

                        if let lastRequest = MockURLProtocol.lastRequest {
                            XCTAssertEqual(lastRequest.httpMethod, "POST")
                            XCTAssertEqual(lastRequest.url, testURL)
                        }
                        else {
                            XCTFail("No request was made")
                        }

                    }
                    else {
                        XCTFail("sharedContents must be exist")
                    }
                case .failure(let error):
                    XCTFail()
            }
        }
    }

    func testDirectPostIdTokenAndVpToken() throws {
        // mock up
        decodeDisclosureFunction = mockDecodeDisclosure2Records
        let requestObject = RequestObjectPayloadImpl(
            responseType: "vp_token id_token",
            clientId: "https://rp.example.com",
            redirectUri: "https://rp.example.com/cb",
            nonce: "dummy-nonce",
            responseMode: ResponseMode.directPost,
            responseUri: "https://rp.example.com/cb"
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        let mockSession = URLSession(configuration: configuration)

        let urlString = "https://rp.example.com/cb"
        let testURL = URL(string: urlString)!
        let mockData = "dummy response".data(using: .utf8)
        let response = HTTPURLResponse(
            url: testURL, statusCode: 200, httpVersion: nil, headerFields: nil)
        MockURLProtocol.mockResponses[testURL.absoluteString] = (mockData, response)

        let sdJwt = "issuer-jwt~dummy-claim1~dummy-claim2~"
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationDefinition = try decoder.decode(
            PresentationDefinition.self, from: presentationDefinition1.data(using: .utf8)!)

        let credential = SubmissionCredential(
            id: "internal-id-1", format: "vc+sd-jwt", types: [], credential: sdJwt,
            inputDescriptor: presentationDefinition.inputDescriptors[0],
            discloseClaims: [
                DisclosureWithOptionality(
                    disclosure:
                        Disclosure(disclosure: "claim1-digest", key: "claim1", value: "foo"),
                    isSubmit: true, isUserSelectable: false)
            ]
        )

        let authRequestProcessedData = ProcessedRequestData(
            authorizationRequest: AuthorizationRequestPayloadImpl(),
            requestObjectJwt: "dummy-jwt",
            requestObject: requestObject,
            clientMetadata: RPRegistrationMetadataPayload(),
            presentationDefinition: presentationDefinition,
            requestIsSigned: false
        )

        runAsyncTest {
            let idProvider = OpenIdProvider(ProviderOption())
            idProvider.authRequestProcessedData = authRequestProcessedData

            let requestObj = authRequestProcessedData.requestObject
            let authRequest = authRequestProcessedData.authorizationRequest
            idProvider.clientId = requestObj?.clientId ?? authRequest.clientId
            idProvider.responseMode = requestObj?.responseMode ?? authRequest.responseMode
            idProvider.responseType = requestObj?.responseType ?? authRequest.responseType
            idProvider.responseUri = requestObj?.responseUri ?? authRequest.responseUri
            idProvider.nonce = requestObj?.nonce ?? authRequest.nonce
            idProvider.presentationDefinition = authRequestProcessedData.presentationDefinition

            try KeyPairUtil.generateSignVerifyKeyPair(alias: Constants.Cryptography.KEY_BINDING)
            let keyBinding = KeyBindingImpl(keyAlias: Constants.Cryptography.KEY_BINDING)
            idProvider.setKeyBinding(keyBinding: keyBinding)

            guard let accountManager = PairwiseAccount(mnemonicWords: nil) else {
                XCTFail("unable to create account manager")
                return
            }
            let newAccount = accountManager.nextAccount()

            let publicKey = accountManager.getPublicKey(index: newAccount.index)
            let privateKey = accountManager.getPrivateKey(index: newAccount.index)
            let keyPair = KeyPairData(publicKey: publicKey, privateKey: privateKey)
            idProvider.setSecp256k1KeyPair(keyPair: keyPair)

            let result = await idProvider.respondToken(
                credentials: [credential], using: mockSession)

            switch result {
                case .success(let data):
                    if let lastRequestData = MockURLProtocol.lastRequestBody,
                        let postBodyString = String(data: lastRequestData, encoding: .utf8)
                    {
                        XCTAssertTrue(postBodyString.contains("id_token="))
                        XCTAssertTrue(postBodyString.contains("vp_token="))
                    }
                    else {
                        XCTFail()
                    }

                    if let sharedContents = data.sharedCredentials {
                        XCTAssertEqual(sharedContents.count, 1)
                        XCTAssertEqual(sharedContents[0].id, "internal-id-1")
                        XCTAssertEqual(sharedContents[0].sharedClaims.count, 1)
                        XCTAssertEqual(sharedContents[0].sharedClaims[0].name, "claim1")

                        if let lastRequest = MockURLProtocol.lastRequest {
                            XCTAssertEqual(lastRequest.httpMethod, "POST")
                            XCTAssertEqual(lastRequest.url, testURL)
                        }
                        else {
                            XCTFail("No request was made")
                        }

                    }
                    else {
                        XCTFail("sharedContents must be exist")
                    }
                    if let rawIdToken = data.sharedIdToken {
                        XCTAssertTrue(rawIdToken.hasPrefix("eyJ"))
                    }
                    else {
                        XCTFail("id token must be transmitted")
                    }
                case .failure(let error):
                    print(error)
                    XCTFail()
            }
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
