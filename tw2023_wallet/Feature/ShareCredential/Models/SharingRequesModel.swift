//
//  SharingRequesModel.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2024/01/10.
//

import Foundation

@Observable
class SharingRequestModel {
    var redirectTo: String? = nil
    var postResult: PostResult? = nil
    var presentationDefinition: PresentationDefinition? = nil
    init(presentationDefinition: PresentationDefinition? = nil) {
        self.presentationDefinition = presentationDefinition
    }

    var type: String? = nil
    var data: SubmissionCredential? = nil
    var metadata: CredentialIssuerMetadata? = nil
    var submissionClaims: [DisclosureWithOptionality]? = nil
    func setSelectedCredential(
        data: SubmissionCredential, submissionClaims: [DisclosureWithOptionality],
        metadata: CredentialIssuerMetadata
    ) {
        self.data = data
        self.submissionClaims = submissionClaims
        self.metadata = metadata
    }
}
