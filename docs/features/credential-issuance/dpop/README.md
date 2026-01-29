# Credential Issuance - DPoP (RFC 9449)

## Overview

RFC 9449に基づくDPoP (Demonstrating Proof of Possession) を使用して、アクセストークンを送信者に紐付けます。

## DPoP Integration Flow

```
1. Token Endpoint
   Request:  DPoP: <dpop_proof_jwt>
   Response: access_token, token_type="DPoP"

2. Nonce Endpoint (OID4VCI 1.0)
   Request:  POST /nonce
   Response: c_nonce (body), DPoP-Nonce (header)

3. Credential Endpoint
   Request:  Authorization: DPoP <access_token>
             DPoP: <dpop_proof_jwt_with_ath_and_nonce>
   Response: credential
```

## DPoP Proof JWT Structure

```json
{
  "header": {
    "typ": "dpop+jwt",
    "alg": "ES256",
    "jwk": { "kty": "EC", "crv": "P-256", "x": "...", "y": "..." }
  },
  "payload": {
    "jti": "<unique-id>",
    "htm": "POST",
    "htu": "https://issuer.example.com/credential",
    "iat": 1234567890,
    "ath": "<base64url(sha256(access_token))>",
    "nonce": "<server-provided-dpop-nonce>"
  }
}
```

### Payload Fields

| Field | Description |
|-------|-------------|
| `jti` | 一意のJWT ID（リプレイ防止） |
| `htm` | HTTPメソッド（POST, GETなど） |
| `htu` | HTTPターゲットURI |
| `iat` | 発行時刻（Unix timestamp） |
| `ath` | Access Token Hash（リソースサーバーへのリクエスト時のみ） |
| `nonce` | サーバー提供のDPoP-Nonce（オプション） |

## DPoP Service API

```swift
// tw2023_wallet/Services/OID/VCI/DPoPService.swift
enum DPoPService {
    /// Token Endpoint用のDPoP Proof生成（athなし）
    static func createProof(
        httpMethod: String,
        httpUri: String,
        nonce: String? = nil
    ) throws -> String

    /// Resource Server用のDPoP Proof生成（ath付き）
    static func createProofWithAccessToken(
        httpMethod: String,
        httpUri: String,
        accessToken: String,
        nonce: String? = nil
    ) throws -> String

    /// Access Token Hash計算
    static func calculateAth(accessToken: String) throws -> String
}
```

## Security Benefits

DPoP (RFC 9449) は以下のセキュリティ強化を提供:

### 1. Sender-Constrained Access Tokens

- Access Tokenは発行時のクライアントにバインド
- 盗まれたトークンは攻撃者が使用不可

### 2. Proof of Possession

- 各リクエストでクライアントの秘密鍵による署名が必要
- トークン漏洩リスクの大幅な軽減

### 3. Replay Protection

- DPoP-Nonce によるリプレイ攻撃防止
- jti (JWT ID) によるProof再利用防止

### 4. HAIP Compliance

- OID4VCI High Assurance Interoperability Profile準拠
- 高セキュリティ環境での相互運用性

## Implementation Notes

- DPoP鍵はSecure Enclaveに保存
- 各リクエストで新しいDPoP Proofを生成
- サーバーからの`DPoP-Nonce`ヘッダーを適切に処理

## References

- [RFC 9449: OAuth 2.0 DPoP](https://www.rfc-editor.org/rfc/rfc9449.html)
- [HAIP (High Assurance Interoperability Profile)](https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-1_0-05.html)
