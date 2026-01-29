# Credential Issuance - Wallet Attestation (Client Authentication)

## 概要

本ドキュメントは、OWND Wallet iOSにおけるWallet Attestation（クライアント認証）機能について記載します。

OAuth 2.0 Attestation-Based Client Authentication を使用して、Walletの信頼性を証明します。Wallet ProviderがWalletに対して発行したAttestationをAuthorization Serverに提示することで、クライアント認証を行います。

> **注意:** 本機能は「Wallet Attestation」と呼ばれますが、プロトコル仕様（OAuth 2.0 Attestation-Based Client Authentication）上でのJWTの名称は「Client Attestation」および「Client Attestation PoP」です。本ドキュメントでは、機能名として「Wallet Attestation」、JWT名として「Client Attestation」を使用します。

## 参照仕様

本実装は以下の仕様に準拠しています。

### 1. OID4VCI Appendix E - Wallet Attestations in JWT format
- URL: https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#appendix-E
- Wallet AttestationのJWT形式を定義
- `wallet_name`, `wallet_link`, `status` などのオプショナルクレームを定義

### 2. OAuth 2.0 Attestation-Based Client Authentication (draft-ietf-oauth-attestation-based-client-auth)
- URL: https://drafts.oauth.net/draft-ietf-oauth-attestation-based-client-auth/draft-ietf-oauth-attestation-based-client-auth.html
- Client Attestation JWT と Client Attestation PoP JWT の構造を定義
- HTTPヘッダーでの送信方法を定義

### 3. HAIP 4.4.1 - Wallet Attestation
- URL: https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-1_0-05.html#name-wallet-attestation
- x5cヘッダーに証明書チェーンを含める要件
- Wallet Attestationを異なるIssuer間で再利用しない要件
- `sub`クレームは全ウォレットインスタンスで共通の値を使用する要件

## 全体フロー

```
+------+                +--------+              +---------------+      +-------+
| User |                | Wallet |              | Pseudo        |      | AuthZ |
|      |                |        |              | Provider      |      | Server|
+--+---+                +---+----+              +-------+-------+      +---+---+
   |                        |                          |                   |
   |  [事前準備: ビルド時]    |                          |                   |
   |                        |  Provider秘密鍵・証明書    |                   |
   |                        |<-------------------------+                   |
   |                        |  (バンドルに組み込み)       |                   |
   |                        |                          |                   |
   |  [設定: クライアント認証を有効化]                    |                   |
   |                        |                          |                   |
   | トグルをON             |                          |                   |
   +----------------------->|                          |                   |
   |                        |                          |                   |
   |                        | Attestation用キーペア生成  |                   |
   |                        +------------------------->|                   |
   |                        |                          |                   |
   |                        | Client Attestation JWT   |                   |
   |                        |<-------------------------+                   |
   |                        | (Provider秘密鍵で署名)     |                   |
   |                        |                          |                   |
   |                        | JWTを保存                 |                   |
   |                        +---+                      |                   |
   |                        |   |                      |                   |
   |                        |<--+                      |                   |
   |                        |                          |                   |
   |  [クレデンシャル発行: Token Request]               |                   |
   |                        |                          |                   |
   |                        | Client Attestation PoP   |                   |
   |                        | JWT生成                   |                   |
   |                        +---+                      |                   |
   |                        |   |                      |                   |
   |                        |<--+                      |                   |
   |                        |                          |                   |
   |                        | POST /token              |                   |
   |                        | OAuth-Client-Attestation: <jwt>              |
   |                        | OAuth-Client-Attestation-PoP: <pop_jwt>      |
   |                        +------------------------------------------>   |
   |                        |                          |                   |
   |                        |              access_token|                   |
   |                        |<------------------------------------------+  |
   |                        |                          |                   |
```

## Client Attestation JWT

Wallet Providerが署名するJWT。Walletの公開鍵を含み、Walletの信頼性を証明します。

