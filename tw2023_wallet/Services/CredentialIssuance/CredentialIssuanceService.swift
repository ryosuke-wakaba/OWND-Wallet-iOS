//
//  CredentialIssuanceService.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Facade service that orchestrates the complete credential issuance flow
class CredentialIssuanceService: CredentialIssuanceServiceProtocol {

    private let tokenService: TokenIssuanceServiceProtocol
    private let proofService: ProofGenerationServiceProtocol
    private let requestService: CredentialRequestServiceProtocol
    private let storageService: CredentialStorageServiceProtocol

    init(
        tokenService: TokenIssuanceServiceProtocol = TokenIssuanceService(),
        proofService: ProofGenerationServiceProtocol = ProofGenerationService(),
        requestService: CredentialRequestServiceProtocol = CredentialRequestService(),
        storageService: CredentialStorageServiceProtocol = CredentialStorageService()
    ) {
        self.tokenService = tokenService
        self.proofService = proofService
        self.requestService = requestService
        self.storageService = storageService
    }

    func issueCredential(
        credentialOffer: CredentialOffer,
        metadata: Metadata,
        credentialConfigurationId: String,
        txCode: String?
    ) async throws {
        // Initialize VCI Client
        let vciClient = try await VCIClient(credentialOffer: credentialOffer, metaData: metadata)

        // Step 1: Issue token
        let accessToken = try await tokenService.issueToken(vciClient: vciClient, txCode: txCode)

        // Step 2: Fetch nonce
        let nonce = try await tokenService.fetchNonce(vciClient: vciClient)

        // Step 3: Get credential configuration
        guard let credentialConfig = metadata.credentialIssuerMetadata.credentialConfigurationsSupported[credentialConfigurationId] else {
            throw CredentialIssuanceError.loadDataDidNotFinishSuccessfully
        }

        // Step 4: Generate proof
        let proofs = try proofService.generateProof(
            credentialConfig: credentialConfig,
            credentialIssuer: credentialOffer.credentialIssuer,
            nonce: nonce
        )

        // Step 5: Request credential
        let credentialResponse = try await requestService.requestCredential(
            vciClient: vciClient,
            credentialConfigurationId: credentialConfigurationId,
            proofs: proofs,
            accessToken: accessToken
        )

        // Step 6: Save credential
        try storageService.saveCredential(
            credentialResponse: credentialResponse,
            accessToken: accessToken,
            metadata: metadata,
            credentialConfigurationId: credentialConfigurationId
        )
    }
}
