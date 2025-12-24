//
//  TokenIssuanceService.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Default implementation of TokenIssuanceServiceProtocol
class TokenIssuanceService: TokenIssuanceServiceProtocol {

    func issueToken(vciClient: VCIClient, txCode: String?, useDPoP: Bool) async throws -> TokenIssuanceResult {
        let token = try await vciClient.issueToken(txCode: txCode, useDPoP: useDPoP)
        return TokenIssuanceResult(accessToken: token.accessToken, tokenType: token.tokenType)
    }

    func fetchNonce(vciClient: VCIClient) async throws -> NonceResult {
        let nonceResponse = try await vciClient.fetchNonce()
        return NonceResult(cNonce: nonceResponse.cNonce, dpopNonce: nonceResponse.dpopNonce)
    }
}