### Header

```json
{
  "typ": "oauth-client-attestation+jwt",
  "alg": "ES256",
  "x5c": ["<base64-leaf-cert>"]
}
```

| フィールド | 値 | 仕様 |
|-----------|-----|------|
| `typ` | `oauth-client-attestation+jwt` | OAuth Attestation-Based Client Auth 5.1 |
| `alg` | `ES256` | ECDSA P-256 with SHA-256 |
| `x5c` | 証明書チェーン（base64 DER） | HAIP 4.4.1 |

### Payload

```json
{
  "iss": "https://wallet-provider.ownd-project.com",
  "sub": "https://wallet.ownd-project.com",
  "nbf": 1234567890,
  "exp": 1234571490,
  "cnf": {
    "jwk": {
      "kty": "EC",
      "crv": "P-256",
      "x": "...",
      "y": "..."
    }
  },
  "wallet_name": "OWND Wallet",
  "wallet_link": "https://www.ownd-project.com/wallet/"
}
```

| フィールド | 必須 | 説明 | 仕様 |
|-----------|------|------|------|
| `iss` | REQUIRED | Wallet Provider識別子 | OAuth Attestation 5.1 |
| `sub` | REQUIRED | Client ID（全インスタンス共通） | OAuth Attestation 5.1, HAIP 4.4.1 |
| `nbf` | OPTIONAL | 有効開始時刻（UNIX timestamp） | OAuth Attestation 5.1 |
| `exp` | REQUIRED | 有効期限（UNIX timestamp） | OAuth Attestation 5.1 |
| `cnf` | REQUIRED | Wallet公開鍵（JWK形式） | OAuth Attestation 5.1 |
| `wallet_name` | OPTIONAL | Wallet名称 | OID4VCI Appendix E |
| `wallet_link` | OPTIONAL | Wallet情報URL | OID4VCI Appendix E |

## Client Attestation PoP JWT

Walletが署名するJWT。Client Attestationの`cnf.jwk`に対応する秘密鍵で署名し、Attestationの所有を証明します。

### Header

```json
{
  "typ": "oauth-client-attestation-pop+jwt",
  "alg": "ES256"
}
```

| フィールド | 値 | 仕様 |
|-----------|-----|------|
| `typ` | `oauth-client-attestation-pop+jwt` | OAuth Attestation-Based Client Auth 5.2 |
| `alg` | `ES256` | ECDSA P-256 with SHA-256 |

### Payload

```json
{
  "iss": "https://wallet.ownd-project.com",
  "aud": "https://issuer.example.com",
  "jti": "<UUID>",
  "iat": 1234567890
}
```

| フィールド | 必須 | 説明 | 仕様 |
|-----------|------|------|------|
| `iss` | REQUIRED | Client ID（= Client Attestationの`sub`） | OAuth Attestation 5.2 |
| `aud` | REQUIRED | Authorization ServerのIssuer URL | OAuth Attestation 5.2 |
| `jti` | REQUIRED | 一意のJWT ID（リプレイ防止） | OAuth Attestation 5.2 |
| `iat` | REQUIRED | 発行時刻（UNIX timestamp） | OAuth Attestation 5.2 |

## HTTPヘッダー

Token Endpointへのリクエスト時に以下のヘッダーを追加:

```http
POST /token HTTP/1.1
Host: issuer.example.com
Content-Type: application/x-www-form-urlencoded
OAuth-Client-Attestation: <client_attestation_jwt>
OAuth-Client-Attestation-PoP: <client_attestation_pop_jwt>
DPoP: <dpop_proof_jwt>  (optional)

grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code&...
```

| Header | Value |
|--------|-------|
| `OAuth-Client-Attestation` | Client Attestation JWT |
| `OAuth-Client-Attestation-PoP` | Client Attestation PoP JWT |

## 関連ドキュメント

- [実装詳細](implementation.md)
- [セキュリティ](security.md)
