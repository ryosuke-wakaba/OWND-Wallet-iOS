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
    var credentialQuery: DcqlCredentialQuery? = nil

    func loadData(credential: Credential) async {
        await loadData(credential: credential, dcqlQuery: nil)
    }

    func loadData(credential: Credential, dcqlQuery: DcqlQuery? = nil)
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
        if let query = dcqlQuery {
            switch credential.format {
                case "vc+sd-jwt", "dc+sd-jwt":  // OID4VCI 1.0: Support both formats
                    if let matched = query.firstMatchedCredentialQuery(
                        sdJwt: credential.payload)
                    {
                        self.credentialQuery = matched.credentialQuery
                        let disclosuresWithOptionality = matched.disclosuresWithOptionality

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
                    credentialQuery = query.credentials.first
                    self.undisclosedClaims = []
                    self.requiredClaims = jwtVcJsonClaimsTobeDisclosed(jwt: credential.payload).map
                    { it in
                        return DisclosureWithOptionality(
                            disclosure: it, isSubmit: true, isUserSelectable: false)
                    }
                default:
                    credentialQuery = query.credentials.first
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
            credentialQuery: self.credentialQuery!,
            discloseClaims: discloseClaims
        )
        return submissionCredential
    }
}
