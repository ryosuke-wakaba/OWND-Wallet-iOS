# DPoP Implementation Work Document

## Status
- [x] 調査・設計
- [x] 実装
- [x] テスト
- [ ] レビュー

## Overview

RFC 9449に基づくDPoP (Demonstrating Proof of Possession) をOWND Wallet iOSに実装する。

### 目的
- アクセストークンの盗難対策（トークン単体では使用不可）
- OID4VCI High Assurance Interoperability Profile (HAIP) 準拠

## Implementation Plan

### Phase 1: DPoP Proof生成機能
- [x] DPoPService作成
- [x] DPoP JWT生成（ヘッダー・ペイロード構造）
- [x] athクレーム計算（Base64URL(SHA256(access_token))）
- [x] nonce対応

### Phase 2: VCIClient統合
- [x] Token Endpoint対応（DPoPヘッダー追加）
- [x] Nonce Endpoint対応（DPoP-Nonce取得）
- [x] Credential Endpoint対応（DPoPヘッダー + ath）

### Phase 3: 鍵管理
- [x] DPoP用鍵ペア生成・管理
- [x] 鍵の永続化（Secure Enclave使用）

### Phase 4: テスト
- [x] DPoP Proof生成のユニットテスト
- [x] ath計算検証テスト
- [x] VCIClient統合テスト

## Technical Design

### DPoP Proof JWT Structure

**Header:**
```json
{
  "typ": "dpop+jwt",
  "alg": "ES256",
  "jwk": {
    "kty": "EC",
    "crv": "P-256",
    "x": "...",
    "y": "..."
  }
}
```

**Payload (Token Endpoint):**
```json
{
  "jti": "<unique-id>",
  "htm": "POST",
  "htu": "https://issuer.example.com/token",
  "iat": 1234567890
}
```

**Payload (Resource Server with nonce):**
```json
{
  "jti": "<unique-id>",
  "htm": "POST",
  "htu": "https://issuer.example.com/credential",
  "iat": 1234567890,
  "ath": "<base64url(sha256(access_token))>",
  "nonce": "<server-provided-nonce>"
}
```

### Integration Flow

```
1. Token Endpoint
   Request:  DPoP: <jwt(htm=POST, htu=token_url)>
   Response: access_token, token_type="DPoP"

2. Nonce Endpoint
   Request:  POST /nonce
   Response: c_nonce, DPoP-Nonce header

3. Credential Endpoint
   Request:  Authorization: DPoP <access_token>
             DPoP: <jwt(htm=POST, htu=credential_url, ath=..., nonce=...)>
   Response: credential
```

### File Changes

| File | Change |
|------|--------|
| `tw2023_wallet/Services/OID/VCI/DPoPService.swift` | 新規: DPoP Proof生成サービス |
| `tw2023_wallet/Services/OID/VCI/VCIClient.swift` | 変更: DPoPヘッダー対応 |
| `tw2023_wallet/Services/CredentialIssuance/TokenIssuanceService.swift` | 変更: DPoP統合 |
| `tw2023_wallet/Services/CredentialIssuance/CredentialRequestService.swift` | 変更: DPoP統合 |
| `tw2023_wallet/Services/CredentialIssuance/CredentialIssuanceService.swift` | 変更: DPoPフロー統合 |
| `tw2023_wallet/Services/CredentialIssuance/CredentialIssuanceServiceProtocols.swift` | 変更: DPoP対応プロトコル |
| `tw2023_wallet/Feature/Constants.swift` | 変更: DPoP鍵定数追加 |
| `tw2023_wallet/Feature/IssueCredential/ViewModels/CredentialOfferViewModel.swift` | 変更: DPoP有効化 |
| `tw2023_walletTests/DPoPServiceTests.swift` | 新規: DPoPユニットテスト |

### Existing Infrastructure Leveraged

- `JWTUtil.sign()` - JWT署名
- `KeyPairUtil.generateSignVerifyKeyPair()` - 鍵ペア生成
- `KeyPairUtil.publicKeyToJwk()` - JWK変換

## Test Results

**DPoPServiceTests (9 tests - all passed):**
- testCalculateAthConsistency
- testCalculateAthProducesBase64UrlEncoding
- testCalculateAthWithKnownValue
- testCreateProofForTokenEndpoint
- testCreateProofWithAccessToken
- testCreateProofWithNonce
- testGetPublicKeyJwk
- testUniqueJtiGeneration
- testUriNormalization

**VCIClientTests (8 tests - all passed):**
- testFetchNonce
- testFullCredentialIssuanceFlow
- testIssueCredential
- testIssueToken
- testPostCredentialRequest
- testPostNonceRequest
- testPostNonceRequestWithDPoPNonce
- testPostTokenRequest

## Usage

DPoPはデフォルトで有効になっています。

```swift
// CredentialIssuanceServiceでDPoP使用
try await issuanceService.issueCredential(
    credentialOffer: offer,
    metadata: metadata,
    credentialConfigurationId: configId,
    txCode: txCode,
    useDPoP: true  // デフォルトtrue
)
```

DPoPを無効にする場合は `useDPoP: false` を指定してください。

## Progress Log

| Date | Progress |
|------|----------|
| 2025-12-24 | 調査完了、設計ドキュメント作成 |
| 2025-12-24 | DPoPService実装完了 |
| 2025-12-24 | VCIClient DPoP対応完了 |
| 2025-12-24 | サービス層統合完了 |
| 2025-12-24 | ユニットテスト作成・全テストパス |

## References

- [RFC 9449: OAuth 2.0 DPoP](https://www.rfc-editor.org/rfc/rfc9449.html)
- [OID4VCI 1.0](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
- [HAIP](https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-1_0-05.html)
- docs/work/dpop.md - DPoP仕様詳細
