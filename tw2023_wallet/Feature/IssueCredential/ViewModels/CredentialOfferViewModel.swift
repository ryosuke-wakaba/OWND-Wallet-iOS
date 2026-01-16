//
//  CredentialOfferViewModel.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/22.
//

import Foundation
import SwiftUI

/// User-facing errors for credential offer view
enum CredentialOfferViewError: LocalizedError {
    case serverAuthenticationFailed

    var errorDescription: String? {
        switch self {
        case .serverAuthenticationFailed:
            return NSLocalizedString("error_server_authentication_failed", comment: "")
        }
    }
}

class CredentialOfferViewModel: ObservableObject {
    var dataModel: CredentialOfferModel = .init()

    var credentialConfigurationId: String? = nil

    /// Error message to display in alert dialog
    @Published var errorMessage: String?

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

        // Delegate to service layer with DPoP setting from preferences
        let useDPoP = PreferencesDataStore.shared.getUseDPoP()
        try await issuanceService.issueCredential(
            credentialOffer: offer,
            metadata: metadata,
            credentialConfigurationId: configId,
            txCode: txCode,
            useDPoP: useDPoP
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

        do {
            let preferSignedMetadata = PreferencesDataStore.shared.getPreferSignedMetadata()

            // Load LoTE configuration for OID4VCI
            // Domain knowledge: jp-lote + oid4vci service type
            let loteSearchInfos = TrustedListConfigLoader.createSearchInfos([
                (loteName: "jp-lote", serviceName: "oid4vci")
            ])

            dataModel.metaData = try await retrieveAllMetadata(
                issuer: credentialOffer.credentialIssuer,
                preferSignedMetadata: preferSignedMetadata,
                loteSearchInfos: loteSearchInfos
            )
        } catch let error as MetadataError {
            // Convert signed metadata errors to user-facing error
            switch error {
            case .signedMetadataValidationFailed:
                print("Signed metadata validation failed: \(error)")
                throw CredentialOfferViewError.serverAuthenticationFailed
            case .contentTypeMismatch:
                print("Content-Type mismatch: \(error)")
                throw CredentialOfferViewError.serverAuthenticationFailed
            default:
                throw error
            }
        }

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
