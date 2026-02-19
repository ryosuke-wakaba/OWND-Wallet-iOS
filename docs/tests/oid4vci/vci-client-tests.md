# VCIClientTests.swift

**パス**: `tw2023_walletTests/VCIClientTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/VCIClient.swift`

**概要**: OID4VCI 1.0のトークン発行、クレデンシャル発行、Nonce取得のフローをテストします。

---

## テストクラス: DecodingCredentialOfferTests

Credential Offerのデコード処理をテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeFilledCredentialOffer` | 完全なCredential Offer | 全フィールドが正しくデコードされること |
| `testDecodeMinimumCredentialOffer` | 最小限のCredential Offer | 必須フィールドのみのOfferがデコードできること |
| `testDecodeCredentialOfferWithTxCode` | tx_code付きOffer | `isTxCodeRequired()`がtrueを返すこと |
| `testFromStringCredentialOfferFilled` | URL形式からのデコード | `openid-credential-offer://`スキームのURLからデコードできること |

---

## テストクラス: DecodingCredentialResponseTests

Credential Responseのデコード処理をテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeJwtVcJsonResponse` | jwt_vc_json形式レスポンス | JWT形式のCredentialがデコードできること |
| `testDecodeVcSdJwtResponse` | vc+sd-jwt形式レスポンス | SD-JWT形式のCredentialがデコードできること |
| `testDeferredResponse` | Deferredレスポンス | `transaction_id`が正しく取得できること |
| `testNotificationResponse` | Notificationレスポンス | `notification_id`が正しく取得できること |

---

## テストクラス: VCIClientTests

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

---

## OID4VCI 1.0 統合フロー

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
