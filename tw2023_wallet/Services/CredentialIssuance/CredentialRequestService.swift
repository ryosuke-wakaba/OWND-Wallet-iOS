//
//  CredentialRequestService.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Default implementation of CredentialRequestServiceProtocol
class CredentialRequestService: CredentialRequestServiceProtocol {

    func requestCredential(
        vciClient: VCIClient,
        credentialConfigurationId: String,
        proofs: Proofs?,
        accessToken: String
    ) async throws -> CredentialResponse {
        // Create credential request
        let credentialRequest = createCredentialRequest(
            credentialConfigurationId: credentialConfigurationId,
            proofs: proofs
        )

        // Issue credential
        let credentialResponse = try await vciClient.issueCredential(
            payload: credentialRequest,
            accessToken: accessToken
        )

        // Validate response
        if credentialResponse.credential == nil {
            if credentialResponse.transactionId == nil {
                throw CredentialIssuanceError.transactionIdIsRequired
            }
            // Deferred issuance not supported
            throw CredentialIssuanceError.deferredIssuanceIsNotSupported
        }

        return credentialResponse
    }
}
