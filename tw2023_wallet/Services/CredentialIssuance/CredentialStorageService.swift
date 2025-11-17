//
//  CredentialStorageService.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Default implementation of CredentialStorageServiceProtocol
class CredentialStorageService: CredentialStorageServiceProtocol {

    private let credentialDataManager: CredentialDataManager

    init(credentialDataManager: CredentialDataManager = CredentialDataManager(container: nil)) {
        self.credentialDataManager = credentialDataManager
    }

    func saveCredential(
        credentialResponse: CredentialResponse,
        accessToken: String,
        metadata: Metadata,
        credentialConfigurationId: String
    ) throws {
        // Convert to ProtoBuf format
        let protoBuf = try convertToProtoBuf(
            credentialResponse: credentialResponse,
            accessToken: accessToken,
            metadata: metadata,
            credentialConfigurationId: credentialConfigurationId
        )

        // Save to datastore
        try credentialDataManager.saveCredentialData(credentialData: protoBuf)
    }

    // MARK: - Private Methods

    private func convertToProtoBuf(
        credentialResponse: CredentialResponse,
        accessToken: String,
        metadata: Metadata,
        credentialConfigurationId: String
    ) throws -> Datastore_CredentialData {
        guard let credentialToSave = credentialResponse.credential else {
            throw CredentialIssuanceError.credentialToBeConvertedDoesNotExist
        }

        // Get credential configuration from metadata
        guard let config = metadata.credentialIssuerMetadata.credentialConfigurationsSupported[credentialConfigurationId] else {
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
            let encodedMetadata = try encoder.encode(metadata.credentialIssuerMetadata)
            guard let jsonString = String(data: encodedMetadata, encoding: .utf8) else {
                throw CredentialIssuanceError.failedToConvertToInternalFormat
            }

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
            credentialData.credentialIssuerMetadata = jsonString

            return credentialData

        } catch {
            throw CredentialIssuanceError.failedToConvertToInternalFormat
        }
    }
}
