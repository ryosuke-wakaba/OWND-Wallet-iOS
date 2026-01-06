# Signed Metadata Accept Header Fix

## Status
- [x] 調査・設計
- [x] 実装
- [ ] テスト
- [ ] ドキュメント更新

## Overview

OID4VCI 1.0仕様 Section 12.2.2に準拠するため、Signed Metadata取得時のAcceptヘッダー制御を修正する。

### 問題点

**現在の実装:**
- `Accept: application/jwt, application/json;q=0.9` を常に送信（署名付き優先）
- レスポンスの`Content-Type`で処理を分岐

**仕様との不一致:**
- 仕様では、クライアントが`Accept`ヘッダーで要求する形式を明示的に指定すべき
- `application/jwt` = 署名付きメタデータを要求
- `application/json` = 署名なしメタデータを要求

### 修正内容

1. `fetchCredentialIssuerMetadata`関数に`preferSignedMetadata`パラメータを追加
2. パラメータに基づいて`Accept`ヘッダーを設定
   - `true`: `Accept: application/jwt`
   - `false`: `Accept: application/json`（デフォルト）
3. `retrieveAllMetadata`関数にも同様のパラメータを追加
4. レスポンスのContent-Typeが要求と一致しない場合はエラーを返す

## Specification Reference

[OID4VCI 1.0 Section 12.2.2](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#section-12.2.2):

> To fetch the Credential Issuer Metadata, the Wallet MUST send an HTTP request using the GET method and the path formed following the steps above. The Wallet is RECOMMENDED to send an Accept header in the HTTP GET request to indicate the Content Type(s) it supports, and by doing so, signaling whether it supports signed metadata.

## Implementation Plan

### Modified Files

| File | Change |
|------|--------|
| `tw2023_wallet/Services/OID/VCI/VCIMetadataClient.swift` | Accept header control via parameter |
| `tw2023_wallet/datastore/PreferencesDataStore.swift` | 設定の保存・取得メソッド追加 |
| `tw2023_wallet/Feature/Settings/Setting.swift` | 発行設定セクション追加 |
| `tw2023_wallet/Feature/IssueCredential/ViewModels/CredentialOfferViewModel.swift` | 設定値を使用してメタデータ取得 |
| `tw2023_wallet/Localizable.xcstrings` | ローカライズ文字列追加 |

### API Changes

**Before:**
```swift
func fetchCredentialIssuerMetadata(
    from url: URL,
    issuerIdentifier: String,
    using session: URLSession = URLSession.shared
) async throws -> CredentialIssuerMetadata

func retrieveAllMetadata(issuer: String, using session: URLSession = URLSession.shared)
    async throws -> Metadata
```

**After:**
```swift
func fetchCredentialIssuerMetadata(
    from url: URL,
    issuerIdentifier: String,
    preferSignedMetadata: Bool = false,  // NEW: デフォルトはJSON
    using session: URLSession = URLSession.shared
) async throws -> CredentialIssuerMetadata

func retrieveAllMetadata(
    issuer: String,
    preferSignedMetadata: Bool = false,  // NEW: デフォルトはJSON
    using session: URLSession = URLSession.shared
) async throws -> Metadata
```

### Accept Header Behavior

| `preferSignedMetadata` | Accept Header |
|------------------------|---------------|
| `false` (default) | `application/json` |
| `true` | `application/jwt` |

### New Error Type

```swift
case contentTypeMismatch(expected: String, actual: String)
```

要求した`Accept`ヘッダーとレスポンスの`Content-Type`が一致しない場合にスローされる。

## Progress Log

| Date | Progress |
|------|----------|
| 2026-01-06 | 調査完了、設計ドキュメント作成 |
| 2026-01-06 | 実装完了: `preferSignedMetadata`パラメータ追加 |
| 2026-01-06 | Content-Type検証追加: 要求と応答の不一致時にエラー |
| 2026-01-06 | 設定UI追加: 発行設定セクションとトグル |
| 2026-01-06 | CredentialOfferViewModelに設定を統合 |

## References

- [OID4VCI 1.0 Section 12.2.2](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#section-12.2.2)
- docs/work/signed-metadata-implementation.md
- docs/features/credential-issuance.md
