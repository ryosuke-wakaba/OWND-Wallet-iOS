# OID4VCI テストコード一覧

## 概要

OID4VCI（OpenID for Verifiable Credential Issuance）1.0プロトコルの実装に対するテストコードの一覧とテスト内容を記載します。

**関連ドキュメント**: [docs/features/credential-issuance.md](../features/credential-issuance.md)

## テストファイル一覧

| テストファイル | テスト対象 | パス |
|--------------|----------|------|
| VCIClientTests.swift | トークン・クレデンシャル発行 | tw2023_walletTests/ |
| VCIMetadataTests.swift | メタデータデコード | tw2023_walletTests/ |
| VCIMetadataClientTests.swift | メタデータ取得 | tw2023_walletTests/ |
| VCIMetadataUtilTests.swift | メタデータユーティリティ | tw2023_walletTests/ |
| DPoPServiceTests.swift | DPoP Proof生成 | tw2023_walletTests/ |
| KeyPairUtilTest.swift | 鍵ペア・Proof JWT生成 | tw2023_walletTests/Utils/ |
| SDJwtUtilTest.swift | SD-JWT処理 | tw2023_walletTests/Utils/ |

---

## 1. VCIClientTests.swift

**パス**: `tw2023_walletTests/VCIClientTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/VCIClient.swift`

**概要**: OID4VCI 1.0のトークン発行、クレデンシャル発行、Nonce取得のフローをテストします。

### テストクラス: DecodingCredentialOfferTests

Credential Offerのデコード処理をテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeFilledCredentialOffer` | 完全なCredential Offer | 全フィールドが正しくデコードされること |
| `testDecodeMinimumCredentialOffer` | 最小限のCredential Offer | 必須フィールドのみのOfferがデコードできること |
| `testDecodeCredentialOfferWithTxCode` | tx_code付きOffer | `isTxCodeRequired()`がtrueを返すこと |
| `testFromStringCredentialOfferFilled` | URL形式からのデコード | `openid-credential-offer://`スキームのURLからデコードできること |

### テストクラス: DecodingCredentialResponseTests

Credential Responseのデコード処理をテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeJwtVcJsonResponse` | jwt_vc_json形式レスポンス | JWT形式のCredentialがデコードできること |
| `testDecodeVcSdJwtResponse` | vc+sd-jwt形式レスポンス | SD-JWT形式のCredentialがデコードできること |
| `testDeferredResponse` | Deferredレスポンス | `transaction_id`が正しく取得できること |
| `testNotificationResponse` | Notificationレスポンス | `notification_id`が正しく取得できること |

### テストクラス: VCIClientTests

VCIクライアントの各エンドポイント通信をテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testPostTokenRequest` | Token Endpoint通信 | トークンリクエストが正しく送信され、レスポンスがデコードされること |
| `testPostCredentialRequest` | Credential Endpoint通信 | クレデンシャルリクエストが正しく送信されること |
| `testPostNonceRequest` | Nonce Endpoint通信 | OID4VCI 1.0のNonceエンドポイントからc_nonceを取得できること |
| `testPostNonceRequestWithDPoPNonce` | DPoP-Nonce取得 | レスポンスヘッダーからDPoP-Nonceを抽出できること |
| `testFetchNonce` | VCIClient.fetchNonce | VCIClientのfetchNonceメソッドが正しく動作すること |
| `testIssueToken` | VCIClient.issueToken | Pre-authorized Codeでトークンを発行できること |
| `testIssueCredential` | VCIClient.issueCredential | クレデンシャルを発行できること |
| `testFullCredentialIssuanceFlow` | 完全発行フロー | Credential Offer→メタデータ取得→トークン発行→Nonce取得→クレデンシャル発行の一連フローが成功すること |

### OID4VCI 1.0 統合フロー

```
1. Credential Offer URL解析
   openid-credential-offer://?credential_offer={...}

2. メタデータ取得
   GET /.well-known/openid-credential-issuer
   GET /.well-known/oauth-authorization-server

3. Token Endpoint
   POST /token
   → access_token, token_type

4. Nonce Endpoint (OID4VCI 1.0)
   POST /nonce
   → c_nonce, DPoP-Nonce header

5. Credential Endpoint
   POST /credentials
   Authorization: DPoP <access_token>
   → credential
```

---

## 2. VCIMetadataTests.swift

**パス**: `tw2023_walletTests/VCIMetadataTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/VCIMetadata.swift`

**概要**: Credential IssuerメタデータとCredential Configurationのデコード処理をテストします。

