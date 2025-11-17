//
//  CredentialOfferViewModel.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/22.
//

import Foundation
import SwiftUI

class CredentialOfferViewModel: ObservableObject {
    var dataModel: CredentialOfferModel = .init()

    var credentialConfigurationId: String? = nil

    private let issuanceService: CredentialIssuanceServiceProtocol

    // Dependency injection with default implementation
    init(issuanceService: CredentialIssuanceServiceProtocol = CredentialIssuanceService()) {
        self.issuanceService = issuanceService
    }

    func sendRequest(txCode: String?) async throws {
        guard let offer = dataModel.credentialOffer,
            let metadata = dataModel.metaData,
            let configId = credentialConfigurationId
        else {
            throw CredentialIssuanceError.loadDataDidNotFinishSuccessfully
        }

        // Delegate to service layer
        try await issuanceService.issueCredential(
            credentialOffer: offer,
            metadata: metadata,
            credentialConfigurationId: configId,
            txCode: txCode
        )
    }

    func loadData(_ credentialOffer: CredentialOffer) async throws {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            print("now previewing")
            return
        }
        guard !dataModel.hasLoadedData else { return }

        dataModel.isLoading = true
        print("load data..")

        dataModel.credentialOffer = credentialOffer

        dataModel.metaData = try await retrieveAllMetadata(issuer: credentialOffer.credentialIssuer)

        try interpretMetadataAndCredentialOffer()

        dataModel.isLoading = false
        dataModel.hasLoadedData = true
        print("done")
    }

    private func interpretMetadataAndCredentialOffer() throws {
        guard let offer = dataModel.credentialOffer,
            let metadata = dataModel.metaData
        else {
            throw CredentialIssuanceError.loadDataDidNotFinishSuccessfully
        }

        let offerIds = offer.credentialConfigurationIds

        // OID4VCI 1.0: Use credential_configuration_id directly
        // todo: support multiple credential offer
        guard let firstOfferCredential = offerIds.first else {
            throw CredentialIssuanceError.credentialOfferConfigurationIsEmpty
        }

        dataModel.targetCredentialId = firstOfferCredential
        credentialConfigurationId = firstOfferCredential
    }
}
