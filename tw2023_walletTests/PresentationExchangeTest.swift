//
//  PresentationExchangeTest.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2024/11/21.
//

import XCTest

@testable import tw2023_wallet

final class PresentationExchangeTest: XCTestCase {

    var subsetRelationship: PresentationDefinition?

    let sdJwtPrefecture =
        "eyJ0eXAiOiJzZCtqd3QiLCJhbGciOiJFUzI1NiJ9.eyJfc2QiOlsiZnJpakxvSm1qQnhxTzk1c1A0WVAzMVJJNGJkd2ctdnlVZWpDZUlxTlJTYyJdLCJfc2RfYWxnIjoiU0hBLTI1NiJ9.WCGcU9Ox6PYKMtDazkxztXm0qUZ4nXeTDvx875ZNNQ5_dj4yyUCdZdEoCzPMkiySUo6hirMIliAK4EhG39g3sg~WyI0ZTk5MWMzNjQ4ZjU2ZTg4IiwicHJlZmVjdHVyZSIsIlRva3lvIl0~"

    let sdJwtPrefectureAndPostalCode =
        "eyJ0eXAiOiJzZCtqd3QiLCJhbGciOiJFUzI1NiJ9.eyJfc2QiOlsiMlMxRXdhV1RBMEpGRlhSNXlySW1VbW9jekhwb3dNQ1c5OUw5SW5wUGdWbyIsIlNQVC0xMk81UU1YSHhseUNuLWtrTTRzM2FYa0s5ejZ5dzBuT01CMTdSVVkiXSwiX3NkX2FsZyI6IlNIQS0yNTYifQ.yoldrSUzadig98dyWm2CWoEOsWTuOD51qv5Q37dxIZUm-GTVnBjChLnYWZiXaTwcTqFrYKWnKDFusfPhltAV3g~WyJhNmFiODFkNTk2ODBkYjQ2IiwicHJlZmVjdHVyZSIsIlRva3lvIl0~WyJkYzgwYjZmZjI2OGQ2Y2M4IiwicG9zdGFsX2NvZGUiLCIxMjMiXQ~"
    
    let sdJwtPostalCode = "eyJ0eXAiOiJzZCtqd3QiLCJhbGciOiJFUzI1NiJ9.eyJfc2QiOlsiWS1WUS1VZHBFVlhxazF1WWJoQnkwaFFkREdGVEwxRHE3UGRnT1JhUTFMUSJdLCJfc2RfYWxnIjoiU0hBLTI1NiJ9.mnjJ6fCfwphf4y4WKZ1zysDUDDlhPE1_pVD5ONufnzjqGMXlFKXxocv6LxBE5RpRiKK3O0uicwG09MrfHzUabw~WyJmNzNjZDg1ZWUyMjVjMDRjIiwicG9zdGFsX2NvZGUiLCIxMjMiXQ~"
    
    let sdJwtPostalCodeAndFamilyGivenName = "eyJ0eXAiOiJzZCtqd3QiLCJhbGciOiJFUzI1NiJ9.eyJfc2QiOlsiSGQ4T0swS2FmMDJqd3BncnI4MlBsWnJTYUJlUXhmRXB1SlY5YzlBUi1jcyIsImJuenJQUDNBcGhyaTMtWi1uaHhFeEY2NXFZRHA3UnE5MktNem54aVBGMkkiLCJ0Qm9oZDFtVUlaLVAydERoYV9EVHpsaS1zQk5JYkhyMmh0Sm9NS3E1dmtjIl0sIl9zZF9hbGciOiJTSEEtMjU2In0.WBmCzLb19vpT_JVl6Ai9ObMW39V3U5l1PEBOUlpu58Wt77KR1KdYUPBAWQJxhNENzlMEn1RJeIN0RaXggdBIBQ~WyJkOWQ0Y2ZkNzljMjhkYWYzIiwicG9zdGFsX2NvZGUiLCIxMjMiXQ~WyIzOWNhNDcyNzAyZmEzZWZiIiwiZmFtaWx5X25hbWUiLCJZYW1hZGEiXQ~WyJmNWNlYzY1MTY2NTAyMzVjIiwiZ2l2ZW5fbmFtZSIsIlRhcm8iXQ~"

    
    private func decodePresentationDefinition(resourceFile: String) throws -> PresentationDefinition
    {
        let url = Bundle.main.url(
            forResource: resourceFile, withExtension: "json")!
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(PresentationDefinition.self, from: data)
    }

