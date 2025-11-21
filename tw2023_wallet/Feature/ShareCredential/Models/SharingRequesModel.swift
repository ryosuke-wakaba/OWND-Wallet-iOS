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
    var postResult: TokenSendResult? = nil
    var dcqlQuery: DcqlQuery? = nil
    init(dcqlQuery: DcqlQuery? = nil) {
        self.dcqlQuery = dcqlQuery
    }

    var type: String? = nil
    var data: [SubmissionCredential]? = nil
    var metadata: CredentialIssuerMetadata? = nil
    func setSelectedCredentials(
        data: [SubmissionCredential],
        metadata: CredentialIssuerMetadata
    ) {
        self.data = data
        self.metadata = metadata
    }
}
