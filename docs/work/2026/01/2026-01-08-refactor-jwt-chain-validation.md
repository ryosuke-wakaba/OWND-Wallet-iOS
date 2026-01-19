# JWTUtilとSignatureUtilの依存分離リファクタリング

## ブランチ

`refactor/metadata-validation-cleanup`

## ステータス
- [x] 調査完了
- [x] X5CJWTVerifierの作成
- [x] JWTUtilからx5c/x5u関連メソッドを削除
- [x] 呼び出し元の更新
  - [x] OpenIdProvider.swift
  - [x] SignedMetadataValidator.swift
  - [x] VerificationViewModel.swift
- [x] テストコードの更新
  - [x] X509ChainValidationTests.swift
  - [x] X509HashValidationTests.swift
  - [x] JWTTest.swift
- [ ] ビルド確認
- [ ] テスト実行
- [ ] レビュー

## 概要

JWTUtilからSignatureUtilへの依存を無くし、JWT検証とX509証明書チェーン検証の責務を分離するリファクタリング。

## 背景

### 変更前のアーキテクチャ

```
OpenIdProvider / SignedMetadataValidator
            ↓
    JWTUtil.verifyJwtByX5C()
            ↓
    ┌───────┴───────┐
    ↓               ↓
 JWT署名検証    SignatureUtil.validateCertificateChainWithCustomAnchors()
```

### 問題点

1. `JWTUtil`がJWT検証と証明書チェーン検証の両方を担当
2. `JWTUtil`が`SignatureUtil`に依存
3. 責務が混在しており単体テストが困難

## 変更後のアーキテクチャ

```
OpenIdProvider / SignedMetadataValidator
            ↓
    X5CJWTVerifier (新規)
            ↓
    ┌───────┴───────┐
    ↓               ↓
  JWTUtil      SignatureUtil
(JWT検証のみ)  (チェーン検証のみ)
```

## 変更内容

### 新規ファイル

| ファイル | 説明 |
|---------|------|
| `tw2023_wallet/Signature/X5CJWTVerifier.swift` | JWT検証と証明書チェーン検証を統合するラッパー層 |

### X5CJWTVerifier API

```swift
enum X5CJWTVerifier {
    typealias VerifiedX5CJwt = (decoded: JWT, certs: [Certificate])

    /// x5cヘッダーを使用したJWT検証
    static func verifyJwtWithX5C(
        jwt: String,
        issuerURL: String?,
        verifyCertChain: Bool
    ) async -> Result<VerifiedX5CJwt, JWTVerificationError>

    /// x5uヘッダーを使用したJWT検証
    static func verifyJwtWithX5U(
        jwt: String
    ) -> Result<JWT, JWTVerificationError>
}
```

### JWTUtilからの削除

- `typealias VerifiedX5CJwt`
- `verifyJwtByX5C(jwt:issuerURL:verifyCertChain:)`
- `verifyJwtByX5U(jwt:)`
- `import X509`

### JWTUtilに残るメソッド

- `sign(keyAlias:header:payload:)` - JWT署名
- `verifyJwt(jwt:publicKey:)` - JWT署名検証
- `decodeJwt(jwt:)` - JWTデコード

### 呼び出し元の変更

| ファイル | 行 | 変更前 | 変更後 |
|---------|---|--------|--------|
| `OpenIdProvider.swift` | 82 | `JWTUtil.verifyJwtByX5C(...)` | `X5CJWTVerifier.verifyJwtWithX5C(...)` |
| `SignedMetadataValidator.swift` | 148 | `JWTUtil.verifyJwtByX5C(...)` | `X5CJWTVerifier.verifyJwtWithX5C(...)` |
| `VerificationViewModel.swift` | 52 | `JWTUtil.verifyJwtByX5U(...)` | `X5CJWTVerifier.verifyJwtWithX5U(...)` |

### テストコードの変更

| ファイル | 変更内容 |
|---------|---------|
| `X509ChainValidationTests.swift` | 4箇所の呼び出しをX5CJWTVerifierに変更 |
| `X509HashValidationTests.swift` | 2箇所の呼び出しをX5CJWTVerifierに変更 |
| `JWTTest.swift` | 1箇所の呼び出しをX5CJWTVerifierに変更 |

## 責務の分離

| コンポーネント | 責務 |
|--------------|------|
| **JWTUtil** | 純粋なJWT操作（署名、検証、デコード） |
| **SignatureUtil** | 証明書チェーン検証、証明書変換 |
| **X5CJWTVerifier** | x5c/x5uを使用したJWT検証の統合 |

## 検証方法

```bash
# ビルド確認
xcodebuild -scheme tw2023_wallet -destination 'platform=iOS Simulator,name=iPhone 15' build

# テスト実行
xcodebuild test -scheme tw2023_wallet -destination 'platform=iOS Simulator,name=iPhone 15'
```

## 関連ドキュメント

- `docs/x509-certificate-chain-validation.md` - X.509証明書チェーン検証機能
- `docs/work/2026-01-08-metadata-validation-refactoring.md` - メタデータ検証リファクタリング
