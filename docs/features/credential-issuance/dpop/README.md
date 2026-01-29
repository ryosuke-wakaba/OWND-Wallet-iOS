# Credential Issuance - DPoP (RFC 9449)

## 概要

本ドキュメントは、OWND Wallet iOSにおけるDPoP (Demonstrating Proof of Possession) 機能について記載します。

DPoPは、アクセストークンを発行時のクライアントに暗号学的にバインドすることで、トークン漏洩時の悪用を防止するセキュリティ機構です。

## 参照仕様

本実装は以下の仕様に準拠しています。

### 1. RFC 9449: OAuth 2.0 Demonstrating Proof of Possession (DPoP)
- URL: https://www.rfc-editor.org/rfc/rfc9449.html
- DPoP Proof JWTの構造・生成方法を定義
- `ath` (Access Token Hash) によるトークンバインディング
- `DPoP-Nonce` によるリプレイ防止

### 2. OID4VCI 1.0 - Nonce Endpoint
- URL: https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html
- Nonce Endpointでの`DPoP-Nonce`ヘッダー取得
- Credential Endpoint呼び出し時のDPoP使用

### 3. HAIP 4.4.2 - DPoP
- URL: https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-1_0-05.html
- 高保証プロファイルでのDPoP要件
- Sender-Constrained Access Tokensの使用

## 全体フロー

```
+------+                +--------+                        +--------+
| User |                | Wallet |                        | Issuer |
+--+---+                +---+----+                        +----+---+
   |                        |                                  |
   |  [事前準備]             |                                  |
   |                        |                                  |
   |                        | DPoP用キーペア生成                |
   |                        | (Secure Enclave)                 |
   |                        +---+                              |
   |                        |   |                              |
   |                        |<--+                              |
   |                        |                                  |
   |  [Token Request]       |                                  |
   |                        |                                  |
   |                        | DPoP Proof生成                   |
   |                        | (htm=POST, htu=token_url)        |
   |                        +---+                              |
   |                        |   |                              |
   |                        |<--+                              |
   |                        |                                  |
   |                        | POST /token                      |
   |                        | DPoP: <dpop_proof_jwt>           |
   |                        +--------------------------------->|
   |                        |                                  |
   |                        |     access_token, token_type=DPoP|
   |                        |<---------------------------------+
   |                        |                                  |
   |  [Nonce Request]       |                                  |
   |                        |                                  |
   |                        | POST /nonce                      |
   |                        +--------------------------------->|
   |                        |                                  |
   |                        |     c_nonce, DPoP-Nonce (header) |
   |                        |<---------------------------------+
   |                        |                                  |
   |  [Credential Request]  |                                  |
   |                        |                                  |
   |                        | DPoP Proof生成                   |
   |                        | (htm=POST, htu=credential_url,   |
   |                        |  ath=hash(access_token),         |
   |                        |  nonce=dpop_nonce)               |
   |                        +---+                              |
   |                        |   |                              |
   |                        |<--+                              |
   |                        |                                  |
   |                        | POST /credential                 |
   |                        | Authorization: DPoP <access_token>
   |                        | DPoP: <dpop_proof_jwt>           |
   |                        +--------------------------------->|
   |                        |                                  |
   |                        |                       credential |
   |                        |<---------------------------------+
   |                        |                                  |
```

## DPoP Proof JWT

### JWT構造

#### Header

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

| フィールド | 値 | 仕様 |
|-----------|-----|------|
| `typ` | `dpop+jwt` | RFC 9449 Section 4.2 |
| `alg` | `ES256` | ECDSA P-256 with SHA-256 |
| `jwk` | 公開鍵（JWK形式） | RFC 9449 Section 4.2 |

#### Payload (Token Endpoint用)

```json
{
  "jti": "<UUID>",
  "htm": "POST",
  "htu": "https://issuer.example.com/token",
  "iat": 1234567890
}
```

#### Payload (Credential Endpoint用 - ath・nonce付き)

```json
{
  "jti": "<UUID>",
  "htm": "POST",
  "htu": "https://issuer.example.com/credential",
  "iat": 1234567890,
  "ath": "<base64url(sha256(access_token))>",
  "nonce": "<server-provided-dpop-nonce>"
}
```

### Payloadフィールド

| フィールド | 必須 | 説明 | 仕様 |
|-----------|------|------|------|
| `jti` | REQUIRED | 一意のJWT ID（リプレイ防止） | RFC 9449 Section 4.2 |
| `htm` | REQUIRED | HTTPメソッド（大文字） | RFC 9449 Section 4.2 |
| `htu` | REQUIRED | HTTPターゲットURI（クエリ・フラグメント除外） | RFC 9449 Section 4.2 |
| `iat` | REQUIRED | 発行時刻（UNIX timestamp） | RFC 9449 Section 4.2 |
| `ath` | CONDITIONAL | Access Token Hash（リソースサーバーリクエスト時） | RFC 9449 Section 4.2 |
| `nonce` | OPTIONAL | サーバー提供のDPoP-Nonce | RFC 9449 Section 4.2 |

### athの計算

Access Token Hash（`ath`）は以下の手順で計算します:

```
ath = Base64URL(SHA256(access_token))
```

1. アクセストークン文字列をASCIIエンコード
2. SHA-256ハッシュを計算
3. 結果をBase64URLエンコード（パディングなし）

## HTTPヘッダー

### リクエストヘッダー

| エンドポイント | ヘッダー | 値 |
|--------------|---------|-----|
| Token | `DPoP` | DPoP Proof JWT |
| Credential | `Authorization` | `DPoP <access_token>` |
| Credential | `DPoP` | DPoP Proof JWT (ath付き) |

### レスポンスヘッダー

| ヘッダー | 説明 |
|---------|------|
| `DPoP-Nonce` | 次回DPoP Proofで使用するnonce |

## 関連ドキュメント

- [実装詳細](implementation.md)
- [セキュリティ](security.md)
