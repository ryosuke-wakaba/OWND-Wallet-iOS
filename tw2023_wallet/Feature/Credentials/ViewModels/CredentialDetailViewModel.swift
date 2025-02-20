//
//  CredentialDetailViewModel.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2023/12/27.
//

import Foundation

func jwtVcJsonClaimsTobeDisclosed(jwt: String) -> [Disclosure] {
    if let (_, body, _) = try? JWTUtil.decodeJwt(jwt: jwt),
        let vc = body["vc"] as? [String: Any],
        let credentialSubject = vc["credentialSubject"] as? [String: Any]
    {
        let disclosures = credentialSubject.map { key, value in
            // valueがネストしていることは想定していない。
            return Disclosure(disclosure: nil, key: key, value: value as? String)
        }
        return disclosures
    }
    return []
}

@Observable
class CredentialDetailViewModel {
    var requiredClaims: [DisclosureWithOptionality] = []
    var userSelectableClaims: [DisclosureWithOptionality] = []
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
                    if let matched = pd.firstMatchedInputDescriptor(
                        sdJwt: credential.payload)
                    {
                        let (inputDescriptors, disclosuresWithOptionality) = matched
                        self.inputDescriptor = inputDescriptors

                        self.requiredClaims = disclosuresWithOptionality.filter { d in
                            d.isSubmit && !d.isUserSelectable
                        }
                        self.userSelectableClaims = disclosuresWithOptionality.filter { d in
                            d.isUserSelectable
                        }
                        self.undisclosedClaims = disclosuresWithOptionality.filter { d in
                            !d.isSubmit && !d.isUserSelectable
                        }
                    }
                case "jwt_vc_json":
                    inputDescriptor = pd.inputDescriptors[0]  // 選択開示できないので先頭固定
                    self.undisclosedClaims = []
                    self.requiredClaims = jwtVcJsonClaimsTobeDisclosed(jwt: credential.payload).map
                    { it in
                        return DisclosureWithOptionality(
                            disclosure: it, isSubmit: true, isUserSelectable: false)
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
