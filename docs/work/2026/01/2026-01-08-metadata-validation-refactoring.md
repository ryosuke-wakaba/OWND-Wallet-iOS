# メタデータ検証機能のリファクタリング

## ブランチ

`refactor/metadata-validation-cleanup`

## ステータス
- [x] 調査完了
- [x] Phase 1: 重複コードの統合
  - [x] extractDERFromPEM()の統合
  - [x] validateCertificateChainWithCustomAnchors()の整理 (既に実装済み)
  - [x] テストコード作成
- [x] Phase 2: 同期版APIの削除
  - [x] 使用箇所調査
  - [x] 非同期版への移行
  - [x] 同期版の削除
  - [x] テストコード更新
- [x] Phase 3: 未使用コードの削除
  - [x] レガシーAPIの削除
  - [x] テストコード更新
- [x] ビルド確認
- [x] 全テスト実行・確認
- [ ] レビュー

## 概要

メタデータ検証機能に関連するモジュールの実装を調査し、重複コード・未使用コードを整理する。

## 対象ファイル

| ファイル | 行数 | 責務 |
|---------|-----|------|
| `tw2023_wallet/Services/OID/VCI/VCIMetadataClient.swift` | 243 | メタデータ取得クライアント |
| `tw2023_wallet/Services/OID/VCI/SignedMetadataValidator.swift` | 300 | 署名付きメタデータ検証 |
| `tw2023_wallet/Services/TrustedList/TrustedListManager.swift` | 391 | トラストリスト管理 |
| `tw2023_wallet/Services/TrustedList/TrustedListModels.swift` | 129 | LoTEデータモデル |
| `tw2023_wallet/Signature/TrustAnchorManager.swift` | 283 | 信頼アンカー証明書管理 |
| `tw2023_wallet/Signature/JWTUtil.swift` | 516 | JWT検証ユーティリティ |
| `tw2023_wallet/Signature/SignatureUtil.swift` | 580 | 証明書チェーン検証 |

## 調査結果

### 1. 重複コード

#### 1.1 extractDERFromPEM() - 3箇所

**完全に同一の実装**:
- `TrustAnchorManager.swift` (行222-237)
- `TrustedListManager.swift` (行364-379)

**類似機能**:
- `SignatureUtil.swift` - `base64strToPem()` (行215-233)

```swift
private func extractDERFromPEM(_ pem: String) -> Data? {
    let beginMarker = "-----BEGIN CERTIFICATE-----"
    let endMarker = "-----END CERTIFICATE-----"

    guard let beginRange = pem.range(of: beginMarker),
          let endRange = pem.range(of: endMarker) else {
        return nil
    }

    let base64String = pem[beginRange.upperBound..<endRange.lowerBound]
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "\n", with: "")
        .replacingOccurrences(of: "\r", with: "")

    return Data(base64Encoded: base64String)
}
```

**対応方針**: `SignatureUtil.swift`に共通関数として統合

---

#### 1.2 base64urlデコーディング - 3箇所

**実装箇所**:
- `SignatureUtil.swift` - `base64UrlDecoded()` extension (行25-40)
- `SDJwtUtil.swift` - `base64urlToBase64()` (行62-71)
- `TrustedListManager.swift` - `extractPayloadFromJWT()` (行186-220)

**対応方針**: `SignatureUtil.swift`のextensionに統合し、他から参照

---

#### 1.3 同期版/非同期版APIの重複

**SignedMetadataValidator.validate()**:
- 同期版 (行102-153) - シングルトンTrustAnchorManager使用
- 非同期版 (行160-236) - TrustedList対応

**JWTUtil.verifyJwtByX5C()**:
- 同期版 (行180-264) - シングルトンTrustAnchorManager使用
- 非同期版 (行272-377) - TrustedList対応

**対応方針**: 同期版の使用箇所を調査し、削除可能か判断

---

#### 1.4 validateCertificateChainWithCustomAnchors() - 2オーバーロード

**SignatureUtil.swift**:
- シングルトン版 (行413)
- インスタンス指定版 (行432)

両方の実装がほぼ同一で、シングルトン版がインスタンス指定版に委譲していない。

**対応方針**: シングルトン版をインスタンス指定版に委譲するよう修正

---

### 2. 未使用コード

#### 2.1 fetchCredentialIssuerMetadata (レガシー版)

**ファイル**: `VCIMetadataClient.swift` (行165-169)

```swift
/// Legacy function for backward compatibility (without signed metadata validation)
func fetchCredentialIssuerMetadata(from url: URL, using session: URLSession = URLSession.shared)
    async throws -> CredentialIssuerMetadata
```

**使用状況**: grepによる調査で呼び出し元が見つからない

**対応方針**: 削除

---

#### 2.2 verifyJwtByX5C (同期版)

**ファイル**: `JWTUtil.swift` (行180-264)

**使用箇所**: `OpenIdProvider.swift` (行80) のみ

```swift
let result = JWTUtil.verifyJwtByX5C(jwt: jwt, verifyCertChain: true)
```

**対応方針**: OpenIdProviderを非同期版に移行後、同期版を削除

