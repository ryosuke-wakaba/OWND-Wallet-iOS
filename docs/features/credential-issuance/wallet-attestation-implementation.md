# Wallet Attestation 実装詳細ドキュメント

## 概要

本ドキュメントは、OWND Wallet iOSにおけるWallet Attestation（クライアント認証）機能の実装詳細について記載します。

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

## Wallet Attestation

### 擬似ウォレットプロバイダー実装

本来、Wallet ProviderはWalletとは独立した外部サービスとして存在し、モバイルOSのDeviceCheck（iOS）やPlay Integrity（Android）を使用してWalletの信頼性を検証した上でAttestationを発行します。

本実装では、テスト・開発目的で擬似的にWallet Provider機能をウォレット内部に組み込んでいます。

### Wallet Attestation生成の操作

1. **設定画面でトグルをON**: ユーザーが設定画面で「クライアント認証」トグルを有効化
2. **自動生成処理**: Attestation用キーペア（ES256）を生成し、Client Attestation JWTを生成・保存
3. **クレデンシャル発行時の使用**: Token Request時に自動的にヘッダーを追加（期限切れの場合は自動再生成）

### プロバイダーのキーペア情報

#### Provider秘密鍵

| 項目 | 値 |
|------|-----|
| ファイルパス | `WalletProviderCert/wallet-provider-private.key` |
| ビルド後パス | `<app-bundle>/wallet-provider-private.key` |
| フォーマット | PEM (SEC1 EC PRIVATE KEY) |
| アルゴリズム | ECDSA P-256 (secp256r1) |

#### Provider証明書

| 項目 | 値 |
|------|-----|
| ファイルパス | `WalletProviderCert/wallet-provider.cer` |
| ビルド後パス | `<app-bundle>/wallet-provider.cer` |
| フォーマット | PEM (X.509 Certificate) |
| アルゴリズム | ECDSA P-256 with SHA-256 |
| 発行者 | CN=Test Root CA, O=Cyber Security Cloud, L=Sinagawa, ST=Tokyo, C=JP |
| サブジェクト | CN=OWND Project, O=Cyber Security Cloud, L=Sinagawa, ST=Tokyo, C=JP |
| 有効期間 | 2026-01-23 〜 2028-04-27 |

#### Attestation定数

| 定数 | 値 | 説明 |
|------|-----|------|
| `PROVIDER_ISSUER` | `https://wallet-provider.ownd-project.com` | Client Attestationの`iss`クレーム |
| `CLIENT_ID` | `https://wallet.ownd-project.com` | Client Attestationの`sub`クレーム、PoP JWTの`iss`クレーム |
| `WALLET_NAME` | `OWND Wallet` | Wallet名称（オプショナル） |
| `WALLET_LINK` | `https://www.ownd-project.com/wallet/` | Wallet情報URL（オプショナル） |
| `ATTESTATION_VALIDITY_SECONDS` | `86400` (24時間) | Client Attestationの有効期間 |
| `KEY_WALLET_ATTESTATION` | `walletAttestationKey` | Attestation用キーペアのエイリアス |

### Client Attestation JWT構造

#### Header
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

#### Payload
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

## Wallet Attestation PoP

### Client Attestation PoP JWT構造

#### Header
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

#### Payload
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

## HTTPヘッダー送信

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

## Authorization Server側での検証手順

#### 1. Client Attestation JWTの検証

- `typ`が`oauth-client-attestation+jwt`であること
- `x5c`ヘッダーから証明書チェーンを取得
- Trust Anchorに対して証明書チェーンを検証
- Leaf証明書から公開鍵を抽出
- JWTの署名を検証
- `exp`が未来であることを確認
- `nbf`が過去であることを確認（存在する場合）

#### 2. Client Attestation PoP JWTの検証

- `typ`が`oauth-client-attestation-pop+jwt`であること
- `iss`がClient Attestationの`sub`と一致すること
- `aud`が認可サーバーのIssuer URLと一致すること
- `jti`がユニークであること（リプレイ検出）※本実装では割愛
- 署名がClient Attestationの`cnf.jwk`で検証できること
- `iat`が合理的な範囲内であることを確認

