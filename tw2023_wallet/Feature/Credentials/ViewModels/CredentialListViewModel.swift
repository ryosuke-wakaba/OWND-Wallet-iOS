//
//  CredentialListViewModel.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/22.
//

import Foundation

class CredentialListViewModel {
    var dataModel: CredentialListModel = .init()

    private let credentialDataManager = CredentialDataManager(container: nil)

    func loadData() {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            print("now previewing")
            return
        }
        guard !dataModel.hasLoadedData else { return }
        dataModel.isLoading = true
        print("load data..")

        var credentialList: [Credential] = []
        for rawCredential in credentialDataManager.getAllCredentials() {
            if let converted = rawCredential.toCredential() {
                credentialList.append(converted)
            } else {
                print("Malformed Credential Found")
            }
        }

        dataModel.credentials = credentialList
        dataModel.isLoading = false
        dataModel.hasLoadedData = true
        print("done")
    }

    func deleteCredential(credential: Credential) {
        print("delete: \(credential.id), \(credential.format)")
        credentialDataManager.deleteCredentialById(id: credential.id)
        dataModel.hasLoadedData = false
        loadData()
    }
}
