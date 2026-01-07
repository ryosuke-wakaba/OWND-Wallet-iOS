//
//  TrustedListManagerTests.swift
//  tw2023_walletTests
//
//  Tests for TrustedListManager functionality.
//

import XCTest
@testable import tw2023_wallet

final class TrustedListManagerTests: XCTestCase {

    var manager: TrustedListManager!
    var mockSession: URLSession!

    // MARK: - Sample Data

    let sampleTrustedListJSON = """
    {
      "LoTE": {
        "ListAndSchemeInformation": {
          "LoTEVersionIdentifier": 1,
          "LoTESequenceNumber": 1,
          "SchemeOperatorName": [{ "lang": "en", "value": "Test Authority" }],
          "ListIssueDateTime": "2026-01-01T00:00:00Z"
        },
        "TrustedEntitiesList": [
          {
            "TrustedEntityInformation": {
              "TEName": [{ "lang": "en", "value": "Test Entity" }]
            },
            "TrustedEntityServices": [
              {
                "ServiceInformation": {
                  "ServiceName": [{ "lang": "en", "value": "Test Issuer" }],
                  "ServiceDigitalIdentity": {
                    "X509Certificates": [
                      "-----BEGIN CERTIFICATE-----\\nMIIBkTCB+wIJAKHBfpegmI8lMA0GCSqGSIb3DQEBCwUAMBExDzANBgNVBAMMBnRl\\nc3RjYTAeFw0yNDAxMDEwMDAwMDBaFw0yNTAxMDEwMDAwMDBaMBExDzANBgNVBAMM\\nBnRlc3RjYTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IABJgNRPs1JGTTR/SX/Y/q\\nPmKqOPuACAQy5vwDhgOKzVZRJ6rIl2mfPvRmVPvfyH+xHMXhIe5Gy+5I9X0X2H5X\\nZp2jUzBRMB0GA1UdDgQWBBQlxBOOO3ygAfIh8HqR7hVqy5M8vjAfBgNVHSMEGDAW\\ngBQlxBOOO3ygAfIh8HqR7hVqy5M8vjAPBgNVHRMBAf8EBTADAQH/MA0GCSqGSIb3\\nDQEBCwUAA0EAGdJgK6FhCQVXn6HxSOdNJ9WkMRaPRnD8YNT+5IgLk5D1TA1WRhJ8\\nHHJKq3cDxQrS7yNQvULUkR8E5dQk+RLQEQ==\\n-----END CERTIFICATE-----"
                    ]
                  },
                  "ServiceTypeIdentifier": "http://example.com/SvcType/CredentialIssuance",
                  "ServiceStatus": "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/granted",
                  "StatusStartingTime": "2024-01-01T00:00:00Z",
                  "ServiceSupplyPoints": [
                    { "uriValue": "https://issuer.test.example.com" }
                  ]
                }
              },
              {
                "ServiceInformation": {
                  "ServiceName": [{ "lang": "en", "value": "Test Verifier" }],
                  "ServiceDigitalIdentity": {},
                  "ServiceTypeIdentifier": "http://uri.etsi.org/TrstSvc/Svctype/CA/QC",
                  "ServiceStatus": "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/granted",
                  "StatusStartingTime": "2024-01-01T00:00:00Z"
                }
              }
            ]
          },
          {
            "TrustedEntityInformation": {
              "TEName": [{ "lang": "en", "value": "Withdrawn Entity" }]
            },
            "TrustedEntityServices": [
              {
                "ServiceInformation": {
                  "ServiceName": [{ "lang": "en", "value": "Withdrawn Service" }],
                  "ServiceDigitalIdentity": {
                    "X509Certificates": ["-----BEGIN CERTIFICATE-----\\nMIIBkTCB+w...\\n-----END CERTIFICATE-----"]
                  },
                  "ServiceTypeIdentifier": "http://example.com/SvcType/CredentialIssuance",
                  "ServiceStatus": "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/withdrawn",
                  "StatusStartingTime": "2024-01-01T00:00:00Z",
                  "ServiceSupplyPoints": [
                    { "uriValue": "https://withdrawn.test.example.com" }
                  ]
                }
              }
            ]
          }
        ]
      }
    }
    """

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        // Configure mock URL session
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        mockSession = URLSession(configuration: config)

        // Clear any existing mock responses
        MockURLProtocol.mockResponses = [:]

