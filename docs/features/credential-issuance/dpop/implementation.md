# DPoP 実装詳細ドキュメント

## 概要

本ドキュメントは、OWND Wallet iOSにおけるDPoP (Demonstrating Proof of Possession) 機能の実装詳細について記載します。

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

## 鍵管理

### DPoP鍵ペア

| 項目 | 値 |
|------|-----|
| キーエイリアス | `dpopKey` (Constants.Cryptography.KEY_DPOP) |
| アルゴリズム | ECDSA P-256 (secp256r1) |
| 保存場所 | Keychain / Secure Enclave |
| 生成タイミング | DPoP Proof初回生成時（自動） |

### 鍵生成フロー

```swift
// DPoPService.ensureKeyPairExists()
if !KeyPairUtil.isKeyPairExist(alias: keyAlias) {
    try KeyPairUtil.generateSignVerifyKeyPair(alias: keyAlias)
}
```

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

## セキュリティ効果

### 1. Sender-Constrained Access Tokens

- アクセストークンは発行時のクライアント公開鍵にバインド
- 盗まれたトークン単体では使用不可
- 秘密鍵を持つクライアントのみがトークンを使用可能

### 2. Proof of Possession

- 各リクエストでクライアントの秘密鍵による署名が必要
- Man-in-the-Middle攻撃への耐性
- トークン漏洩リスクの大幅な軽減

### 3. Replay Protection

- `jti` (JWT ID): 各Proofに一意のID
- `DPoP-Nonce`: サーバー発行のnonce
- `ath`: アクセストークンへのバインディング

### 4. URI Binding

- `htu`: リクエスト先URIへのバインディング
- `htm`: HTTPメソッドへのバインディング
- 異なるエンドポイントでのProof再利用を防止

## Authorization Server側での検証手順

### 1. DPoP Proof JWTの基本検証

- `typ`が`dpop+jwt`であること
- `alg`がサポートされた非対称アルゴリズムであること（ES256）
- `jwk`ヘッダーに有効な公開鍵が含まれること
- 署名が`jwk`の公開鍵で検証できること

### 2. Payloadクレームの検証

- `jti`がユニークであること（リプレイ検出）
- `htm`がリクエストのHTTPメソッドと一致すること
- `htu`がリクエストのターゲットURIと一致すること
- `iat`が合理的な範囲内であること

### 3. Access Token使用時の追加検証

- `ath`がアクセストークンのハッシュと一致すること
- アクセストークン発行時の`jwk`と一致すること
- `nonce`がサーバー発行値と一致すること（提供した場合）

## 使用方法

DPoPはクレデンシャル発行サービスで使用されます:

```swift
// CredentialIssuanceServiceでDPoP使用
try await issuanceService.issueCredential(
    credentialOffer: offer,
    metadata: metadata,
    credentialConfigurationId: configId,
    txCode: txCode,
    useDPoP: true  // DPoP有効化
)
```

## 実装ファイル一覧

| ファイル | 役割 |
|---------|------|
| `tw2023_wallet/Services/OID/VCI/DPoPService.swift` | DPoP Proof生成サービス |
| `tw2023_wallet/Services/OID/VCI/VCIClient.swift` | VCI クライアント（DPoP統合） |
| `tw2023_wallet/Feature/Constants.swift` | DPoP鍵定数定義 |
| `tw2023_wallet/Services/CredentialIssuance/TokenIssuanceService.swift` | Token発行サービス |
| `tw2023_wallet/Services/CredentialIssuance/CredentialRequestService.swift` | Credential要求サービス |
| `tw2023_walletTests/DPoPServiceTests.swift` | ユニットテスト |
