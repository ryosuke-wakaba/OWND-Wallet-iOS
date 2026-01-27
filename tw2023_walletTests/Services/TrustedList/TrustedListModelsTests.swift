//
//  TrustedListModelsTests.swift
//  tw2023_walletTests
//
//  Tests for ETSI TS 119 602 (LoTE) data model parsing.
//

import XCTest
@testable import tw2023_wallet

final class TrustedListModelsTests: XCTestCase {

    // MARK: - Sample JSON

    let sampleJSON = """
    {
      "LoTE": {
        "ListAndSchemeInformation": {
          "LoTEVersionIdentifier": 1,
          "LoTESequenceNumber": 8,
          "SchemeOperatorName": [
            { "lang": "en", "value": "Japan Trust Framework Authority" },
            { "lang": "ja", "value": "日本トラストフレームワーク機関" }
          ],
          "ListIssueDateTime": "2026-01-06T09:42:06.337Z",
          "NextUpdate": "2026-01-13T09:42:06.337Z",
          "SchemeTerritory": "JP"
        },
        "TrustedEntitiesList": [
          {
            "TrustedEntityInformation": {
              "TEName": [
                { "lang": "en", "value": "Foo University" },
                { "lang": "ja", "value": "Foo 大学" }
              ],
              "TEInformationURI": [
                { "lang": "en", "uriValue": "https://foo.ac.jp" }
              ]
            },
            "TrustedEntityServices": [
              {
                "ServiceInformation": {
                  "ServiceName": [
                    { "lang": "en", "value": "Credential Issuer" }
                  ],
                  "ServiceDigitalIdentity": {
                    "X509Certificates": [
                      { "val": "MIIBkTCB+wIJAKHBfpeg" }
                    ]
                  },
                  "ServiceTypeIdentifier": "http://example.com/SvcType/CredentialIssuance",
                  "ServiceStatus": "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/granted",
                  "StatusStartingTime": "2025-12-18T08:02:29.392Z",
                  "ServiceSupplyPoints": [
                    { "uriValue": "https://issuer.example.com" }
                  ]
                }
              }
            ]
          }
        ]
      }
    }
    """

    // MARK: - Tests

    func testParseLoTEDocument() throws {
        let data = sampleJSON.data(using: .utf8)!
        let document = try JSONDecoder().decode(LoTEDocument.self, from: data)

        XCTAssertEqual(document.LoTE.ListAndSchemeInformation.LoTEVersionIdentifier, 1)
        XCTAssertEqual(document.LoTE.ListAndSchemeInformation.LoTESequenceNumber, 8)
        XCTAssertEqual(document.LoTE.ListAndSchemeInformation.SchemeTerritory, "JP")
    }

    func testParseSchemeOperatorName() throws {
        let data = sampleJSON.data(using: .utf8)!
        let document = try JSONDecoder().decode(LoTEDocument.self, from: data)

        let operatorNames = document.LoTE.ListAndSchemeInformation.SchemeOperatorName
        XCTAssertEqual(operatorNames.count, 2)

        let englishName = operatorNames.first { $0.lang == "en" }
        XCTAssertEqual(englishName?.value, "Japan Trust Framework Authority")

        let japaneseName = operatorNames.first { $0.lang == "ja" }
        XCTAssertEqual(japaneseName?.value, "日本トラストフレームワーク機関")
    }

    func testParseTrustedEntitiesList() throws {
        let data = sampleJSON.data(using: .utf8)!
        let document = try JSONDecoder().decode(LoTEDocument.self, from: data)

        XCTAssertEqual(document.LoTE.TrustedEntitiesList.count, 1)

        let entity = document.LoTE.TrustedEntitiesList[0]
        let entityName = entity.TrustedEntityInformation.TEName.first { $0.lang == "en" }
        XCTAssertEqual(entityName?.value, "Foo University")
    }