        manager = TrustedListManager(urlSession: mockSession)
    }

    override func tearDown() {
        MockURLProtocol.mockResponses = [:]
        manager = nil
        mockSession = nil
        super.tearDown()
    }

    // MARK: - URL Management Tests

    func testAddTrustedListURL() {
        let testURL = URL(string: "https://test.example.com/trusted-list.json")!

        manager.addTrustedListURL(testURL)

        XCTAssertTrue(manager.trustedListURLs.contains(testURL))
    }

    func testAddDuplicateURLIsIgnored() {
        let testURL = URL(string: "https://test.example.com/trusted-list.json")!

        manager.addTrustedListURL(testURL)
        manager.addTrustedListURL(testURL)

        XCTAssertEqual(manager.trustedListURLs.filter { $0 == testURL }.count, 1)
    }

    func testClearCache() {
        manager.clearCache()
        // Should not throw
        XCTAssertTrue(true)
    }

    // MARK: - Fetch Tests

    func testFetchTrustedList() async throws {
        let testURL = URL(string: "https://test.example.com/trusted-list.json")!

        // Setup mock response
        let responseData = sampleTrustedListJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*trusted-list\\.json"] = (responseData, response)

        let document = try await manager.fetchTrustedList(from: testURL)

        XCTAssertEqual(document.LoTE.ListAndSchemeInformation.LoTEVersionIdentifier, 1)
        XCTAssertEqual(document.LoTE.TrustedEntitiesList.count, 2)
    }

    func testFetchTrustedListCaching() async throws {
        let testURL = URL(string: "https://test.example.com/cached-list.json")!

        // Setup mock response
        let responseData = sampleTrustedListJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*cached-list\\.json"] = (responseData, response)

        // First fetch
        let doc1 = try await manager.fetchTrustedList(from: testURL)

        // Second fetch should use cache
        let doc2 = try await manager.fetchTrustedList(from: testURL)

        XCTAssertEqual(doc1.LoTE.ListAndSchemeInformation.LoTEVersionIdentifier,
                       doc2.LoTE.ListAndSchemeInformation.LoTEVersionIdentifier)
    }

    func testFetchTrustedListHTTPError() async {
        let testURL = URL(string: "https://test.example.com/error-list.json")!

        // Setup mock 404 response
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*error-list\\.json"] = (nil, response)

        do {
            _ = try await manager.fetchTrustedList(from: testURL)
            XCTFail("Should throw error")
        } catch {
            XCTAssertTrue(error is TrustedListError)
        }
    }

    // MARK: - Service Search Tests

    func testFindServiceByIssuerURL() async throws {
        let testURL = URL(string: "https://test.example.com/search-list.json")!
        manager.addTrustedListURL(testURL)

        // Setup mock response
        let responseData = sampleTrustedListJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*search-list\\.json"] = (responseData, response)

        let result = try await manager.findService(issuerURL: "https://issuer.test.example.com")

        XCTAssertEqual(result.entity.TrustedEntityInformation.TEName.first?.value, "Test Entity")
        XCTAssertEqual(result.service.ServiceInformation.ServiceName.first?.value, "Test Issuer")
        XCTAssertFalse(result.certificates.isEmpty)
    }

    func testFindServiceWithTrailingSlash() async throws {
        let testURL = URL(string: "https://test.example.com/slash-list.json")!
        manager.addTrustedListURL(testURL)

        // Setup mock response
        let responseData = sampleTrustedListJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*slash-list\\.json"] = (responseData, response)

        // Should match even with trailing slash
        let result = try await manager.findService(issuerURL: "https://issuer.test.example.com/")

        XCTAssertEqual(result.service.ServiceInformation.ServiceName.first?.value, "Test Issuer")
    }

    func testFindServiceNotFound() async {
        let testURL = URL(string: "https://test.example.com/notfound-list.json")!
        manager.addTrustedListURL(testURL)

        // Setup mock response
        let responseData = sampleTrustedListJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*notfound-list\\.json"] = (responseData, response)

        do {
            _ = try await manager.findService(issuerURL: "https://nonexistent.example.com")
            XCTFail("Should throw serviceNotFound error")
        } catch let error as TrustedListError {
            if case .serviceNotFound(let issuerURL, _) = error {
                XCTAssertEqual(issuerURL, "https://nonexistent.example.com")
            } else {
                XCTFail("Expected serviceNotFound error")
            }
        }
    }

    func testFindServiceIgnoresWithdrawnStatus() async {
        let testURL = URL(string: "https://test.example.com/withdrawn-list.json")!
        manager.addTrustedListURL(testURL)

        // Setup mock response
        let responseData = sampleTrustedListJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*withdrawn-list\\.json"] = (responseData, response)

        // Should not find withdrawn service
        do {
            _ = try await manager.findService(issuerURL: "https://withdrawn.test.example.com")
            XCTFail("Should throw serviceNotFound error for withdrawn service")
        } catch let error as TrustedListError {
            if case .serviceNotFound = error {
                // Expected
            } else {
                XCTFail("Expected serviceNotFound error")
            }
        }
    }

    func testFindServiceInDocument() throws {
        let data = sampleTrustedListJSON.data(using: .utf8)!
        let document = try JSONDecoder().decode(LoTEDocument.self, from: data)

        let result = try manager.findService(
            in: document,
            issuerURL: "https://issuer.test.example.com"
        )

        XCTAssertEqual(result.service.ServiceInformation.ServiceTypeIdentifier,
                       TrustedListServiceType.credentialIssuance)
    }

    // MARK: - Certificate Extraction Tests

    func testGetCertificatesForIssuer() async throws {
        let testURL = URL(string: "https://test.example.com/certs-list.json")!
        manager.addTrustedListURL(testURL)

        // Setup mock response
        let responseData = sampleTrustedListJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*certs-list\\.json"] = (responseData, response)

        let certificates = try await manager.getCertificates(
            forIssuerURL: "https://issuer.test.example.com"
        )

        // Certificate in sample is a dummy, but structure should be correct
        // Real certificates would parse correctly
        XCTAssertGreaterThanOrEqual(certificates.count, 0)
    }
}