### テストクラス: DecodingCredentialDisplayTests

クレデンシャル表示情報のデコードをテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeFilledCredentialDisplay` | 完全なDisplay | name, locale, logo, description, colors等が正しくデコードされること |
| `testDecodeMinimumCredentialDisplay` | 最小限のDisplay | nameのみでデコードできること |

### テストクラス: DecodingCredentialSupportedTests

Credential Configurationのデコードをテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeCredentialSupportedJwtVcJson` | jwt_vc_json形式 | jwt_vc_json形式のCredential Configurationがデコードできること |
| `testDecodeCredentialSupportedVcSdJwt` | vc+sd-jwt形式 | vc+sd-jwt形式のCredential Configurationがデコードできること |
| `testDecodeCredentialSupportedLdpVc` | ldp_vc形式 | ldp_vc形式のCredential Configurationがデコードできること |

### テストクラス: DecodingClaimMapTests

クレームマップのデコードをテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeEmptyClaimMap` | 空のClaimMap | 空のClaimMapがデコードできること |
| `testDecodeFilledClaimMap` | 完全なClaimMap | mandatory, valueType, display等が正しくデコードされること |
| `testDecodeMixMandatoryAndNonMandatoryClaimMap` | 混合ClaimMap | mandatory/非mandatoryが混在するClaimMapがデコードできること |

### テストクラス: localizedClaimNamesTests

クレーム名のローカライズ処理をテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testGetLocalizedClaimNames` | ローカライズ取得 | 指定localeのクレーム名を取得できること |
| `testFirstLocaleSelected` | フォールバック | 未対応localeでは最初のlocaleにフォールバックすること |

### テストクラス: DecodingVCIMetadataTests

Credential Issuerメタデータ全体のデコードをテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeVcSdJwtMetadata` | SD-JWTメタデータ | vc+sd-jwt形式のメタデータが完全にデコードされること |
| `testDecodeJwtVcMetadata` | JWT VCメタデータ | jwt_vc_json形式のメタデータが完全にデコードされること |
| `testDecodeLdpVcMetadata` | LDP VCメタデータ | ldp_vc形式のメタデータが完全にデコードされること |

### サポートするCredential Format

| フォーマット | 説明 | テスト対象 |
|------------|------|----------|
| `jwt_vc_json` | JWT形式VC | ✅ |
| `vc+sd-jwt` | SD-JWT形式VC | ✅ |
| `ldp_vc` | Linked Data Proof VC | ✅ |

---

## 3. VCIMetadataClientTests.swift

**パス**: `tw2023_walletTests/VCIMetadataClientTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/VCIMetadataClient.swift`

**概要**: メタデータエンドポイントからのデータ取得をテストします。

### テストクラス: CredentialIssuerMetadataTests

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testFetchCredentialIssuerMetadata` | Issuerメタデータ取得 | `/.well-known/openid-credential-issuer`からメタデータを取得できること |
| `testFetchAuthServerMetadata` | 認可サーバーメタデータ取得 | `/.well-known/oauth-authorization-server`からメタデータを取得できること |
| `testRetrieveAllMetadata` | 全メタデータ取得 | IssuerメタデータとAuthサーバーメタデータを同時に取得できること |
| `testEnumDocode` | Enumデコード | ResponseMode等のEnum値が正しくデコードされること |

### Well-Known エンドポイント

| エンドポイント | 取得データ |
|--------------|----------|
| `/.well-known/openid-credential-issuer` | Credential Issuerメタデータ |
| `/.well-known/oauth-authorization-server` | Authorization Serverメタデータ |

---

## 4. VCIMetadataUtilTests.swift

**パス**: `tw2023_walletTests/VCIMetadataUtilTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/VCIMetadataUtil.swift`

**概要**: メタデータ処理のユーティリティ関数をテストします。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testFindMatchingCredentialsJwtVc` | JWT VC検索 | jwt_vc_json形式のCredential Configurationを検索できること |
| `testFindMatchingCredentialsSdJwt` | SD-JWT検索 | dc+sd-jwt形式のCredential Configurationを検索できること |
| `testExtractDisplayByClaim` | Display抽出 | Credential Configurationからクレームごとのdisplay情報を抽出できること |
| `testSerializationAndDeserialization` | シリアライズ | DisplayByClaimMapのシリアライズ・デシリアライズが正しく動作すること |

---

## 5. DPoPServiceTests.swift

**パス**: `tw2023_walletTests/DPoPServiceTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/DPoPService.swift`

**概要**: RFC 9449に基づくDPoP（Demonstrating Proof of Possession）のProof生成をテストします。

### テストケース

#### ath（Access Token Hash）計算テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testCalculateAthConsistency` | ath計算一貫性 | 同じアクセストークンから同じathが生成されること |
| `testCalculateAthWithKnownValue` | ath計算検証 | 既知の値（SHA256("test")）でathが正しく計算されること |
| `testCalculateAthProducesBase64UrlEncoding` | Base64URL形式 | athがBase64URL形式（+/=なし）であること |

