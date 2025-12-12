# x5c証明書チェーン中間証明書対応

## 概要

Request ObjectのJWTヘッダーに含まれるx5c証明書に中間証明書が含まれるケースに対応する。

**作業ブランチ**: `feature/x5c-chain-intermediate-support`

## 進捗状況

| タスク | ステータス | 備考 |
|--------|------------|------|
| 現状調査・分析 | 完了 | |
| 作業ドキュメント作成 | 完了 | |
| 実装方針決定 | 完了 | x5c優先方式を採用 |
| 実装 | 完了 | SignatureUtil, JWTUtil, 呼び出し元を更新 |
| テスト作成・実行 | 完了 | 全12テストパス |
| コードレビュー依頼 | 未着手 | |

## 現状分析（変更前）

### 変更前の実装フロー

```
x5c: [cert1, cert2, ...] (JWTヘッダー)
        ↓
JWTUtil.verifyJwtByX5C()
        ↓
全証明書をSecCertificateに変換
        ↓
validateCertificateChainWithCustomAnchors(leafCertificates: 全証明書)
        ↓
fullChain = 全証明書 + TrustAnchorManager.intermediateCertificates  ← 常に追加
        ↓
validateTrust(fullChain, customAnchors: TrustAnchorManager.anchorCertificates)
```

### 変更後の実装フロー

```
x5c: [cert1, cert2, ...] (JWTヘッダー)
        ↓
JWTUtil.verifyJwtByX5C()
        ↓
convertPemToX509Certificates() → カンマ区切りチェック（RFC 7515違反検出）
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

### 関連ファイル

| ファイル | 役割 |
|----------|------|
| `tw2023_wallet/Signature/JWTUtil.swift` | JWT検証、x5c抽出 (L180-258) |
| `tw2023_wallet/Signature/SignatureUtil.swift` | 証明書チェーン検証 (L376-455) |
| `tw2023_wallet/Signature/TrustAnchorManager.swift` | トラストアンカー・中間証明書管理 |

### 問題点

1. **x5cにルートCAが含まれる場合**: x5c内のルートCAが`TrustAnchorManager.anchorCertificates`に存在しないと検証失敗
2. **x5cに中間証明書が含まれる場合**: x5cの中間証明書が活用されず、TrustAnchorManagerの中間証明書のみで構築

### 想定されるx5cパターン

| パターン | 内容 | 変更前 | 変更後 |
|----------|------|--------|--------|
| A | `[leaf]` のみ | ✅ 対応済み | ✅ 対応済み（TrustAnchorManagerから補完） |
| B | `[leaf, intermediate]` | ⚠️ 部分対応 | ✅ **対応済み**（x5cチェーンをそのまま使用） |
| C | `[leaf, intermediate, root]` | ❌ 未対応 | ⚠️ ルートCAはTrustAnchorManager登録が必要 |
| D | カンマ区切り形式（RFC違反） | ❌ クラッシュ | ✅ **エラーダイアログ表示** |

## 実装方針

### 案1: x5cチェーン内のルートCAを動的アンカーとして使用

x5cの最後の証明書が自己署名（ルートCA）の場合、それを一時的なトラストアンカーとして追加。

**メリット**:
- x5c内で完結するチェーンを検証可能
- TrustAnchorManagerへの事前登録不要

**デメリット**:
- 任意のルートCAを信頼するリスク（要検討）

### 案2: x5c証明書を優先使用

x5cに複数証明書がある場合、TrustAnchorManagerの中間証明書追加をスキップし、x5cのチェーンをそのまま使用。

**メリット**:
- シンプルな実装
- x5c提供者の意図通りのチェーン

**デメリット**:
- ルートCAはTrustAnchorManagerに必要

### 案3: ハイブリッド方式

1. x5cの証明書を全てチェーンに含める
2. x5c内の自己署名証明書があれば一時アンカーとして追加
3. TrustAnchorManagerのアンカーも併用（フォールバック）

## 採用方針: 案2 x5c優先方式

**理由**:
- x5c提供者の意図通りのチェーンを尊重
- シンプルな実装で保守性が高い
- ルートCAはTrustAnchorManagerで管理することでセキュリティを維持

**動作概要**:
- x5cにリーフのみ → 従来通りTrustAnchorManagerから中間証明書を補完
- x5cに複数証明書 → x5cのチェーンをそのまま使用（TrustAnchorManagerの中間証明書は追加しない）
- ルートCA → 常にTrustAnchorManager.anchorCertificatesを使用

## 実装詳細

### 変更対象

#### 1. SignatureUtil.swift (L376-411)

`validateCertificateChainWithCustomAnchors`を変更し、x5cチェーンの内容に応じた処理を実装。

```swift
// 変更前
static func validateCertificateChainWithCustomAnchors(
    leafCertificates: [SecCertificate],
    useCustomAnchorsOnly: Bool = false
) -> Result<Void, CertificateValidationError>

