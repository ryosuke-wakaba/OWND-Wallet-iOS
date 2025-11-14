//
//  CredentialIssuanceServiceProtocols.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

// MARK: - Token Issuance Service

/// Service responsible for issuing OAuth tokens
protocol TokenIssuanceServiceProtocol {
    /// Issue an access token for credential issuance
    /// - Parameters:
    ///   - vciClient: The VCI client
    ///   - txCode: Optional transaction code (PIN)
    /// - Returns: The access token string
    func issueToken(vciClient: VCIClient, txCode: String?) async throws -> String

    /// Fetch a fresh nonce for proof generation
    /// - Parameter vciClient: The VCI client
    /// - Returns: The nonce string
    func fetchNonce(vciClient: VCIClient) async throws -> String
}

// MARK: - Proof Generation Service

/// Service responsible for generating cryptographic proofs
protocol ProofGenerationServiceProtocol {
    /// Generate proof object for credential request
    /// - Parameters:
    ///   - credentialConfig: The credential configuration from metadata
    ///   - credentialIssuer: The credential issuer URL
    ///   - nonce: The nonce from the token response
    /// - Returns: Proofs object or nil if not required
    func generateProof(
        credentialConfig: CredentialConfiguration,
        credentialIssuer: String,
        nonce: String
    ) throws -> Proofs?
}

// MARK: - Credential Request Service

/// Service responsible for requesting credentials
protocol CredentialRequestServiceProtocol {
    /// Request a credential from the issuer
    /// - Parameters:
    ///   - vciClient: The VCI client
    ///   - credentialConfigurationId: The credential configuration ID
    ///   - proofs: Optional proofs object
    ///   - accessToken: The access token
    /// - Returns: The credential response
    func requestCredential(
        vciClient: VCIClient,
        credentialConfigurationId: String,
        proofs: Proofs?,
        accessToken: String
    ) async throws -> CredentialResponse
}

// MARK: - Credential Storage Service

/// Service responsible for storing credentials
protocol CredentialStorageServiceProtocol {
    /// Save a credential to storage
    /// - Parameters:
    ///   - credentialResponse: The credential response from the issuer
    ///   - accessToken: The access token
    ///   - metadata: The credential issuer metadata
    ///   - credentialConfigurationId: The credential configuration ID
    func saveCredential(
        credentialResponse: CredentialResponse,
        accessToken: String,
        metadata: Metadata,
        credentialConfigurationId: String
    ) throws
}

// MARK: - Credential Issuance Service (Facade)

/// Facade service that orchestrates the entire credential issuance flow
protocol CredentialIssuanceServiceProtocol {
    /// Execute the complete credential issuance flow
    /// - Parameters:
    ///   - credentialOffer: The credential offer
    ///   - metadata: The credential issuer metadata
    ///   - credentialConfigurationId: The credential configuration ID
    ///   - txCode: Optional transaction code (PIN)
    func issueCredential(
        credentialOffer: CredentialOffer,
        metadata: Metadata,
        credentialConfigurationId: String,
        txCode: String?
    ) async throws
}
