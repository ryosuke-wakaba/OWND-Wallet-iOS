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

    private let credentialDataManager = CredentialDataManager(container: nil)

    func sendRequest(txCode: String?) async throws {
        guard let offer = dataModel.credentialOffer,
            let metadata = dataModel.metaData,
            let configId = credentialConfigurationId
        else {
            throw CredentialIssuanceError.loadDataDidNotFinishSuccessfully
        }

        let vciClient = try await VCIClient(credentialOffer: offer, metaData: metadata)

        // Step 1: Issue token
        let token = try await vciClient.issueToken(txCode: txCode)
        let accessToken = token.accessToken

        // Step 2: OID4VCI 1.0 - Fetch nonce from dedicated nonce endpoint
        let nonceResponse = try await vciClient.fetchNonce()
        let cNonce = nonceResponse.cNonce

        // binding key generation
        let isKeyPairExist = KeyPairUtil.isKeyPairExist(
            alias: Constants.Cryptography.KEY_BINDING)
        if !isKeyPairExist {
            try KeyPairUtil.generateSignVerifyKeyPair(alias: Constants.Cryptography.KEY_BINDING)
        }

        // Step 3: OID4VCI 1.0 - Generate proof based on proof_types_supported
        let credentialIssuer = offer.credentialIssuer

        // Get credential configuration from metadata
        guard let credentialConfig = metadata.credentialIssuerMetadata.credentialConfigurationsSupported[configId] else {
            throw CredentialIssuanceError.loadDataDidNotFinishSuccessfully
        }

        // Determine if proofs should be included based on proof_types_supported
        let proofsObject: Proofs?
        if let proofTypesSupported = credentialConfig.proofTypesSupported, !proofTypesSupported.isEmpty {
            // proof_types_supported exists and is not empty
            let supportedTypes = Array(proofTypesSupported.keys)
            guard let jwtProofType = proofTypesSupported["jwt"] else {
                throw CredentialIssuanceError.unsupportedProofType(supportedTypes: supportedTypes)
            }

            // Generate jwt proof with supported signing algorithms
            let proofJwt = try KeyPairUtil.createProofJwt(
                keyAlias: Constants.Cryptography.KEY_BINDING,
                audience: credentialIssuer,
                nonce: cNonce,
                proofSigningAlgValuesSupported: jwtProofType.proofSigningAlgValuesSupported)
            proofsObject = Proofs(jwt: [proofJwt], cwt: nil, ldpVp: nil)
        } else {
            // proof_types_supported is nil or empty - no proofs required
            proofsObject = nil
        }

        // OID4VCI 1.0: Credential Request Generation
        let credentialRequest = createCredentialRequest(
            credentialConfigurationId: configId, proofs: proofsObject)

        // Issue credential
        let credentialResponse = try await vciClient.issueCredential(
            payload: credentialRequest, accessToken: accessToken)

        if credentialResponse.credential == nil {
            if credentialResponse.transactionId == nil {
                throw CredentialIssuanceError.transactionIdIsRequired
            }

            // todo: implement deferred issuance
            throw CredentialIssuanceError.deferredIssuanceIsNotSupported
        }
        else {
            // save credential
            let protoBuf = try convertToProtoBuf(
                accessToken: accessToken, credentialResponse: credentialResponse)
            try credentialDataManager.saveCredentialData(credentialData: protoBuf)
        }
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

    private func convertToProtoBuf(accessToken: String, credentialResponse: CredentialResponse)
        throws -> Datastore_CredentialData
    {
        guard let credentialToSave = credentialResponse.credential else {
            throw CredentialIssuanceError.credentialToBeConvertedDoesNotExist
        }

        // OID4VCI 1.0: Determine format from metadata
        guard let configId = credentialConfigurationId,
            let metadata = dataModel.metaData,
            let config = metadata.credentialIssuerMetadata.credentialConfigurationsSupported[configId]
        else {
            throw CredentialIssuanceError.loadDataDidNotFinishSuccessfully
        }

        let format = config.format
        let credentialFormat = CredentialFormat(formatString: format)
        let basicInfo: [String: Any] =
            credentialFormat?.isSDJWT == true
            ? JWTParsingUtil.extractSDJwtInfo(credential: credentialToSave, format: format)
            : JWTParsingUtil.extractInfoFromJwt(jwt: credentialToSave, format: format)

        let encoder = JSONEncoder()

        do {
            let encodedMetadata = try encoder.encode(
                self.dataModel.metaData?.credentialIssuerMetadata)
            let jsonString = String(data: encodedMetadata, encoding: .utf8)
            let expiresIn =
                credentialResponse.cNonceExpiresIn == nil
                ? Int32(0) : Int32(credentialResponse.cNonceExpiresIn!)
            var credentialData = Datastore_CredentialData()
            credentialData.id = UUID().uuidString

            credentialData.format = format
            credentialData.credential = credentialToSave
            credentialData.iss = basicInfo["iss"] as! String
            credentialData.iat = basicInfo["iat"] as! Int64
            credentialData.exp = basicInfo["exp"] as! Int64
            credentialData.type = basicInfo["typeOrVct"] as! String
            credentialData.cNonce = credentialResponse.cNonce ?? ""
            credentialData.cNonceExpiresIn = expiresIn
            credentialData.accessToken = accessToken
            credentialData.credentialIssuerMetadata = jsonString!

            return credentialData

        }
        catch {
            throw CredentialIssuanceError.failedToConvertToInternalFormat
        }
    }

}
