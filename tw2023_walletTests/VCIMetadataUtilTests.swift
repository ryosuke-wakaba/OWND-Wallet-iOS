//
//  VCIMetadataUtilTests.swift
//  tw2023_walletTests
//
//  Created by 若葉良介 on 2024/01/05.
//

import XCTest

final class VCIMetadataUtilTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testFindMatchingCredentialsJwtVc() {
        let issuer = "https://datasign-demo-vci.tunnelto.dev"
        guard
            let data = try? loadCredentialIssuerMetadata(
                credentialSupportedFileNames: ["credential_supported_jwt_vc"])
        else {
            XCTFail("Cannot read credential_issuer_metadata.json")
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let metadata = try decoder.decode(CredentialIssuerMetadata.self, from: data)
            XCTAssertEqual(metadata.credentialIssuer, issuer)
            let types = ["VerifiableCredential", "UniversityDegreeCredential"]
            let credentialSupported = VCIMetadataUtil.findMatchingCredentials(
                format: "jwt_vc_json", types: types, metadata: metadata)
            XCTAssertNotNil(credentialSupported)
        }
        catch {
            print(error)
            XCTFail("Request should not fail")
        }
    }

    func testFindMatchingCredentialsSdJwt() {
        let issuer = "https://datasign-demo-vci.tunnelto.dev"
        guard
            let data = try? loadCredentialIssuerMetadata(
                credentialSupportedFileNames: ["credential_supported_vc_sd_jwt"])
        else {
            XCTFail("Cannot read credential_issuer_metadata.json")
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let metadata = try decoder.decode(CredentialIssuerMetadata.self, from: data)
            XCTAssertEqual(metadata.credentialIssuer, issuer)
            let vct = "SD_JWT_VC_example_in_OpenID4VCI"
            let credentialSupported = VCIMetadataUtil.findMatchingCredentials(
                format: "dc+sd-jwt", types: [vct], metadata: metadata)
            XCTAssertNotNil(credentialSupported)
        }
        catch {
            XCTFail("Request should not fail")
        }
    }

    func testExtractDisplayByClaim() {
        let issuer = "https://datasign-demo-vci.tunnelto.dev"
        guard
            let data = try? loadCredentialIssuerMetadata(
                credentialSupportedFileNames: ["credential_supported_vc_sd_jwt"])
        else {
            XCTFail("Cannot read credential_issuer_metadata.json")
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let metadata = try decoder.decode(CredentialIssuerMetadata.self, from: data)
            XCTAssertEqual(metadata.credentialIssuer, issuer)
            let vct = "SD_JWT_VC_example_in_OpenID4VCI"
            let credentialSupported = VCIMetadataUtil.findMatchingCredentials(
                format: "dc+sd-jwt", types: [vct], metadata: metadata)
            if let credentialSupported = credentialSupported {
                let displayMap = VCIMetadataUtil.extractDisplayByClaim(
                    credentialsSupported: credentialSupported)

                print(displayMap)

                XCTAssertNotNil(displayMap)
                // Updated SD-JWT credential has: given_name, family_name, address
                XCTAssertTrue(displayMap.count >= 3)

                if let display1 = displayMap["given_name"] {
                    XCTAssertEqual(display1.count, 2)
                    XCTAssertEqual(display1[0].name, "Given Name")
                    XCTAssertEqual(display1[1].name, "Vorname")
                }
                else {
                    XCTFail("Display for 'given_name' should exist")
                }
                if let display2 = displayMap["family_name"] {
                    XCTAssertEqual(display2.count, 2)
                    XCTAssertEqual(display2[0].name, "Surname")
                    XCTAssertEqual(display2[1].name, "Nachname")
                }
                else {
                    XCTFail("Display for 'family_name' should exist")
                }
                if let display3 = displayMap["address"] {
                    XCTAssertEqual(display3.count, 2)
                    XCTAssertEqual(display3[0].name, "Place of residence")
                    XCTAssertEqual(display3[1].name, "Wohnsitz")
                }
                else {
                    XCTFail("Display for 'address' should exist")
                }
            }
            else {
                XCTFail("ExtractDisplayByClaim should not fail")
            }
        }
        catch {
            XCTFail("Decode should not fail")
        }
    }

    func testSerializationAndDeserialization() {
        let issuer = "https://datasign-demo-vci.tunnelto.dev"
        guard
            let data = try? loadCredentialIssuerMetadata(
                credentialSupportedFileNames: ["credential_supported_vc_sd_jwt"])
        else {
            XCTFail("Cannot read credential_issuer_metadata.json")
            return
        }
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let metadata = try decoder.decode(CredentialIssuerMetadata.self, from: data)
            XCTAssertEqual(metadata.credentialIssuer, issuer)
            let vct = "SD_JWT_VC_example_in_OpenID4VCI"
            guard
                let credentialSupported = VCIMetadataUtil.findMatchingCredentials(
                    format: "dc+sd-jwt", types: [vct], metadata: metadata)
            else {
                XCTFail("ExtractDisplayByClaim should not fail")
                return
            }

            let displayMap = VCIMetadataUtil.extractDisplayByClaim(
                credentialsSupported: credentialSupported)

            // 一度シリアライズ
            let serialized = VCIMetadataUtil.serializeDisplayByClaimMap(displayMap: displayMap)
            // デシリアライズ
            let deserialized = VCIMetadataUtil.deserializeDisplayByClaimMap(
                displayMapString: serialized)

            XCTAssertNotNil(deserialized)
            XCTAssertTrue(deserialized.count >= 3)

            if let display1 = deserialized["given_name"] {
                XCTAssertEqual(display1.count, 2)
                XCTAssertEqual(display1[0].name, "Given Name")
                XCTAssertEqual(display1[1].name, "Vorname")
            }
            else {
                XCTFail("Display for 'given_name' should exist")
            }

            if let display2 = deserialized["family_name"] {
                XCTAssertEqual(display2.count, 2)
                XCTAssertEqual(display2[0].name, "Surname")
                XCTAssertEqual(display2[1].name, "Nachname")
            }
            else {
                XCTFail("Display for 'family_name' should exist")
            }

            // あとは割愛
        }
        catch {
            XCTFail("Decode should not fail")
        }
    }

}
