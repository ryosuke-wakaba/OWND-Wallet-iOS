//
//  CredentialDetailViewModel.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2023/12/27.
//

import Foundation

@Observable
class CredentialDetailViewModel {
    var dataModel: CredentialDetailModel = .init()

    func loadData(credential: Credential) async {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            print("now previewing")
            return
        }
        guard !dataModel.hasLoadedData else { return }
        dataModel.isLoading = true
        print("load data..")
        // Load sharing history for this credential
        let historyManager = CredentialSharingHistoryManager(container: nil)
        dataModel.sharingHistories = historyManager.findAllByCredentialId(credentialId: credential.id)
            .map { $0.toCredentialSharingHistory() }
        dataModel.isLoading = false
        dataModel.hasLoadedData = true
        print("done")
    }
}
