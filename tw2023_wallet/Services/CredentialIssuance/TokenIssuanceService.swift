//
//  TokenIssuanceService.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Default implementation of TokenIssuanceServiceProtocol
class TokenIssuanceService: TokenIssuanceServiceProtocol {

    func issueToken(vciClient: VCIClient, txCode: String?) async throws -> String {
        let token = try await vciClient.issueToken(txCode: txCode)
        return token.accessToken
    }

    func fetchNonce(vciClient: VCIClient) async throws -> String {
        let nonceResponse = try await vciClient.fetchNonce()
        return nonceResponse.cNonce
    }
}