    override func setUpWithError() throws {
        decodeDisclosureFunction = SDJwtUtil.decodeDisclosure
        subsetRelationship = try decodePresentationDefinition(
            resourceFile: "presentation_definition_multi_descriptors_2")
    }

    override func tearDownWithError() throws {
    }
    
    func testSelectFirstInputDescriptor() throws {
        guard let pd = subsetRelationship else {
            XCTFail("The presentation definition has not been initialized correctly.")
            return
        }
        
        guard
            let (firstMatchedInputDescriptor, disclosureWithOptionality) =
                pd.firstMatchedInputDescriptor(sdJwt: sdJwtPrefectureAndPostalCode) else {
            XCTFail("should be matched")
            return
        }
        
        XCTAssertEqual(firstMatchedInputDescriptor.id, "input1")
        XCTAssertTrue(disclosureWithOptionality.count == 2)
        for d in disclosureWithOptionality {
            XCTAssertTrue(d.isSubmit)
            XCTAssertTrue(!d.isUserSelectable)
        }
    }

    func testSelectSecondInputDescriptor() throws {
        guard let pd = subsetRelationship else {
            XCTFail("The presentation definition has not been initialized correctly.")
            return
        }

        guard
            let (firstMatchedInputDescriptor, disclosureWithOptionality) =
                pd.firstMatchedInputDescriptor(sdJwt: sdJwtPrefecture)
        else {
            XCTFail("shoud be matched")
            return
        }

        XCTAssertEqual(firstMatchedInputDescriptor.id, "input2")
        XCTAssertTrue(disclosureWithOptionality.count == 1)
        XCTAssertTrue(disclosureWithOptionality[0].isSubmit)
        XCTAssertTrue(!disclosureWithOptionality[0].isUserSelectable)
    }
    
    func testSelectThirdInputDescriptor1() throws {
        guard let pd = subsetRelationship else {
            XCTFail("The presentation definition has not been initialized correctly.")
            return
        }

        guard
            let (firstMatchedInputDescriptor, disclosureWithOptionality) =
                pd.firstMatchedInputDescriptor(sdJwt: sdJwtPostalCode)
        else {
            XCTFail("shoud be matched")
            return
        }

        XCTAssertEqual(firstMatchedInputDescriptor.id, "input3")
        XCTAssertTrue(disclosureWithOptionality.count == 1)
        XCTAssertTrue(disclosureWithOptionality[0].isSubmit)
        XCTAssertTrue(!disclosureWithOptionality[0].isUserSelectable)
    }
    
    func testSelectThirdInputDescriptor2() throws {
        guard let pd = subsetRelationship else {
            XCTFail("The presentation definition has not been initialized correctly.")
            return
        }

        guard
            let (firstMatchedInputDescriptor, disclosureWithOptionality) =
                pd.firstMatchedInputDescriptor(sdJwt: sdJwtPostalCodeAndFamilyGivenName)
        else {
            XCTFail("shoud be matched")
            return
        }

        XCTAssertEqual(firstMatchedInputDescriptor.id, "input3")
        XCTAssertTrue(disclosureWithOptionality.count == 3)
        for d in disclosureWithOptionality {
            if d.isSubmit {
                XCTAssertTrue(!d.isUserSelectable)
                XCTAssertEqual(d.disclosure.key, "postal_code") // 必須で求められている
            }else {
                if (d.isUserSelectable) {
                    XCTAssertEqual(d.disclosure.key, "family_name") // オプション
                }else{
                    XCTAssertEqual(d.disclosure.key, "given_name") // 送信しない
                }
            }
        }
    }
}