#### DPoP Proof生成テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testCreateProofForTokenEndpoint` | Token Endpoint用Proof | typ, alg, jwk, jti, htm, htu, iatが正しく含まれ、athがないこと |
| `testCreateProofWithAccessToken` | Resource Server用Proof | athクレームが正しく含まれること |
| `testCreateProofWithNonce` | nonce付きProof | nonceクレームが正しく含まれること |
| `testUriNormalization` | URI正規化 | htuからquery/fragmentが除去されること |
| `testUniqueJtiGeneration` | jti一意性 | 各Proofに固有のjtiが生成されること |
| `testGetPublicKeyJwk` | 公開鍵JWK取得 | DPoP鍵の公開鍵JWKが取得できること |

### DPoP Proof JWT構造

**Header:**
```json
{
  "typ": "dpop+jwt",
  "alg": "ES256",
  "jwk": { "kty": "EC", "crv": "P-256", "x": "...", "y": "..." }
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

**Payload (Resource Server):**
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

### RFC 9449 準拠

| 要件 | 対応状況 |
|-----|:-------:|
| typ: "dpop+jwt" | ✅ |
| 非対称アルゴリズム (ES256) | ✅ |
| 公開鍵をjwkに含める | ✅ |
| jti (一意なID) | ✅ |
| htm (HTTPメソッド) | ✅ |
| htu (ターゲットURI、query/fragmentなし) | ✅ |
| iat (発行時刻) | ✅ |
| ath (アクセストークンハッシュ) | ✅ |
| nonce (サーバー提供nonce) | ✅ |

---

## 6. KeyPairUtilTest.swift

**パス**: `tw2023_walletTests/Utils/KeyPairUtilTest.swift`

**対応実装**: `tw2023_wallet/Utils/KeyPairUtil.swift`

**概要**: 鍵ペア生成とProof JWT作成をテストします。クレデンシャル発行時のKey Binding Proofに使用されます。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testGeneration` | 鍵ペア生成 | ES256鍵ペアが正常に生成されること |
| `testCheckKeyExistence` | 鍵存在確認 | 生成した鍵の存在を確認できること |
| `testGetPrivateKey` | 秘密鍵取得 | 秘密鍵を取得できること |
| `testGetPublicKey` | 公開鍵取得 | 公開鍵を取得できること |
| `testGetKeyPair` | 鍵ペア取得 | 秘密鍵・公開鍵のペアを取得できること |
| `testPublicKeyToJwk` | JWK変換 | 公開鍵をJWK形式に変換できること |
| `testCreateProofJwtAndVerify` | Proof JWT生成・検証 | Proof JWTを生成し、公開鍵で検証できること |
| `testCreatePublicKey` | JWKから公開鍵復元 | JWKからSecKeyを復元できること |

### Proof JWT構造（OID4VCI Key Binding）

```json
{
  "header": {
    "typ": "openid4vci-proof+jwt",
    "alg": "ES256",
    "jwk": { ... }
  },
  "payload": {
    "aud": "<credential_issuer>",
    "iat": 1234567890,
    "nonce": "<c_nonce>"
  }
}
```

---

## 7. SDJwtUtilTest.swift

**パス**: `tw2023_walletTests/Utils/SDJwtUtilTest.swift`

**対応実装**: `tw2023_wallet/Utils/SDJwtUtil.swift`