// 変更後
static func validateCertificateChainWithCustomAnchors(
    certificates: [SecCertificate],  // パラメータ名変更
    useCustomAnchorsOnly: Bool = false
) -> Result<Void, CertificateValidationError>
```

**変更内容:**
- パラメータ名を`leafCertificates`から`certificates`に変更（実態を反映）
- x5cに1証明書のみ（リーフのみ）の場合: TrustAnchorManagerの中間証明書を追加
- x5cに複数証明書（チェーン）の場合: そのまま使用（TrustAnchorManagerの中間証明書は追加しない）

#### 2. 呼び出し元の更新

以下のファイルでパラメータ名を更新:
- `tw2023_wallet/Signature/JWTUtil.swift` (L240-242, L304-307)
- `tw2023_wallet/Feature/IssuerDetail/ViewModels/IssuerDetailViewModel.swift` (L114)
- `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestPreviewModel.swift` (L30)
- `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestViewModel.swift` (L139-140)

#### 3. SignatureUtil.swift - base64デコード処理の整理

RFC 7515に準拠した実装に整理。

**RFC 7515 Section 4.1.6:**
> Each string in the array is a **base64-encoded** (Section 4 of [RFC4648] -- **not base64url-encoded**) DER PKIX certificate value.

**実装:**
- x5c内の証明書は標準base64エンコード（base64urlではない）
- `.ignoreUnknownCharacters`オプションで空白・改行を許容
- 不要なbase64url変換ロジックを削除

```swift
static func decodeBase64ToX509Certificate(base64str: String) throws -> Certificate {
    // RFC 7515: x5c certificates are standard base64-encoded (not base64url)
    guard let derData = Data(base64Encoded: base64str, options: .ignoreUnknownCharacters) else {
        throw SignatureUtilError.X509CertificateConversionError
    }
    return try Certificate(derEncoded: Array(derData))
}
```

#### 4. SignatureUtil.swift - 不正なx5c形式のエラー検出

RFC 7515違反（カンマ区切り形式）の検出とエラーダイアログ表示を実装。

**追加エラーケース:**
```swift
enum SignatureUtilError: LocalizedError, Equatable {
    case KeyConversionError
    case X509CertificateConversionError
    case invalidX5cFormat  // 新規追加

    var errorDescription: String? {
        switch self {
        case .invalidX5cFormat:
            return "Invalid x5c format in JWT: certificates must be separate array elements, not comma-separated. Please contact the service provider."
        // ...
        }
    }
}
```

**検出ロジック:**
```swift
static func convertPemToX509Certificates(pemChain: [String]) throws -> [Certificate] {
    return try pemChain.map { certString in
        // RFC 7515違反: カンマ区切り形式の検出
        if certString.contains(",") {
            throw SignatureUtilError.invalidX5cFormat
        }
        return try decodeBase64ToX509Certificate(base64str: certString)
    }
}
```

**エラー伝播（JWTUtil.swift）:**
```swift
let certificates: [Certificate]
do {
    certificates = try SignatureUtil.convertPemToX509Certificates(pemChain: x5c)
} catch let error as SignatureUtilError {
    return .failure(.verificationFailed(error.localizedDescription))
} catch {
    return .failure(.verificationFailed("Unable to convert x5c: \(error.localizedDescription)"))
}
```

### テスト結果

**ファイル:** `tw2023_walletTests/Signature/X509ChainValidationTests.swift`

| テストケース | 説明 | 結果 |
|--------------|------|------|
| `testX5cWithChain_LeafAndIntermediate` | x5cにリーフ＋中間証明書、TrustAnchorManagerには中間なし | ✅ Pass |
| `testX5cWithLeafOnly_FailsWithoutIntermediate` | x5cにリーフのみ、TrustAnchorManagerに中間なし → 失敗すべき | ✅ Pass |
| `testJwtWithX5CChain_LeafAndIntermediate` | JWT検証: x5cにチェーン含む | ✅ Pass |
| `testJwtWithX5CLeafOnly_SucceedsWithTrustAnchorManagerIntermediate` | JWT検証: x5cリーフのみ、TrustAnchorManagerから補完 | ✅ Pass |
| `testInvalidX5cFormat_CommaSeparatedCertificates` | カンマ区切り形式のx5cでエラーが発生すること | ✅ Pass |
| 既存テスト（7件） | 従来動作の回帰テスト | ✅ Pass |

**全12テストパス**

## 変更ファイル一覧

| ファイル | 変更内容 |
|----------|----------|
| `tw2023_wallet/Signature/SignatureUtil.swift` | x5c優先ロジック実装、base64url対応修正、`invalidX5cFormat`エラー追加、デバッグログ削除 |
| `tw2023_wallet/Signature/JWTUtil.swift` | `SignatureUtilError`のエラーメッセージ伝播対応 |
| `tw2023_wallet/Feature/IssuerDetail/ViewModels/IssuerDetailViewModel.swift` | パラメータ名変更（`leafCertificates` → `certificates`） |
| `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestPreviewModel.swift` | パラメータ名変更 |
| `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestViewModel.swift` | パラメータ名変更 |
| `tw2023_walletTests/Signature/X509ChainValidationTests.swift` | 新規テスト5件追加（x5cチェーン対応、不正形式検出） |

## 参考資料

- [RFC 7515 - JSON Web Signature (JWS)](https://datatracker.ietf.org/doc/html/rfc7515#section-4.1.6) - x5cヘッダーの仕様
- [OID4VP 1.0](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html) - Client ID Scheme
- `docs/features/credential-presentation.md` - VP提示機能ドキュメント
- `docs/x509-certificate-chain-validation.md` - 証明書チェーン検証アーキテクチャ

## 変更履歴

| 日付 | 内容 |
|------|------|
| 2025-12-12 | 初版作成、現状分析完了 |
| 2025-12-12 | 実装完了、テストパス |
| 2025-12-12 | base64url対応修正を追加（動作確認で発見） |
| 2025-12-12 | RFC 7515違反（カンマ区切りx5c）のエラー検出・ダイアログ表示機能を追加 |
| 2025-12-12 | デバッグログのクリーンアップ、全12テストパス |
| 2025-12-12 | 不要なbase64url変換ロジックを削除（RFC 7515: x5cは標準base64） |