    func testParseServiceInformation() throws {
        let data = sampleJSON.data(using: .utf8)!
        let document = try JSONDecoder().decode(LoTEDocument.self, from: data)

        let entity = document.LoTE.TrustedEntitiesList[0]
        XCTAssertEqual(entity.TrustedEntityServices.count, 1)

        let service = entity.TrustedEntityServices[0].ServiceInformation
        XCTAssertEqual(service.ServiceTypeIdentifier, TrustedListServiceType.credentialIssuance)
        XCTAssertEqual(service.ServiceStatus, TrustedListServiceStatus.granted)
    }

    func testParseServiceSupplyPoints() throws {
        let data = sampleJSON.data(using: .utf8)!
        let document = try JSONDecoder().decode(LoTEDocument.self, from: data)

        let service = document.LoTE.TrustedEntitiesList[0].TrustedEntityServices[0].ServiceInformation
        XCTAssertNotNil(service.ServiceSupplyPoints)
        XCTAssertEqual(service.ServiceSupplyPoints?.count, 1)
        XCTAssertEqual(service.ServiceSupplyPoints?.first?.uriValue, "https://issuer.example.com")
    }

    func testParseServiceDigitalIdentity() throws {
        let data = sampleJSON.data(using: .utf8)!
        let document = try JSONDecoder().decode(LoTEDocument.self, from: data)

        let service = document.LoTE.TrustedEntitiesList[0].TrustedEntityServices[0].ServiceInformation
        XCTAssertNotNil(service.ServiceDigitalIdentity.X509Certificates)
        XCTAssertEqual(service.ServiceDigitalIdentity.X509Certificates?.count, 1)
        // Per ETSI TS 119 602 public schema, X509Certificates contains pkiOb objects with base64-encoded DER
        XCTAssertNotNil(service.ServiceDigitalIdentity.X509Certificates?.first?.val)
        XCTAssertFalse(service.ServiceDigitalIdentity.X509Certificates?.first?.val.isEmpty ?? true)
    }

    func testServiceTypeConstants() {
        XCTAssertEqual(TrustedListServiceType.credentialIssuance, "http://example.com/SvcType/CredentialIssuance")
        XCTAssertEqual(TrustedListServiceType.walletProvider, "http://uri.etsi.org/TrstSvc/Svctype/WalletProvider")
    }

    func testServiceStatusConstants() {
        XCTAssertEqual(TrustedListServiceStatus.granted, "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/granted")
        XCTAssertEqual(TrustedListServiceStatus.withdrawn, "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/withdrawn")
    }

    // MARK: - Real Sample Data Test

    func testParseRealSampleData() throws {
        // Read the sample trustedlist.json from project root
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent() // TrustedList
            .deletingLastPathComponent() // Services
            .deletingLastPathComponent() // tw2023_walletTests
            .deletingLastPathComponent() // OWND-Wallet-iOS

        let samplePath = projectRoot.appendingPathComponent("trustedlist.json")

        guard FileManager.default.fileExists(atPath: samplePath.path) else {
            // Skip if sample file doesn't exist
            print("Skipping test: trustedlist.json not found at \(samplePath.path)")
            return
        }

        let data = try Data(contentsOf: samplePath)
        let document = try JSONDecoder().decode(LoTEDocument.self, from: data)

        // Verify basic structure
        XCTAssertGreaterThan(document.LoTE.TrustedEntitiesList.count, 0)

        // Find credential issuance service
        var foundIssuanceService = false
        for entity in document.LoTE.TrustedEntitiesList {
            for service in entity.TrustedEntityServices {
                if service.ServiceInformation.ServiceTypeIdentifier == TrustedListServiceType.credentialIssuance {
                    foundIssuanceService = true
                    XCTAssertNotNil(service.ServiceInformation.ServiceSupplyPoints)
                    XCTAssertNotNil(service.ServiceInformation.ServiceDigitalIdentity.X509Certificates)
                }
            }
        }

        XCTAssertTrue(foundIssuanceService, "Should find at least one credential issuance service")
    }
}