**概要**: SD-JWT（Selective Disclosure JWT）の解析処理をテストします。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDevideSDJwtSignedJwtExtraction` | SD-JWT分割 | Issuer Signed JWT、Disclosure、KB-JWTを正しく分割すること |
| `testDecodeDisclosure` | Disclosure解読 | Disclosureを正しくデコードし、クレーム名を抽出すること |
| `testgetDecodedJwtHeader` | JWTヘッダーデコード | SD-JWTのヘッダーを正しくデコードすること |
| `testGetSdAlg_Default` | `_sd_alg`デフォルト値 | `_sd_alg`省略時に`sha-256`が返されること |
| `testGetSdAlg_WithExplicitSha256` | `_sd_alg`明示指定 | `_sd_alg: "sha-256"`が正しく読み取られること |
| `testGetSdAlg_WithSha384` | `_sd_alg`値抽出 | `_sd_alg: "sha-384"`が正しく読み取られること |
| `testGetSdAlg_InvalidJwt` | 不正JWT時のデフォルト | 不正なJWT形式でもデフォルト`sha-256`が返されること |
| `testGetSdAlg_EmptyString` | 空文字列入力 | 空文字列入力でもデフォルト`sha-256`が返されること |

---

## テストリソースファイル

テストで使用するJSONリソースファイル一覧：

```
tw2023_walletTests/Resources/
├── credential_offer_filled.json
├── credential_offer_minimum.json
├── credential_offer_tx_code_required.json
├── token_response.json
├── credential_response_jwt_vc_json.json
├── credential_response_vc_sd_jwt.json
├── credential_response_deferred.json
├── credential_response_notification.json
├── credential_response_mock.json
├── credential_display_filled.json
├── credential_display_minimum.json
├── credential_supported_jwt_vc.json
├── credential_supported_vc_sd_jwt.json
├── credential_supported_ldp_vc.json
├── claim_map_empty.json
├── claim_map_filled.json
├── claim_map_mixed.json
├── authorization_server.json
└── credential_issuer_metadata.json
```

---

## テスト機能マッピング

OID4VCI機能とテストの対応関係：

| OID4VCI機能 | テストファイル | カバレッジ |
|-----------|--------------|----------|
| Credential Offer解析 | VCIClientTests.swift | ✅ |
| Issuerメタデータ取得 | VCIMetadataClientTests.swift | ✅ |
| AuthServerメタデータ取得 | VCIMetadataClientTests.swift | ✅ |
| Credential Configuration解析 | VCIMetadataTests.swift | ✅ |
| Token Endpoint通信 | VCIClientTests.swift | ✅ |
| Nonce Endpoint通信 (OID4VCI 1.0) | VCIClientTests.swift | ✅ |
| Credential Endpoint通信 | VCIClientTests.swift | ✅ |
| DPoP Proof生成 (RFC 9449) | DPoPServiceTests.swift | ✅ |
| DPoP-Nonce処理 | VCIClientTests.swift | ✅ |
| Key Binding Proof生成 | KeyPairUtilTest.swift | ✅ |
| SD-JWT解析 | SDJwtUtilTest.swift | ✅ |
| Credential Response処理 | VCIClientTests.swift | ✅ |
| 多言語Display処理 | VCIMetadataTests.swift | ✅ |

---

## 実装状況サマリー

| 機能 | 実装 | テスト | OID4VCI 1.0 | 備考 |
|------|:----:|:------:|:----------:|------|
| Pre-Authorized Code Grant | ✅ | ✅ | 必須 | VCIClientTests.swift |
| Authorization Code Grant | ❌ | - | オプション | 未実装 |
| Nonce Endpoint | ✅ | ✅ | 必須 | OID4VCI 1.0で追加 |
| DPoP (RFC 9449) | ✅ | ✅ | HAIP必須 | DPoPServiceTests.swift |
| Key Binding Proof (JWT) | ✅ | ✅ | 必須 | KeyPairUtilTest.swift |
| jwt_vc_json形式 | ✅ | ✅ | オプション | VCIMetadataTests.swift |
| vc+sd-jwt形式 | ✅ | ✅ | オプション | VCIMetadataTests.swift |
| ldp_vc形式 | ✅ | ✅ | オプション | VCIMetadataTests.swift（デコードのみ） |
| Deferred Issuance | ❌ | ✅ | オプション | レスポンス解析のみ |
| Batch Issuance | ❌ | - | オプション | 未実装 |
| Credential Encryption | ❌ | - | オプション | 未実装 |

---

## 今後のテスト拡充候補

### テスト追加が望ましい実装済み機能

以下の機能は実装済みですが、専用のユニットテストがありません：

- [ ] CredentialIssuanceService統合テスト
- [ ] TokenIssuanceService単体テスト
- [ ] CredentialRequestService単体テスト
- [ ] ProofGenerationService単体テスト
- [ ] CredentialStorageService単体テスト
- [ ] DPoP統合テスト（VCIClient経由）

### 未実装機能（オプション）

以下はOID4VCI 1.0のオプション機能であり、現在未実装です：

- [ ] Authorization Code Grant
- [ ] Deferred Issuance完全対応
- [ ] Batch Issuance
- [ ] Credential Encryption
