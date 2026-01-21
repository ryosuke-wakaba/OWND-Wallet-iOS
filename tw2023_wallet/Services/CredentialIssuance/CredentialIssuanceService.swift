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
        txCode: String?,
        useDPoP: Bool = true,
        useClientAttestation: Bool = false
    ) async throws {
        print("[Issuance] ================================================")
        print("[Issuance] Starting Credential Issuance Flow")
        print("[Issuance] ================================================")
        print("[Issuance] Credential Issuer: \(credentialOffer.credentialIssuer)")
        print("[Issuance] Credential Configuration ID: \(credentialConfigurationId)")
        print("[Issuance] DPoP Enabled: \(useDPoP)")
        print("[Issuance] Client Attestation Enabled: \(useClientAttestation)")
        print("[Issuance] TX Code Provided: \(txCode != nil)")

        // Initialize VCI Client
        print("[Issuance] Initializing VCI Client...")
        let vciClient = try await VCIClient(credentialOffer: credentialOffer, metaData: metadata)
        print("[Issuance] VCI Client initialized")
        print("[Issuance] Token Endpoint: \(vciClient.getTokenEndpoint())")
        print("[Issuance] Credential Endpoint: \(vciClient.getCredentialEndpoint())")

        // Step 1: Issue token (with optional DPoP and Client Attestation)
        print("[Issuance] ---- Step 1: Token Issuance ----")
        let tokenResult = try await tokenService.issueToken(
            vciClient: vciClient,
            txCode: txCode,
            useDPoP: useDPoP,
            useClientAttestation: useClientAttestation
        )
        print("[Issuance] Token issued successfully")
        print("[Issuance] Token Type: \(tokenResult.tokenType)")

        // Step 2: Fetch nonce (returns both c_nonce and DPoP-Nonce)
        print("[Issuance] ---- Step 2: Nonce Fetch ----")
        let nonceResult = try await tokenService.fetchNonce(vciClient: vciClient)
        print("[Issuance] c_nonce received: \(nonceResult.cNonce)")
        if let dpopNonce = nonceResult.dpopNonce {
            print("[Issuance] DPoP-Nonce received: \(dpopNonce)")
        } else {
            print("[Issuance] DPoP-Nonce: Not provided")
        }

        // Step 3: Get credential configuration
        print("[Issuance] ---- Step 3: Credential Configuration ----")
        guard let credentialConfig = metadata.credentialIssuerMetadata.credentialConfigurationsSupported[credentialConfigurationId] else {
            print("[Issuance] ERROR: Credential configuration not found")
            throw CredentialIssuanceError.loadDataDidNotFinishSuccessfully
        }
        print("[Issuance] Credential format: \(credentialConfig.format)")

        // Step 4: Generate proof (using c_nonce for key binding)
        print("[Issuance] ---- Step 4: Proof Generation ----")
        let proofs = try proofService.generateProof(
            credentialConfig: credentialConfig,
            credentialIssuer: credentialOffer.credentialIssuer,
            nonce: nonceResult.cNonce
        )
        print("[Issuance] Proof generated successfully")

        // Step 5: Request credential (with optional DPoP using DPoP-Nonce)
        print("[Issuance] ---- Step 5: Credential Request ----")
        if useDPoP {
            print("[Issuance] Using DPoP for credential request")
            if let dpopNonce = nonceResult.dpopNonce {
                print("[Issuance] Including DPoP-Nonce in proof: \(dpopNonce)")
            }
        }
        let credentialResponse = try await requestService.requestCredential(
            vciClient: vciClient,
            credentialConfigurationId: credentialConfigurationId,
            proofs: proofs,
            accessToken: tokenResult.accessToken,
            dpopNonce: nonceResult.dpopNonce,
            useDPoP: useDPoP
        )
        print("[Issuance] Credential response received")

        // Step 6: Save credential
        print("[Issuance] ---- Step 6: Credential Storage ----")
        try storageService.saveCredential(
            credentialResponse: credentialResponse,
            accessToken: tokenResult.accessToken,
            metadata: metadata,
            credentialConfigurationId: credentialConfigurationId
        )
        print("[Issuance] Credential saved successfully")
        print("[Issuance] ================================================")
        print("[Issuance] Credential Issuance Flow Completed Successfully")
        print("[Issuance] ================================================")
    }
}
