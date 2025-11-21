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

    // DCQL Query definitions for tests
    let dcqlQuery1 = """
        {
          "credentials": [
            {
              "id": "input1",
              "format": "vc+sd-jwt",
              "claims": [
                {"path": ["claim1"]}
              ]
            }
          ]
        }
        """

    let dcqlQuery2 = """
        {
          "credentials": [
            {
              "id": "input1",
              "format": "vc+sd-jwt",
              "claims": [
                {"path": ["claim2"]}
              ]
            }
          ]
        }
        """

    // PEX tests removed - migrated to DCQL

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