---

### 3. アーキテクチャ上の課題

#### 3.1 証明書変換ロジックの分散

証明書のPEM/DER変換が複数のファイルに分散:
- `TrustAnchorManager.swift` - `createCertificate()`, `extractDERFromPEM()`
- `TrustedListManager.swift` - `createCertificate()`, `extractDERFromPEM()`
- `SignatureUtil.swift` - 各種変換関数

**対応方針**: `SignatureUtil.swift`に集約

#### 3.2 Content-Type検証ロジック

**ファイル**: `VCIMetadataClient.swift` (行118-123)

現在の実装:
```swift
if preferSignedMetadata && !isJwtResponse {
    throw MetadataError.contentTypeMismatch(expected: "application/jwt", actual: contentType)
}
if !preferSignedMetadata && !isJsonResponse {
    throw MetadataError.contentTypeMismatch(expected: "application/json", actual: contentType)
}
```

問題: 条件が排他的でないケースがある（JWTを期待してJSONが返ってきた場合のフォールバック処理との整合性）

**対応方針**: 既存動作を維持（フォールバックが実装済みのため問題なし）

---

### 4. TODO/暫定対応事項

#### 4.1 TrustedListManager キャッシュ

```swift
// TODO: Re-enable cache with TTL based on NextUpdate
```

キャッシュは一時的に無効化されている。将来的にNextUpdateフィールドに基づくTTL実装が望ましい。

#### 4.2 ServiceTypeIdentifier検索

```swift
// TODO: Service type check temporarily disabled for investigation
// guard info.ServiceTypeIdentifier == serviceType else {
//     continue
// }
```

サービスタイプによるフィルタリングがコメントアウト。

**対応方針**: 本リファクタリングでは対応せず、将来課題として残す

---

## リファクタリング計画

### Phase 1: 重複コードの統合（安全な変更）

#### 1.1 extractDERFromPEM()の統合

**変更内容**:
- `SignatureUtil.swift`に`static func extractDERFromPEM(_ pem: String) -> Data?`を追加
- `TrustAnchorManager`と`TrustedListManager`から`extractDERFromPEM()`を削除
- 両クラスで`SignatureUtil.extractDERFromPEM()`を使用するよう変更

**テスト**:
- `SignatureUtilTests.swift`に`extractDERFromPEM`のテストを追加
  - 有効なPEM形式の証明書からDERデータを抽出できること
  - 無効な形式（マーカーなし）の場合はnilを返すこと
  - 空文字列の場合はnilを返すこと

#### 1.2 validateCertificateChainWithCustomAnchors()の整理

**変更内容**:
- シングルトン版をインスタンス指定版に委譲するよう修正

**テスト**:
- 既存のテストが引き続きパスすることを確認

---

### Phase 2: 同期版APIの削除（依存関係確認後）

#### 2.1 使用箇所の調査

**調査対象**:
- `JWTUtil.verifyJwtByX5C()` 同期版の呼び出し元
- `SignedMetadataValidator.validate()` 同期版の呼び出し元

#### 2.2 非同期版への移行

**変更内容**:
- `OpenIdProvider.swift`を非同期版`verifyJwtByX5C`に移行
- その他の呼び出し元があれば同様に移行

**テスト**:
- `OpenIdProviderTests.swift`のテストを更新（非同期対応）
- 既存のJWT検証テストが引き続きパスすることを確認

#### 2.3 同期版の削除

**変更内容**:
- `JWTUtil.verifyJwtByX5C()` 同期版を削除
- `SignedMetadataValidator.validate()` 同期版を削除（使用箇所がなければ）

**テスト**:
- 削除した関数を使用していたテストを非同期版に更新

---

### Phase 3: 未使用コードの削除

#### 3.1 レガシーAPIの削除

**変更内容**:
- `VCIMetadataClient.fetchCredentialIssuerMetadata` レガシー版（引数が少ない版）を削除

**テスト**:
- 既存の`VCIMetadataClientTests`が引き続きパスすることを確認

---

## テスト実施結果

### 新規テストファイル

**`SignatureUtilTests.swift`** (新規作成)

| テストケース | 説明 |
|-------------|------|
| `testExtractDERFromPEM_validPEM` | 有効なPEM形式からDERデータを抽出 |
| `testExtractDERFromPEM_validPEMWithWhitespace` | 空白を含むPEMからDERデータを抽出 |
| `testExtractDERFromPEM_invalidFormat_noMarkers` | マーカーなしの場合nilを返す |
| `testExtractDERFromPEM_invalidFormat_onlyBeginMarker` | BEGINマーカーのみの場合nilを返す |
| `testExtractDERFromPEM_invalidFormat_onlyEndMarker` | ENDマーカーのみの場合nilを返す |
| `testExtractDERFromPEM_emptyString` | 空文字列の場合nilを返す |
| `testExtractDERFromPEM_emptyContent` | 空のコンテンツの場合の動作確認 |
| `testExtractDERFromPEM_invalidBase64` | 無効なBase64の場合nilを返す |
| `testExtractDERFromPEM_pemWithCarriageReturns` | CRLF改行コードを含むPEMの処理 |
| `testBase64UrlDecoded_validBase64Url` | 有効なbase64urlのデコード |
| `testBase64UrlDecoded_withSpecialChars` | 特殊文字（-、_）を含むbase64url |
| `testBase64UrlDecoded_requiresPadding` | パディングが必要なbase64url |

