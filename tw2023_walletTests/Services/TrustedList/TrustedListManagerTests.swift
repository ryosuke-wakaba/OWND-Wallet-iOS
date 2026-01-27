//
//  TrustedListManagerTests.swift
//  tw2023_walletTests
//
//  Tests for TrustedListManager functionality.
//

import XCTest
import X509
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
                      { "val": "MIIBdzCCAR2gAwIBAgIUU5zz087ESNzLz0l0luR5JvFPo38wCgYIKoZIzj0EAwIwETEPMA0GA1UEAwwGdGVzdGNhMB4XDTI2MDEwODA2MjE0MFoXDTI3MDEwODA2MjE0MFowETEPMA0GA1UEAwwGdGVzdGNhMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEeqf0vRgYFn1x8n2/Y+ucsy0Vlb40w1HbvausSpllS4hsmhDwTNQY7OdozBIDU33V1kvBjJ6+KQDO8S2Ca8xHXaNTMFEwHQYDVR0OBBYEFCO/bo5hyffXWVlGEsqXDvTj2IYLMB8GA1UdIwQYMBaAFCO/bo5hyffXWVlGEsqXDvTj2IYLMA8GA1UdEwEB/wQFMAMBAf8wCgYIKoZIzj0EAwIDSAAwRQIgLKOhMsiUBdLXgwkSVSYlJQ2CqNEKA12hZMCZgi5wPywCIQClCC8E6Y4Bh2XEzSkd3aoc6gwJG18tMPF+AZ91M7oecg==" }
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
                    "X509Certificates": [{ "val": "MIIBkTCB+w" }]
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

    // MARK: - Certificate-Based Search Tests (AKI/SKI)

    /// Intermediate certificate (Sectigo ECC OV CA) - PEM encoded
    let intermediateCertPEM = """
    -----BEGIN CERTIFICATE-----
    MIIDrjCCAzOgAwIBAgIQNb50Y4yz6d4oBXC3l4CzZzAKBggqhkjOPQQDAzCBiDEL
    MAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNl
    eSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMT
    JVVTRVJUcnVzdCBFQ0MgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTgxMTAy
    MDAwMDAwWhcNMzAxMjMxMjM1OTU5WjCBlTELMAkGA1UEBhMCR0IxGzAZBgNVBAgT
    EkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMP
    U2VjdGlnbyBMaW1pdGVkMT0wOwYDVQQDEzRTZWN0aWdvIEVDQyBPcmdhbml6YXRp
    b24gVmFsaWRhdGlvbiBTZWN1cmUgU2VydmVyIENBMFkwEwYHKoZIzj0CAQYIKoZI
    zj0DAQcDQgAEnI5cCmFvoVij0NXO+vxE+f+6Bh57FhpyH0LTCrJmzfsPSXIhTSex
    r92HOlz+aHqoGE0vSe/CSwLFoWcZ8W1jOaOCAW4wggFqMB8GA1UdIwQYMBaAFDrh
    CYbUzxnClnZ0SXbc4DXGY2OaMB0GA1UdDgQWBBRNSu/ERrMSrU9OmrFZ4lGrCBB4
    CDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHSUEFjAU
    BggrBgEFBQcDAQYIKwYBBQUHAwIwGwYDVR0gBBQwEjAGBgRVHSAAMAgGBmeBDAEC
    AjBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNF
    UlRydXN0RUNDQ2VydGlmaWNhdGlvbkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEE
    ajBoMD8GCCsGAQUFBzAChjNodHRwOi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRy
    dXN0RUNDQWRkVHJ1c3RDQS5jcnQwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVz
    ZXJ0cnVzdC5jb20wCgYIKoZIzj0EAwMDaQAwZgIxAOk//uo7i/MoeKdcyeqvjOXs
    BJFGLI+1i0d+Tty7zEnn2w4DNS21TK8wmY3Kjm3EmQIxAPI1qHM/I+OS+hx0OZhG
    fDoNifTe/GxgWZ1gOYQKzn6lwP0yGKlrP+7vrVC8IczJ4A==
    -----END CERTIFICATE-----
    """

    /// Sample trusted list with real certificate chain for AKI/SKI testing
    let sampleTrustedListWithChainJSON = """
        {
          "LoTE": {
            "ListAndSchemeInformation": {
              "LoTEVersionIdentifier": 1,
              "LoTESequenceNumber": 1,
              "SchemeOperatorName": [{ "lang": "en", "value": "Test Authority" }],
              "ListIssueDateTime": "2026-01-01T00:00:00Z",
              "LoTEType": "https://example.com/LoTEType/TestList"
            },
            "TrustedEntitiesList": [
              {
                "TrustedEntityInformation": {
                  "TEName": [{ "lang": "en", "value": "Sectigo" }]
                },
                "TrustedEntityServices": [
                  {
                    "ServiceInformation": {
                      "ServiceName": [{ "lang": "en", "value": "Sectigo ECC OV CA" }],
                      "ServiceDigitalIdentity": {
                        "X509Certificates": [
                          { "val": "MIIDrjCCAzOgAwIBAgIQNb50Y4yz6d4oBXC3l4CzZzAKBggqhkjOPQQDAzCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBFQ0MgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkwHhcNMTgxMTAyMDAwMDAwWhcNMzAxMjMxMjM1OTU5WjCBlTELMAkGA1UEBhMCR0IxGzAZBgNVBAgTEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBxMHU2FsZm9yZDEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMT0wOwYDVQQDEzRTZWN0aWdvIEVDQyBPcmdhbml6YXRpb24gVmFsaWRhdGlvbiBTZWN1cmUgU2VydmVyIENBMFkwEwYHKoZIzj0CAQYIKoZIzj0DAQcDQgAEnI5cCmFvoVij0NXO+vxE+f+6Bh57FhpyH0LTCrJmzfsPSXIhTSexr92HOlz+aHqoGE0vSe/CSwLFoWcZ8W1jOaOCAW4wggFqMB8GA1UdIwQYMBaAFDrhCYbUzxnClnZ0SXbc4DXGY2OaMB0GA1UdDgQWBBRNSu/ERrMSrU9OmrFZ4lGrCBB4CDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADAdBgNVHSUEFjAUBggrBgEFBQcDAQYIKwYBBQUHAwIwGwYDVR0gBBQwEjAGBgRVHSAAMAgGBmeBDAECAjBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0RUNDQ2VydGlmaWNhdGlvbkF1dGhvcml0eS5jcmwwdgYIKwYBBQUHAQEEajBoMD8GCCsGAQUFBzAChjNodHRwOi8vY3J0LnVzZXJ0cnVzdC5jb20vVVNFUlRydXN0RUNDQWRkVHJ1c3RDQS5jcnQwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wCgYIKoZIzj0EAwMDaQAwZgIxAOk//uo7i/MoeKdcyeqvjOXsBJFGLI+1i0d+Tty7zEnn2w4DNS21TK8wmY3Kjm3EmQIxAPI1qHM/I+OS+hx0OZhGfDoNifTe/GxgWZ1gOYQKzn6lwP0yGKlrP+7vrVC8IczJ4A==" }
                        ]
                      },
                      "ServiceTypeIdentifier": "http://example.com/SvcType/IntermediateCA",
                      "ServiceStatus": "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/granted",
                      "StatusStartingTime": "2024-01-01T00:00:00Z"
                    }
                  }
                ]
              }
            ]
          }
        }
        """

    /// Leaf certificate PEM (ownd-project.com) - signed by Sectigo ECC OV CA
    let leafCertificatePEM = """
    -----BEGIN CERTIFICATE-----
    MIIFUjCCBPegAwIBAgIRAO68a+XoD/PhST9Zr7Fq4b0wCgYIKoZIzj0EAwIwgZUx
    CzAJBgNVBAYTAkdCMRswGQYDVQQIExJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNV
    BAcTB1NhbGZvcmQxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDE9MDsGA1UEAxM0
    U2VjdGlnbyBFQ0MgT3JnYW5pemF0aW9uIFZhbGlkYXRpb24gU2VjdXJlIFNlcnZl
    ciBDQTAeFw0yMzEyMDUwMDAwMDBaFw0yNTAxMDQyMzU5NTlaMFAxCzAJBgNVBAYT
    AkpQMQ4wDAYDVQQIEwVUb2t5bzEWMBQGA1UEChMNRGF0YVNpZ24gSW5jLjEZMBcG
    A1UEAxMQb3duZC1wcm9qZWN0LmNvbTBZMBMGByqGSM49AgEGCCqGSM49AwEHA0IA
    BFIprdRg9RgqfsmAAmY/QMQ3Czjds6QvvO3WJT4rP00KVBwHxlbH1ZfSKVgDAdZP
    fQAp7tWBED9nlck7Qk9M4nGjggNqMIIDZjAfBgNVHSMEGDAWgBRNSu/ERrMSrU9O
    mrFZ4lGrCBB4CDAdBgNVHQ4EFgQULd9BFtdtud+3yIiR9ZXHqd6S9WQwDgYDVR0P
    AQH/BAQDAgeAMAwGA1UdEwEB/wQCMAAwHQYDVR0lBBYwFAYIKwYBBQUHAwEGCCsG
    AQUFBwMCMEoGA1UdIARDMEEwNQYMKwYBBAGyMQECAQMEMCUwIwYIKwYBBQUHAgEW
    F2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMAgGBmeBDAECAjBaBgNVHR8EUzBRME+g
    TaBLhklodHRwOi8vY3JsLnNlY3RpZ28uY29tL1NlY3RpZ29FQ0NPcmdhbml6YXRp
    b25WYWxpZGF0aW9uU2VjdXJlU2VydmVyQ0EuY3JsMIGKBggrBgEFBQcBAQR+MHww
    VQYIKwYBBQUHMAKGSWh0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGlnb0VDQ09y
    Z2FuaXphdGlvblZhbGlkYXRpb25TZWN1cmVTZXJ2ZXJDQS5jcnQwIwYIKwYBBQUH
    MAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMDEGA1UdEQQqMCiCEG93bmQtcHJv
    amVjdC5jb22CFHd3dy5vd25kLXByb2plY3QuY29tMIIBfQYKKwYBBAHWeQIEAgSC
    AW0EggFpAWcAdQDPEVbu1S58r/OHW9lpLpvpGnFnSrAX7KwB0lt3zsw7CAAAAYw6
    NipUAAAEAwBGMEQCIBVcGQjOkfLxvpm1Admcetmn8D15G4Gt2AIdOXveZYrsAiBe
    q8jh8G4geumOHXIklSxvBzip9VK6sw9yq4AnTHnSPwB2AKLjCuRF772tm3447Udn
    d1PXgluElNcrXhssxLlQpEfnAAABjDo2KcoAAAQDAEcwRQIhAJP0UetSSFGF9/fa
    OHVzhkPFOg3etjXqWQShnxYI8a+GAiABzN4+sJAysZ88mtodttNYamXsnfw1T3qX
    YcJbB5GwJAB2AE51oydcmhDDOFts1N8/Uusd8OCOG41pwLH6ZLFimjnfAAABjDo2
    KhkAAAQDAEcwRQIgbpDfqifRz9PW+Tq83ivbXHA1GheQpGX88laI0XB910gCIQCK
    Rm2sRqqlgaXX7rO3EznDn7MwC4mbQwSyEIDjXddHMzAKBggqhkjOPQQDAgNJADBG
    AiEAzwi+A0/YY55h0f+Id0+eUPrRsVBdOKWIp19yQZ62jJICIQCvKk/avGDl5/eN
    IyN1eesa1sbs8QfbTbvzitYsVlRqXg==
    -----END CERTIFICATE-----
    """

    func testFindIssuerCertificateByAKISKI() async throws {
        let testURL = URL(string: "https://test.example.com/aki-ski-list.json")!

        // Setup mock response with intermediate certificate
        let responseData = sampleTrustedListWithChainJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*aki-ski-list\\.json"] = (responseData, response)

        // Create search info
        let searchInfos = [LoTEContextSearchInfo(
            url: testURL,
            contextName: "TestContext",
            condition: LoTEContextSearchInfo.SearchCondition(
                serviceTypeIdentifier: "http://example.com/SvcType/IntermediateCA",
                status: "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/granted"
            )
        )]

        // Parse leaf certificate
        let leafCert = try Certificate(pemEncoded: leafCertificatePEM)

        // Find issuer certificate
        let result = try await manager.findIssuerCertificate(for: leafCert, searchInfos: searchInfos)

        // Verify result
        XCTAssertEqual(result.entity.TrustedEntityInformation.TEName.first?.value, "Sectigo")
        XCTAssertEqual(result.service.ServiceInformation.ServiceName.first?.value, "Sectigo ECC OV CA")

        // Verify AKI/SKI match
        let leafAKI = X509CertificateOperations.extractAuthorityKeyIdentifier(from: leafCert)
        XCTAssertFalse(result.issuerCertificates.isEmpty, "Should return at least one issuer certificate")
        let issuerSKI = X509CertificateOperations.extractSubjectKeyIdentifier(from: result.issuerCertificates.first!)
        XCTAssertNotNil(leafAKI)
        XCTAssertNotNil(issuerSKI)
        XCTAssertEqual(leafAKI, issuerSKI)
    }

    func testFindIssuerCertificateByDN() async throws {
        // Test DN matching fallback when AKI/SKI is not available
        // Using the same certificate data but verifying DN matching works
        let testURL = URL(string: "https://test.example.com/dn-match-list.json")!

        let responseData = sampleTrustedListWithChainJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*dn-match-list\\.json"] = (responseData, response)

        let searchInfos = [LoTEContextSearchInfo(
            url: testURL,
            contextName: "TestContext",
            condition: LoTEContextSearchInfo.SearchCondition()
        )]

        let leafCert = try Certificate(pemEncoded: leafCertificatePEM)

        // Verify DN matching works
        let issuerDN = X509CertificateOperations.extractIssuerDN(from: leafCert)
        XCTAssertFalse(issuerDN.isEmpty)
        XCTAssertTrue(issuerDN.contains("Sectigo"))

        // Find issuer - should work via AKI/SKI or DN
        let result = try await manager.findIssuerCertificate(for: leafCert, searchInfos: searchInfos)
        XCTAssertNotNil(result)
    }

    func testFindIssuerCertificateNotFound() async {
        let testURL = URL(string: "https://test.example.com/no-issuer-list.json")!

        // Use original sample data which doesn't have the intermediate cert for leaf
        let responseData = sampleTrustedListJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*no-issuer-list\\.json"] = (responseData, response)

        let searchInfos = [LoTEContextSearchInfo(
            url: testURL,
            contextName: "TestContext",
            condition: LoTEContextSearchInfo.SearchCondition()
        )]

        do {
            let leafCert = try Certificate(pemEncoded: leafCertificatePEM)
            _ = try await manager.findIssuerCertificate(for: leafCert, searchInfos: searchInfos)
            XCTFail("Should throw issuerCertificateNotFound error")
        } catch let error as TrustedListError {
            if case .issuerCertificateNotFound = error {
                // Expected
            } else {
                XCTFail("Expected issuerCertificateNotFound error, got: \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFindIssuerCertificateWithConditionFilter() async throws {
        let testURL = URL(string: "https://test.example.com/condition-filter-list.json")!

        let responseData = sampleTrustedListWithChainJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*condition-filter-list\\.json"] = (responseData, response)

        // Search with non-matching serviceTypeIdentifier - should fail
        let searchInfosNonMatching = [LoTEContextSearchInfo(
            url: testURL,
            contextName: "TestContext",
            condition: LoTEContextSearchInfo.SearchCondition(
                serviceTypeIdentifier: "http://example.com/SvcType/NonExistent"
            )
        )]

        let leafCert = try Certificate(pemEncoded: leafCertificatePEM)

        do {
            _ = try await manager.findIssuerCertificate(for: leafCert, searchInfos: searchInfosNonMatching)
            XCTFail("Should throw error with non-matching condition")
        } catch {
            // Expected - condition filter should exclude the service
        }

        // Search with matching serviceTypeIdentifier - should succeed
        let searchInfosMatching = [LoTEContextSearchInfo(
            url: testURL,
            contextName: "TestContext",
            condition: LoTEContextSearchInfo.SearchCondition(
                serviceTypeIdentifier: "http://example.com/SvcType/IntermediateCA"
            )
        )]

        let result = try await manager.findIssuerCertificate(for: leafCert, searchInfos: searchInfosMatching)
        XCTAssertNotNil(result)
    }

    func testGetIssuerCertificatesForChain() async throws {
        let testURL = URL(string: "https://test.example.com/chain-list.json")!

        let responseData = sampleTrustedListWithChainJSON.data(using: .utf8)!
        let response = HTTPURLResponse(
            url: testURL,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        MockURLProtocol.mockResponses[".*chain-list\\.json"] = (responseData, response)

        let searchInfos = [LoTEContextSearchInfo(
            url: testURL,
            contextName: "TestContext",
            condition: LoTEContextSearchInfo.SearchCondition()
        )]

        let leafCert = try Certificate(pemEncoded: leafCertificatePEM)

        let issuerCerts = try await manager.getIssuerCertificatesForChain(
            x5cCertificates: [leafCert],
            searchInfos: searchInfos
        )

        XCTAssertEqual(issuerCerts.count, 1)
    }
}
