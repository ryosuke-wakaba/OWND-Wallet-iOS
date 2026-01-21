//
//  Constants.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2024/01/15.
//

import Foundation

struct Constants {
    struct Cryptography {
        static let KEY_BINDING = "bindingKey"
        static let KEY_PAIR_ALIAS_FOR_KEY_JWT_VP_JSON = "jwtVpJsonKey"
        static let KEY_DPOP = "dpopKey"
        static let KEY_WALLET_ATTESTATION = "walletAttestationKey"
    }

    struct WalletAttestation {
        // Wallet Provider identifier (issuer of Client Attestation)
        static let PROVIDER_ISSUER = "https://wallet-provider.ownd-project.com"
        // Client ID (subject of Client Attestation, shared across all wallet instances)
        static let CLIENT_ID = "https://wallet.ownd-project.com"
        // Wallet name for attestation
        static let WALLET_NAME = "OWND Wallet"
        // Wallet info link
        static let WALLET_LINK = "https://www.ownd-project.com/wallet/"
        // Attestation validity duration in seconds (1 hour)
        static let ATTESTATION_VALIDITY_SECONDS: TimeInterval = 3600
    }
}
