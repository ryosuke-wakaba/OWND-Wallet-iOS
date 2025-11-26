//
//  CredentialListPreviewModel.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/22.
//

import Foundation

class PreviewModel: CredentialListViewModel {
    override func loadData(dcqlQuery: DcqlQuery? = nil) {
        // mock data for preview (without bundle access)
        dataModel.isLoading = true
        print("load dummy data..")
        // Use PreviewSampleData to avoid bundle access issues in SwiftUI previews
        self.dataModel.credentials = [
            PreviewSampleData.sampleSdJwtCredentialWithImage(),
            PreviewSampleData.sampleSdJwtCredentialWithColor(),
            PreviewSampleData.sampleJwtVcJsonCredential()
        ]
        print("done")
        dataModel.isLoading = false
    }
}
