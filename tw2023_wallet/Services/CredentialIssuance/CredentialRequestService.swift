//
//  CredentialRequestService.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Service responsible for requesting credentials
class CredentialRequestService {

    func requestCredential(
        vciClient: VCIClient,
        credentialConfigurationId: String,
        proofs: Proofs?,
        accessToken: String,
        dpopNonce: String?,
        useDPoP: Bool
    ) async throws -> CredentialResponse {
        print("[CredentialRequest] Requesting credential...")
        print("[CredentialRequest] Credential Endpoint: \(vciClient.getCredentialEndpoint())")
        print("[CredentialRequest] Credential Configuration ID: \(credentialConfigurationId)")
        print("[CredentialRequest] DPoP Enabled: \(useDPoP)")
        if let dpopNonce = dpopNonce {
            print("[CredentialRequest] DPoP-Nonce: \(dpopNonce)")
        } else {
            print("[CredentialRequest] DPoP-Nonce: Not provided")
        }

        // Create credential request
        let credentialRequest = createCredentialRequest(
            credentialConfigurationId: credentialConfigurationId,
            proofs: proofs
        )
        print("[CredentialRequest] Credential request created")
        if let proofs = proofs, let jwtProofs = proofs.jwt, !jwtProofs.isEmpty {
            print("[CredentialRequest] JWT Proofs count: \(jwtProofs.count)")
        }

        // Issue credential with optional DPoP
        print("[CredentialRequest] Sending credential request...")
        let credentialResponse = try await vciClient.issueCredential(
            payload: credentialRequest,
            accessToken: accessToken,
            dpopNonce: dpopNonce,
            useDPoP: useDPoP
        )
        print("[CredentialRequest] Credential response received")

        // Validate response
        if credentialResponse.credentialString == nil {
            if credentialResponse.transactionId == nil {
                print("[CredentialRequest] ERROR: No credential or transaction ID in response")
                throw CredentialIssuanceError.transactionIdIsRequired
            }
            // Deferred issuance not supported
            print("[CredentialRequest] Deferred issuance detected (transaction_id: \(credentialResponse.transactionId!))")
            throw CredentialIssuanceError.deferredIssuanceIsNotSupported
        }

        print("[CredentialRequest] Credential received successfully")
        return credentialResponse
    }
}
