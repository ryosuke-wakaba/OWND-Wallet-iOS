//
//  ModelDataTests.swift
//  tw2023_walletTests
//
//  Created by katsuyoshi ozaki on 2024/08/21.
//

import Foundation
import XCTest
@testable import tw2023_wallet

final class ModelDataTests: XCTestCase {
    var modelData: ModelData!

    override func setUp() {
        super.setUp()
        modelData = ModelData()
    }

    override func tearDown() {
        modelData = nil
        super.tearDown()
    }

    func testLoadCredentials() {
        modelData.loadCredentials()
        XCTAssertFalse(modelData.credentials.isEmpty, "Credentials should not be empty after loading.")
    }

    func testLoadCredentialSharingHistories() {
        modelData.loadCredentialSharingHistories()
        XCTAssertFalse(modelData.credentialSharingHistories.isEmpty, "Credential Sharing Histories should not be empty after loading.")
    }

    func testLoadSharingHistories() {
        modelData.loadSharingHistories()
        XCTAssertFalse(modelData.sharingHistories.isEmpty, "Sharing Histories should not be empty after loading.")
    }

    func testLoadAuthorizationMetaDataList() {
        modelData.loadAuthorizationMetaDataList()
        XCTAssertFalse(modelData.authorizationMetaDataList.isEmpty, "Authorization Meta Data List should not be empty after loading.")
    }

    func testLoadIssuerMetaDataList() {
        modelData.loadIssuerMetaDataList()
        XCTAssertFalse(modelData.issuerMetaDataList.isEmpty, "Issuer Meta Data List should not be empty after loading.")
    }

    func testLoadClientInfoList() {
        modelData.loadClientInfoList()
        XCTAssertFalse(modelData.clientInfoList.isEmpty, "Client Info List should not be empty after loading.")
    }

    func testLoadPresentationDefinitions() {
        modelData.loadPresentationDefinitions()
        XCTAssertFalse(modelData.presentationDefinitions.isEmpty, "Presentation Definitions should not be empty after loading.")
    }
}
