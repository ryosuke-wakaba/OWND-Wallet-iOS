# リファクタリング: Signature配下のUtilモジュールのリネーム

## 概要
`tw2023_wallet/Signature/` 配下の3つのファイル名に「Util」と付いているが、汎用的なユーティリティではなく専用処理が主なため、適切な名称に変更した。

## 対象ファイルと変更内容

| 現在のファイル名 | 新しいファイル名 | 変更理由 |
|-----------------|----------------|---------|
| JWTUtil.swift | JWT.swift | JWT署名・検証・デコードの専用処理 |
| JWEUtil.swift | JWE.swift | JWE暗号化の専用処理 |
| SignatureUtil.swift | X509CertificateOperations.swift | X.509証明書の変換・検証が主な処理 |

## 詳細な変更内容

### 1. JWTUtil.swift → JWT.swift
- ファイル名: `JWTUtil.swift` → `JWT.swift`
- enum名: `JWTUtil` → `JWTOperations` (※JWTDecodeライブラリのJWT型との衝突を避けるため)
- 影響範囲: 多数のファイルで `JWTUtil.` → `JWTOperations.` に更新

### 2. JWEUtil.swift → JWE.swift
- ファイル名: `JWEUtil.swift` → `JWE.swift`
- struct名: `JWEUtil` → `JWE`
- 影響範囲: `tw2023_wallet/Services/OID/Provider/ProviderUtils.swift`

### 3. SignatureUtil.swift → X509CertificateOperations.swift
- ファイル名: `SignatureUtil.swift` → `X509CertificateOperations.swift`
- enum名: `SignatureUtil` → `X509CertificateOperations`
- エラー型名: `SignatureUtilError` → `X509CertificateError`
- 影響範囲: 多数のファイルで参照を更新

## 進捗

- [x] 作業ドキュメント作成
- [x] JWTUtil.swift → JWT.swift (enum名は JWTOperations)
- [x] JWEUtil.swift → JWE.swift
- [x] SignatureUtil.swift → X509CertificateOperations.swift
- [x] project.pbxproj の更新
- [x] ビルド確認 ✅ BUILD SUCCEEDED

## 変更されたファイル一覧

### ソースファイル
- tw2023_wallet/Signature/JWT.swift (リネーム + enum名変更)
- tw2023_wallet/Signature/JWE.swift (リネーム + struct名変更)
- tw2023_wallet/Signature/X509CertificateOperations.swift (リネーム + enum名変更)
- tw2023_wallet/Signature/X5CJWTVerifier.swift
- tw2023_wallet/Signature/TrustAnchorManager.swift
- tw2023_wallet/Utils/KeyPairUtil.swift
- tw2023_wallet/Utils/CertificateUtil.swift
- tw2023_wallet/Utils/SDJwtUtil.swift
- tw2023_wallet/Services/OID/AuthorizationRequest.swift
- tw2023_wallet/Services/OID/KeyBindingImpl.swift
- tw2023_wallet/Services/OID/JwtVpJsonGeneratorImpl.swift
- tw2023_wallet/Services/OID/Provider/ProviderTypes.swift
- tw2023_wallet/Services/OID/Provider/ProviderUtils.swift
- tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift
- tw2023_wallet/Services/OID/VCI/DPoPService.swift
- tw2023_wallet/Services/TrustedList/TrustedListManager.swift
- tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestViewModel.swift
- tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestPreviewModel.swift
- tw2023_wallet/Feature/IssuerDetail/ViewModels/IssuerDetailViewModel.swift

### テストファイル
- tw2023_walletTests/Utils/JWTTest.swift
- tw2023_walletTests/Signature/SignatureUitlTest.swift
- tw2023_walletTests/Signature/X509ChainValidationTests.swift
- tw2023_walletTests/Signature/ES256KTest.swift
- tw2023_walletTests/SignatureUtilTests.swift
- tw2023_walletTests/VCIClientTests.swift
- tw2023_walletTests/AuthorizationRquestTests.swift
- tw2023_walletTests/KeyBindingTests.swift

### プロジェクトファイル
- tw2023_wallet.xcodeproj/project.pbxproj
