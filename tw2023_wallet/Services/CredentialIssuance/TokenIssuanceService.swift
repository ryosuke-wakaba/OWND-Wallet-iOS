//
//  TokenIssuanceService.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

// MARK: - Data Types

/// Result of token issuance including DPoP-related information
struct TokenIssuanceResult {
    let accessToken: String
    let tokenType: String
}

/// Result of nonce fetch including DPoP nonce
struct NonceResult {
    let cNonce: String
    let dpopNonce: String?
}

// MARK: - Service

/// Service responsible for issuing OAuth tokens
class TokenIssuanceService {

    func issueToken(vciClient: VCIClient, txCode: String?, useDPoP: Bool, useClientAttestation: Bool) async throws -> TokenIssuanceResult {
        print("[TokenService] Issuing token...")
        print("[TokenService] Token Endpoint: \(vciClient.getTokenEndpoint())")
        print("[TokenService] DPoP Enabled: \(useDPoP)")
        print("[TokenService] Client Attestation Enabled: \(useClientAttestation)")
        print("[TokenService] TX Code Provided: \(txCode != nil)")

        let token = try await vciClient.issueToken(
            txCode: txCode,
            useDPoP: useDPoP,
            useClientAttestation: useClientAttestation
        )

        print("[TokenService] Token issued successfully")
        print("[TokenService] Token Type: \(token.tokenType)")
        print("[TokenService] Expires In: \(token.expiresIn) seconds")

        return TokenIssuanceResult(accessToken: token.accessToken, tokenType: token.tokenType)
    }

    func fetchNonce(vciClient: VCIClient) async throws -> NonceResult {
        print("[TokenService] Fetching nonce...")

        let nonceResponse = try await vciClient.fetchNonce()

        print("[TokenService] Nonce fetched successfully")
        print("[TokenService] c_nonce: \(nonceResponse.cNonce)")
        if let dpopNonce = nonceResponse.dpopNonce {
            print("[TokenService] DPoP-Nonce: \(dpopNonce)")
        } else {
            print("[TokenService] DPoP-Nonce: Not present in response")
        }

        return NonceResult(cNonce: nonceResponse.cNonce, dpopNonce: nonceResponse.dpopNonce)
    }
}
