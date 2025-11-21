//
//  CredentialDetailPreviewModel.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2023/12/27.
//

import Foundation

class DetailPreviewModel: CredentialDetailViewModel {
    override func loadData(credential: Credential) async {
        // nop
    }
    override func loadData(
        credential: Credential, dcqlQuery: DcqlQuery? = nil
    ) async {
        // mock data for preview
        dataModel.isLoading = true
        print("load dummy data..")
        let modelData = ModelData()
        modelData.loadCredentialSharingHistories()
        self.dataModel.sharingHistories = modelData.credentialSharingHistories
        print("done")
        dataModel.isLoading = false
    }
}

class DetailVPModePreviewModel: CredentialDetailViewModel {
    override func loadData(credential: Credential) async {
        // nop
    }
    override func loadData(
        credential: Credential, dcqlQuery: DcqlQuery? = nil
    ) async {
        // mock data for preview
        dataModel.isLoading = true
        print("load dummy data..")
        requiredClaims = [
            DisclosureWithOptionality(
                disclosure: Disclosure(disclosure: "1", key: "last_name", value: "value1"),
                isSubmit: true,
                isUserSelectable: false),
            DisclosureWithOptionality(
                disclosure: Disclosure(disclosure: "2", key: "age", value: "value3"),
                isSubmit: true,
                isUserSelectable: false),
        ]
        undisclosedClaims = [
            DisclosureWithOptionality(
                disclosure: Disclosure(disclosure: "3", key: "first_name", value: "value2"),
                isSubmit: false,
                isUserSelectable: false)
        ]

        userSelectableClaims = [
            DisclosureWithOptionality(
                disclosure: Disclosure(disclosure: "4", key: "address", value: "value4"),
                isSubmit: false,
                isUserSelectable: true),
            DisclosureWithOptionality(
                disclosure: Disclosure(disclosure: "5", key: "gender", value: "value4"),
                isSubmit: true,
                isUserSelectable: true),

        ]

        print("done")
        dataModel.isLoading = false
    }

    func dummyDcqlQuery1() -> DcqlQuery {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dcqlQueryJsonData = dcqlQueryJson1.data(using: .utf8)
        let dcqlQuery = try! decoder.decode(
            DcqlQuery.self, from: dcqlQueryJsonData!)
        return dcqlQuery
    }

    func dummyDcqlQuery2() -> DcqlQuery {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dcqlQueryJsonData = dcqlQueryJson2.data(using: .utf8)
        let dcqlQuery = try! decoder.decode(
            DcqlQuery.self, from: dcqlQueryJsonData!)
        return dcqlQuery
    }

    let dcqlQueryJson1 = """
          {
            "credentials": [
              {
                "id": "age_verification",
                "format": "vc+sd-jwt",
                "meta": {
                  "vct_values": ["AgeVerificationCredential"]
                },
                "claims": [
                  {
                    "path": ["is_older_than_13"]
                  }
                ]
              }
            ]
          }
        """

    let dcqlQueryJson2 = """
          {
            "credentials": [
              {
                "id": "age_verification_optional",
                "format": "vc+sd-jwt",
                "claims": [
                  {
                    "path": ["is_older_than_13"]
                  }
                ]
              }
            ]
          }
        """
}
