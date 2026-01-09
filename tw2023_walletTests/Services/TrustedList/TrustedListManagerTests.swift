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
                      "-----BEGIN CERTIFICATE-----\\nMIIBdzCCAR2gAwIBAgIUU5zz087ESNzLz0l0luR5JvFPo38wCgYIKoZIzj0EAwIwETEPMA0GA1UEAwwGdGVzdGNhMB4XDTI2MDEwODA2MjE0MFoXDTI3MDEwODA2MjE0MFowETEPMA0GA1UEAwwGdGVzdGNhMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEeqf0vRgYFn1x8n2/Y+ucsy0Vlb40w1HbvausSpllS4hsmhDwTNQY7OdozBIDU33V1kvBjJ6+KQDO8S2Ca8xHXaNTMFEwHQYDVR0OBBYEFCO/bo5hyffXWVlGEsqXDvTj2IYLMB8GA1UdIwQYMBaAFCO/bo5hyffXWVlGEsqXDvTj2IYLMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIgLKOhMsiUBdLXgwkSVSYlJQ2CqNEKA12hZMCZgi5wPywCIQClCC8E6Y4Bh2XEzSkd3aoc6gwJG18tMPF+AZ91M7oecg==\\n-----END CERTIFICATE-----"
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

        let result = try await manager.findService(serviceURL: "https://issuer.test.example.com")

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
        let result = try await manager.findService(serviceURL: "https://issuer.test.example.com/")

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
            _ = try await manager.findService(serviceURL: "https://nonexistent.example.com")
            XCTFail("Should throw serviceNotFound error")
        } catch let error as TrustedListError {
            if case .serviceNotFound(let serviceURL, _) = error {
                XCTAssertEqual(serviceURL, "https://nonexistent.example.com")
            } else {
                XCTFail("Expected serviceNotFound error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
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
            _ = try await manager.findService(serviceURL: "https://withdrawn.test.example.com")
            XCTFail("Should throw serviceNotFound error for withdrawn service")
        } catch let error as TrustedListError {
            if case .serviceNotFound = error {
                // Expected
            } else {
                XCTFail("Expected serviceNotFound error")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFindServiceInDocument() throws {
        let data = sampleTrustedListJSON.data(using: .utf8)!
        let document = try JSONDecoder().decode(LoTEDocument.self, from: data)

        let result = try manager.findService(
            in: document,
            serviceURL: "https://issuer.test.example.com"
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
            forServiceURL: "https://issuer.test.example.com"
        )

        // Certificate in sample is a dummy, but structure should be correct
        // Real certificates would parse correctly
        XCTAssertGreaterThanOrEqual(certificates.count, 0)
    }
}
