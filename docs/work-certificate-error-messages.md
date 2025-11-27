# 証明書検証エラーメッセージ改善

## ステータス
- [x] 調査完了
- [x] 計画策定
- [x] 実装
- [x] テスト
- [ ] レビュー

## 概要

証明書チェーン検証失敗時に、具体的なエラー理由をユーザーに表示できるようにする。

## 現状の問題

### エラーフロー（現状）

```
SecTrust API
  └─ CFError: "ルートは信頼されていません"
       │
       ▼ (printのみ)
SignatureUtil.validateTrust()
  └─ return false
       │
       ▼
JWTUtil.verifyJwtByX5C()
  └─ .failure(.verificationFailed("Unable to verify chain of trust"))
       │
       ▼
OpenIdProvider.processAuthRequest()
  └─ .authRequestInputError(.compliantError("JWT verification failed"))
       │
       ▼
SharingRequestViewModel
  └─ alertMessage = "JWT verification failed"
```

### 問題点

1. SecTrustからの詳細エラー情報（`"ルートは信頼されていません"`）が途中で消失
2. ユーザーには「JWT verification failed」としか表示されない
3. 開発者もログを見ないと原因特定できない

## 改善計画

### Phase 1: エラー型の定義

**ファイル:** `tw2023_wallet/Signature/SignatureUtil.swift`

```swift
/// 証明書チェーン検証エラー
enum CertificateValidationError: LocalizedError {
    case trustCreationFailed
    case anchorSettingFailed
    case untrustedRoot(certificateName: String)
    case certificateExpired(certificateName: String)
    case certificateRevoked(certificateName: String)
    case invalidCertificate(certificateName: String, reason: String)
    case chainIncomplete
    case unknownError(description: String)

    var errorDescription: String? {
        switch self {
        case .trustCreationFailed:
            return "証明書の検証準備に失敗しました"
        case .anchorSettingFailed:
            return "信頼アンカーの設定に失敗しました"
        case .untrustedRoot(let name):
            return "証明書「\(name)」のルートCAは信頼されていません"
        case .certificateExpired(let name):
            return "証明書「\(name)」の有効期限が切れています"
        case .certificateRevoked(let name):
            return "証明書「\(name)」は失効しています"
        case .invalidCertificate(let name, let reason):
            return "証明書「\(name)」が無効です: \(reason)"
        case .chainIncomplete:
            return "証明書チェーンが不完全です"
        case .unknownError(let description):
            return "証明書検証エラー: \(description)"
        }
    }
}
```

### Phase 2: validateTrustの改修

**変更:** `Bool`を返す代わりに`Result<Void, CertificateValidationError>`を返す

```swift
private static func validateTrust(
    _ certificates: [SecCertificate],
    customAnchors: [SecCertificate]?,
    useCustomAnchorsOnly: Bool
) -> Result<Void, CertificateValidationError> {
    // ...
    // エラー時は詳細情報を含むCertificateValidationErrorを返す
}
```

### Phase 3: JWTVerificationErrorの拡張

**ファイル:** `tw2023_wallet/Signature/JWTUtil.swift`

```swift
enum JWTVerificationError: Error {
    case unsupportedAlgorithm
    case invalidPublicKeyType
    case verificationFailed(String)
    case certificateValidationFailed(CertificateValidationError)  // 追加
}
```

### Phase 4: エラーメッセージの表示改善

**ファイル:** `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestViewModel.swift`

エラーの種類に応じたユーザーフレンドリーなメッセージを表示。

## 改善後のエラーフロー

```
SecTrust API
  └─ CFError: "ルートは信頼されていません"
       │
       ▼
SignatureUtil.validateTrust()
  └─ .failure(.untrustedRoot(certificateName: "localhost"))
       │
       ▼
JWTUtil.verifyJwtByX5C()
  └─ .failure(.certificateValidationFailed(.untrustedRoot("localhost")))
       │
       ▼
OpenIdProvider.processAuthRequest()
  └─ .authRequestInputError(.compliantError("証明書「localhost」のルートCAは信頼されていません"))
       │
       ▼
SharingRequestViewModel
  └─ alertMessage = "証明書「localhost」のルートCAは信頼されていません"
```

## SecTrust エラーコードマッピング

| OSStatus Code | 意味 | CertificateValidationError |
|---------------|------|---------------------------|
| -67818 | errSecCertificateExpired | `.certificateExpired` |
| -67843 | errSecNotTrusted | `.untrustedRoot` |
| -67820 | errSecCertificateRevoked | `.certificateRevoked` |
| その他 | - | `.unknownError` |

## 変更ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `SignatureUtil.swift` | `CertificateValidationError`追加、`validateTrust`を`Result`型に改修、`parseSecTrustError`追加 |
| `JWTUtil.swift` | `JWTVerificationError.certificateValidationFailed`追加、`verifyJwtByX5C`/`verifyJwtByX5U`でエラー伝播 |
| `OpenIdProvider.swift` | `certificateValidationFailed`からエラーメッセージを抽出して表示 |
| `SharingRequestViewModel.swift` | `Result`型への対応、エラーreasonの直接抽出 |
| `SharingRequestPreviewModel.swift` | `Result`型への対応 |
| `IssuerDetailViewModel.swift` | `Result`型への対応、エラーログ出力追加 |
| `X509ChainValidationTests.swift` | `Result`型への対応 |

## 追加修正: SharingRequestViewModelでのエラー抽出

`AuthorizationRequestInputError`は`LocalizedError`を実装していないため、`.localizedDescription`が「操作を完了できませんでした」のような汎用メッセージを返していた。

**修正前:**
```swift
alertMessage = subError.localizedDescription  // → "操作を完了できませんでした"
```

**修正後:**
```swift
switch subError {
case .compliantError(let reason):
    alertMessage = reason  // → "証明書「localhost」のルートCAは信頼されていません"
case .missingParameter(let reason):
    alertMessage = reason
// ...
}
```

## テスト計画

1. 期限切れ証明書でのエラーメッセージ確認
2. 未知のルートCA証明書でのエラーメッセージ確認
3. 有効な証明書での正常動作確認

## 参考: OSStatusエラーコード

```swift
// Security.framework SecBase.h より
let errSecCertificateExpired = -67818      // 証明書期限切れ
let errSecCertificateNotValidYet = -67819  // 証明書がまだ有効ではない
let errSecCertificateRevoked = -67820      // 証明書が失効
let errSecNotTrusted = -67843              // 信頼されていない
```
