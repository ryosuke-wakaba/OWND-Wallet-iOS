//
//  CredentialDetailViewModel.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2023/12/27.
//

import Foundation

@Observable
class CredentialDetailViewModel {
    var requiredClaims: [DisclosureWithOptionality] = []
    var optionalClaims: [DisclosureWithOptionality] = []
    var undisclosedClaims: [DisclosureWithOptionality] = []

    var dataModel: CredentialDetailModel = .init()
    var inputDescriptor: InputDescriptor? = nil

    func loadData(credential: Credential) async {
        await loadData(credential: credential, presentationDefinition: nil)
    }

    func loadData(credential: Credential, presentationDefinition: PresentationDefinition? = nil)
        async
    {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            print("now previewing")
            return
        }
        guard !dataModel.hasLoadedData else { return }
        dataModel.isLoading = true
        print("load data..")
        dataModel.isLoading = false
        if let pd = presentationDefinition {
            switch credential.format {
                case "vc+sd-jwt":
                    if let selected = selectDisclosure(
                        sdJwt: credential.payload, presentationDefinition: pd)
                    {
                        let (inputDescriptors, disclosuresWithOptionality) = selected
                        self.inputDescriptor = inputDescriptors

                        self.requiredClaims = disclosuresWithOptionality.filter { d in
                            d.isSubmit && !d.optional
                        }
                        self.optionalClaims = disclosuresWithOptionality.filter { d in
                            !d.isSubmit && d.optional
                        }
                        self.undisclosedClaims = disclosuresWithOptionality.filter { d in
                            !d.isSubmit && !d.optional
                        }
                    }
                case "jwt_vc_json":
                    inputDescriptor = pd.inputDescriptors[0]  // 選択開示できないので先頭固定
                    self.undisclosedClaims = []

                    let jwt = credential.payload
                    self.requiredClaims = JWTUtil.convertJWTClaimsAsDisclosure(jwt: jwt).map { it in
                        return DisclosureWithOptionality(
                            disclosure: it, isSubmit: true, optional: false)
                    }
                default:
                    inputDescriptor = pd.inputDescriptors[0]  // 選択開示できないので先頭固定
            }
        }
        dataModel.hasLoadedData = true
        print("done")
    }

    func createSubmissionCredential(
        credential: Credential,
        discloseClaims: [DisclosureWithOptionality]
    )
        -> SubmissionCredential
    {
        let types = try! VCIMetadataUtil.extractTypes(
            format: credential.format, credential: credential.payload)
        let submissionCredential = SubmissionCredential(
            id: credential.id,
            format: credential.format,
            types: types,
            credential: credential.payload,
            inputDescriptor: self.inputDescriptor!,
            discloseClaims: discloseClaims
        )
        return submissionCredential
    }
}
