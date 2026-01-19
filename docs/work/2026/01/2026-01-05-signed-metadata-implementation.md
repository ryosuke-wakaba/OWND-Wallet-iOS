# Signed Metadata Implementation Work Document

## Status
- [x] 調査・設計
- [x] 実装
- [x] テスト
- [x] ドキュメント更新
- [ ] レビュー

## Overview

OID4VCI 1.0仕様 Section 12.2.3に基づくSigned Metadataサポートを実装する。

### 目的
- Issuerメタデータの信頼性検証
- 署名付きメタデータの取得・検証機能の追加

### 要件
- 署名検証はx5cの場合のみサポート（kid, trust_chain等は未サポートエラー）
- HTTPヘッダー（Accept/Content-Type）によるレスポンス形式の判断

## Specification Summary

### Signed Metadata JWT Structure

**JOSE Header:**
```json
{
  "alg": "ES256",
  "typ": "openidvci-issuer-metadata+jwt",
  "x5c": ["<leaf-cert-base64>", "<intermediate-cert-base64>", ...]
}
```

**Payload:**
```json
{
  "iss": "<party attesting to claims>",
  "sub": "<credential-issuer-identifier>",
  "iat": 1234567890,
  "exp": 1234567890,
  "credential_issuer": "...",
  "credential_endpoint": "...",
  "credential_configurations_supported": { ... }
}
```

### HTTP Content Negotiation

Issuer側の処理分岐:
- Signed Metadataがある場合: `Content-Type: application/jwt`
- 通常のJSON: `Content-Type: application/json`

## Existing Infrastructure (Reusable)

以下は `docs/2025-12-12-work-x5c-chain-intermediate.md` で実装済み:

| 機能 | 実装 | 状態 |
|------|------|------|
| x5c検証 | `JWTUtil.verifyJwtByX5C()` | ✅ 完全実装済み |
| 証明書チェーン検証 | `SignatureUtil.validateCertificateChainWithCustomAnchors()` | ✅ 完全実装済み |
| RFC 7515準拠base64デコード | `SignatureUtil.decodeBase64ToX509Certificate()` | ✅ 完全実装済み |
| 不正x5c形式検出 | `SignatureUtil.convertPemToX509Certificates()` | ✅ 完全実装済み |

**既存の検証フロー（そのまま活用可能）:**
```
x5c: [cert1, cert2, ...] (JWTヘッダー)
        ↓
JWTUtil.verifyJwtByX5C()
        ↓
convertPemToX509Certificates() → RFC 7515準拠チェック
        ↓
全証明書をSecCertificateに変換
        ↓
validateCertificateChainWithCustomAnchors(certificates: 全証明書)
        ↓
    ┌─────────────────────────────────────────────────────┐
    │ x5c証明書数で分岐:                                    │
    │ ・count == 1 → TrustAnchorManagerの中間証明書を補完  │
    │ ・count > 1  → x5cチェーンをそのまま使用            │
    └─────────────────────────────────────────────────────┘
        ↓
validateTrust(fullChain, customAnchors: TrustAnchorManager.anchorCertificates)
```

## Implementation Plan

### Phase 1: Signed Metadata検証ロジックの追加
- [x] `typ`ヘッダー検証（`openidvci-issuer-metadata+jwt`）
- [x] 署名方式チェック（x5cのみサポート、kid/trust_chainはエラー）
- [x] x5c検証（既存の`JWTUtil.verifyJwtByX5C()`を使用）
- [x] ペイロード検証（`sub` == Issuer URL）

### Phase 2: VCIMetadataClient拡張
- [x] Acceptヘッダー設定の追加
- [x] Content-Typeによるレスポンス分岐
- [x] Signed Metadata検証統合

### Phase 3: エラーハンドリング
- [x] MetadataError拡張（署名検証エラー追加）
- [x] 未サポート署名形式エラー

### Phase 4: テスト
- [x] Signed Metadata検証ユニットテスト (10 tests passed)
- [ ] VCIMetadataClient 統合テスト（実際のIssuer連携時に検証）

## Technical Design

### New Files

| File | Description |
|------|-------------|
| `tw2023_wallet/Services/OID/VCI/SignedMetadataValidator.swift` | Signed Metadata検証ロジック |

### Modified Files

| File | Change |
|------|--------|
| `tw2023_wallet/Services/OID/VCI/VCIMetadataClient.swift` | MetadataError拡張、Accept/Content-Type対応、検証統合 |

### New Test Files

| File | Description |
|------|-------------|
| `tw2023_walletTests/SignedMetadataValidatorTests.swift` | Signed Metadata検証ユニットテスト |

### Existing Infrastructure Leveraged

- `JWTUtil.verifyJwtByX5C()` - x5c証明書検証（完全実装済み）
- `SignatureUtil.validateCertificateChainWithCustomAnchors()` - 証明書チェーン検証（完全実装済み）
- `SignatureUtil.convertPemToX509Certificates()` - x5c証明書変換（RFC 7515準拠）

### Validation Flow

```
fetchCredentialIssuerMetadata()
  │
  ├─ HTTP Request with Accept: application/jwt, application/json
  │
  ├─ Check Content-Type header
  │   │
  │   ├─ application/jwt
  │   │   ├─ Parse JWT header
  │   │   ├─ Validate typ == "openidvci-issuer-metadata+jwt"
  │   │   ├─ Check x5c presence (error if kid/trust_chain only)
  │   │   ├─ JWTUtil.verifyJwtByX5C(jwt)
  │   │   ├─ Validate payload (sub == issuer, iat, exp)
  │   │   └─ Decode payload as CredentialIssuerMetadata
  │   │
  │   └─ application/json
  │       └─ Decode as CredentialIssuerMetadata (existing flow)
  │
  └─ Return metadata
```

### Error Types

```swift
enum SignedMetadataError: Error {
    case unsupportedSignatureMethod(String)  // kid, trust_chain等
    case invalidTyp(String)                   // typ != openidvci-issuer-metadata+jwt
    case signatureVerificationFailed(Error)   // x5c検証失敗
    case invalidPayload(String)               // sub不一致、iat/exp無効
    case certificateChainValidationFailed(Error)
}
```

## Test Results

**SignedMetadataValidatorTests (10 tests - all passed):**
- testValidSignedMetadata
- testInvalidTypHeader
- testMissingTypHeader
- testUnsupportedSignatureMethod_Kid
- testSubjectMismatch
- testMissingSub
- testMissingIat
- testExpiredMetadata
- testValidMetadataWithoutExp
- testExtractMetadataJson

## Progress Log

| Date | Progress |
|------|----------|
| 2026-01-05 | 調査完了、設計ドキュメント作成 |
| 2026-01-05 | SignedMetadataValidator実装完了 |
| 2026-01-05 | VCIMetadataClient Signed Metadata対応完了 |
| 2026-01-05 | ユニットテスト作成・全10テストパス |

## References

- [OID4VCI 1.0 Section 12.2.3 - Signed Metadata](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#section-12.2.3)
- [RFC 7515 - JSON Web Signature](https://www.rfc-editor.org/rfc/rfc7515.html)
- docs/features/credential-issuance.md
