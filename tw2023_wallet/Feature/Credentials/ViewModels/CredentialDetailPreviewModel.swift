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
        credential: Credential, presentationDefinition: PresentationDefinition? = nil
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
        credential: Credential, presentationDefinition: PresentationDefinition? = nil
    ) async {
        // mock data for preview
        dataModel.isLoading = true
        print("load dummy data..")
        requiredClaims = [
            DisclosureWithOptionality(
                disclosure: Disclosure(disclosure: "1", key: "last_name", value: "value1"),
                isSubmit: true,
                optional: false),
            DisclosureWithOptionality(
                disclosure: Disclosure(disclosure: "2", key: "age", value: "value3"),
                isSubmit: true,
                optional: false),
        ]
        undisclosedClaims = [
            DisclosureWithOptionality(
                disclosure: Disclosure(disclosure: "3", key: "first_name", value: "value2"),
                isSubmit: false,
                optional: false)
        ]

        optionalClaims = [
            DisclosureWithOptionality(
                disclosure: Disclosure(disclosure: "4", key: "address", value: "value4"),
                isSubmit: false,
                optional: true),
            DisclosureWithOptionality(
                disclosure: Disclosure(disclosure: "5", key: "gender", value: "value4"),
                isSubmit: true,
                optional: true),

        ]

        print("done")
        dataModel.isLoading = false
    }

    func dummyPresentationDefinition1() -> PresentationDefinition {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationJsonData = presentationJson1.data(using: .utf8)
        let presentationDefinition = try! decoder.decode(
            PresentationDefinition.self, from: presentationJsonData!)
        return presentationDefinition
    }

    func dummyPresentationDefinition2() -> PresentationDefinition {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let presentationJsonData = presentationJson2.data(using: .utf8)
        let presentationDefinition = try! decoder.decode(
            PresentationDefinition.self, from: presentationJsonData!)
        return presentationDefinition
    }

    let presentationJson1 = """
          {
            "id": "12345",
            "inputDescriptors": [
              {
                "id": "input1",
                "name": "First Input",
                "purpose": "For identification",
                "format": {
                  "vc+sd-jwt": {}
                },
                "group": [
                  "A"
                ],
                "constraints": {
                  "limitDisclosure": "required",
                  "fields": [
                    {
                      "path": [
                        "$.is_older_than_13"
                      ],
                      "filter": {
                        "type": "boolean"
                      }
                    }
                  ]
                }
              }
            ],
            "submissionRequirements": [
              {
                "name": "Over13 Proof",
                "rule": "pick",
                "count": 1,
                "from": "A"
              }
            ]
          }
        """

    let presentationJson2 = """
          {
            "id": "12345",
            "inputDescriptors": [
              {
                "id": "input1",
                "name": "First Input",
                "purpose": "For identification",
                "format": {
                  "vc+sd-jwt": {}
                },
                "group": [
                  "A"
                ],
                "constraints": {
                  "limitDisclosure": "required",
                  "fields": [
                    {
                      "path": [
                        "$.is_older_than_13"
                      ],
                      "filter": {
                        "type": "boolean"
                      },
                      "optional": true
                    }
                  ]
                }
              }
            ],
            "submissionRequirements": [
              {
                "name": "Over13 Proof",
                "rule": "pick",
                "count": 1,
                "from": "A"
              }
            ]
          }
        """
}
