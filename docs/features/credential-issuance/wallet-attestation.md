# Credential Issuance - Wallet Attestation (Client Authentication)

## Overview

OAuth 2.0 Attestation-Based Client Authentication を使用して、Walletの信頼性を証明します。Wallet ProviderがWalletに対して発行したAttestationをAuthorization Serverに提示することで、クライアント認証を行います。

## Wallet Attestation Integration Flow

```
1. Settings (事前準備)
   User enables "Client Authentication"
   → WalletAttestationService.generateAndStoreClientAttestation()
   → Client Attestation JWT stored locally

2. Token Endpoint
   Request Headers:
     OAuth-Client-Attestation: <client_attestation_jwt>
     OAuth-Client-Attestation-PoP: <client_attestation_pop_jwt>
     DPoP: <dpop_proof_jwt> (optional)
   Response: access_token
```

## JWT Structures

### Client Attestation JWT

Wallet Providerが署名するJWT。Walletの公開鍵を含み、Walletの信頼性を証明します。

```json
{
  "header": {
    "typ": "oauth-client-attestation+jwt",
    "alg": "ES256",
    "x5c": ["<base64-leaf-cert>", "<base64-intermediate-cert>", "..."]
  },
  "payload": {
    "iss": "https://wallet-provider.ownd-project.com",
    "sub": "https://wallet.ownd-project.com",
    "nbf": 1234567890,
    "exp": 1234571490,
    "cnf": {
      "jwk": { "kty": "EC", "crv": "P-256", "x": "...", "y": "..." }
    },
    "wallet_name": "OWND Wallet",
    "wallet_link": "https://www.ownd-project.com/wallet/"
  }
}
```

#### Client Attestation Payload Fields

| Field | Description |
|-------|-------------|
| `iss` | Wallet Provider識別子 |
| `sub` | Client ID（Wallet識別子） |
| `nbf` | 有効開始時刻 |
| `exp` | 有効期限 |
| `cnf.jwk` | Walletの公開鍵（PoP署名検証用） |
| `wallet_name` | Wallet名称 |
| `wallet_link` | Wallet情報URL |

### Client Attestation PoP JWT

Walletが署名するJWT。Client Attestationの`cnf.jwk`に対応する秘密鍵で署名し、Attestationの所有を証明します。

```json
{
  "header": {
    "typ": "oauth-client-attestation-pop+jwt",
    "alg": "ES256"
  },
  "payload": {
    "iss": "https://wallet.ownd-project.com",
    "aud": "https://issuer.example.com",
    "jti": "<unique-id>",
    "iat": 1234567890
  }
}
```

#### Client Attestation PoP Payload Fields

| Field | Description |
|-------|-------------|
| `iss` | Client ID（Wallet識別子） |
| `aud` | Authorization ServerのIssuer URL |
| `jti` | 一意のJWT ID（リプレイ防止） |
| `iat` | 発行時刻 |

## Wallet Attestation Service API

```swift
// tw2023_wallet/Services/WalletAttestation/WalletAttestationService.swift
class WalletAttestationService {
    static let shared: WalletAttestationService

    /// Client Attestationが有効かチェック
    func isAttestationEnabled() -> Bool

    /// Client Attestation JWTを生成・保存（設定有効化時に呼び出し）
    func generateAndStoreClientAttestation() async throws

    /// 保存済みClient Attestation JWTを取得（期限切れの場合は再生成）
    func getClientAttestation() throws -> String

    /// Client Attestation PoP JWTを生成
    /// - Parameter audience: Authorization ServerのIssuer URL
    func generateClientAttestationPoP(audience: String) throws -> String
}
```

## Security Benefits

Wallet Attestation (OAuth 2.0 Attestation-Based Client Authentication) は以下のセキュリティ強化を提供:

### 1. Wallet Trust

- Wallet Providerによる署名でWalletの信頼性を証明
- 不正なクライアントからのリクエストを拒否可能

### 2. Proof of Possession

- Client Attestation PoP JWTによる鍵所有証明
- Attestationの盗用・悪用を防止

### 3. Certificate Chain Validation

- x5cヘッダーによる証明書チェーン検証
- Wallet Providerの正当性を検証可能

### 4. HAIP Compliance

- OID4VCI High Assurance Interoperability Profile (4.4.1) 準拠
- 高セキュリティ環境での相互運用性

## Implementation Notes

- Wallet Provider秘密鍵・証明書はビルド時にバンドル（テスト用）
- Attestation鍵ペアはKeychain/Secure Enclaveに保存
- Client Attestationは有効期限管理あり（デフォルト1時間）
- 期限切れ時は自動再生成

## Configuration

| 設定 | 説明 | デフォルト |
|------|------|-----------|
| `use_client_attestation` | Client Attestationを使用 | OFF |

## HTTP Headers

Token Endpointへのリクエスト時に以下のヘッダーを付与:

| Header | Value |
|--------|-------|
| `OAuth-Client-Attestation` | Client Attestation JWT |
| `OAuth-Client-Attestation-PoP` | Client Attestation PoP JWT |

## References

- [OID4VCI Appendix E - Wallet Attestations](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#appendix-E)
- [OAuth 2.0 Attestation-Based Client Authentication](https://drafts.oauth.net/draft-ietf-oauth-attestation-based-client-auth/draft-ietf-oauth-attestation-based-client-auth.html)
- [HAIP 4.4.1 - Wallet Attestation](https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-1_0-05.html#name-wallet-attestation)