---

### 更新したテストファイル

#### `SignedMetadataValidatorTests.swift`

同期版から非同期版への移行:

| テストケース | 変更内容 |
|-------------|---------|
| `testValidSignedMetadata()` | `async throws`に変更、`await`追加 |
| `testInvalidTypHeader()` | `async throws`に変更、`await`追加 |
| `testMissingTypHeader()` | `async throws`に変更、`await`追加 |
| `testUnsupportedSignatureMethod_Kid()` | `async throws`に変更、`await`追加 |
| `testSubjectMismatch()` | `async throws`に変更、`await`追加 |
| `testMissingSub()` | `async throws`に変更、`await`追加 |
| `testMissingIat()` | `async throws`に変更、`await`追加 |
| `testExpiredMetadata()` | `async throws`に変更、`await`追加 |
| `testValidMetadataWithoutExp()` | `async throws`に変更、`await`追加 |

---

#### `X509ChainValidationTests.swift`

| テストケース | 変更内容 |
|-------------|---------|
| `testJwtWithX5CHeaderValidation()` | `async throws`に変更、`JWTUtil.verifyJwtByX5C(jwt:issuerURL:verifyCertChain:)`に移行 |
| `testJwtWithX5CHeaderInvalidChain()` | `async throws`に変更、`JWTUtil.verifyJwtByX5C(jwt:issuerURL:verifyCertChain:)`に移行 |
| `testJwtWithX5CChain_LeafAndIntermediate()` | `async throws`に変更、`JWTUtil.verifyJwtByX5C(jwt:issuerURL:verifyCertChain:)`に移行 |
| `testJwtWithX5CLeafOnly_SucceedsWithTrustAnchorManagerIntermediate()` | `async throws`に変更、`JWTUtil.verifyJwtByX5C(jwt:issuerURL:verifyCertChain:)`に移行 |

---

#### `X509HashValidationTests.swift`

| テストケース | 変更内容 |
|-------------|---------|
| `testJwtX5cIntegration_ValidClientId()` | `async throws`に変更、`JWTUtil.verifyJwtByX5C(jwt:issuerURL:verifyCertChain:)`に移行 |
| `testJwtX5cIntegration_AttackerCertificate()` | `async throws`に変更、`JWTUtil.verifyJwtByX5C(jwt:issuerURL:verifyCertChain:)`に移行 |

---

#### `JWTTest.swift`

| テストケース | 変更内容 |
|-------------|---------|
| `testVerifyJwtByX5C()` | `async`に変更、`JWTUtil.verifyJwtByX5C(jwt:issuerURL:verifyCertChain:)`に移行 |

---

#### `TrustedListManagerTests.swift`

既存エラーの修正（本リファクタリングとは直接関係なし）:

| テストケース | 変更内容 |
|-------------|---------|
| `testFindServiceNotFound()` | catch文に`catch { XCTFail(...) }`を追加（網羅的エラーハンドリング） |
| `testFindServiceIgnoresWithdrawnStatus()` | catch文に`catch { XCTFail(...) }`を追加（網羅的エラーハンドリング） |

---

#### `VCIMetadataClientTests.swift`

| テストケース | 変更内容 |
|-------------|---------|
| `testFetchCredentialIssuerMetadata()` | `fetchCredentialIssuerMetadata(from:using:)`から`fetchMetadata(from:to:using:)`に変更 |

---

### テスト実行結果

```
** TEST SUCCEEDED **

実行テスト:
- SignatureUtilTests: 12 tests passed
- SignedMetadataValidatorTests: 10 tests passed
- X509ChainValidationTests: 10 tests passed
- X509HashValidationTests: 17 tests passed
- JWTUtilTest: 3 tests passed
```

### テスト実行コマンド

```bash
# 関連テストのみ実行
xcodebuild test -scheme tw2023_wallet -destination 'platform=iOS Simulator,name=iPhone 16' \
  -only-testing:tw2023_walletTests/SignedMetadataValidatorTests \
  -only-testing:tw2023_walletTests/SignatureUtilTests \
  -only-testing:tw2023_walletTests/X509ChainValidationTests \
  -only-testing:tw2023_walletTests/X509HashValidationTests \
  -only-testing:tw2023_walletTests/JWTUtilTest

# 全テスト実行
xcodebuild test -scheme tw2023_wallet -destination 'platform=iOS Simulator,name=iPhone 16'
```

---

## 参考ドキュメント

- [docs/features/credential-issuance/metadata-verification.md](../features/credential-issuance/metadata-verification.md)
- [docs/x509-certificate-chain-validation.md](../x509-certificate-chain-validation.md)
- [2026-01-07-work-trusted-list-support.md](./2026-01-07-work-trusted-list-support.md)
