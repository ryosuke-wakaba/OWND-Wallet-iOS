# X509ChainValidationTests.swift

**パス**: `tw2023_walletTests/X509ChainValidationTests.swift`

**対応実装**: `tw2023_wallet/Signature/X509CertificateOperations.swift`

**概要**: 証明書チェーン検証の統合テストです。

---

## 基本検証テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testTrustAnchorManagerSetup` | TrustAnchorManager設定確認 | TrustAnchorManagerの設定が正しいこと |
| `testValidCertificateChainWithCustomAnchors` | 単一チェーンの検証 | カスタムアンカーで単一チェーンを検証できること |
| `testValidCertificateChainWithTwoTrustChains` | 複数チェーンの検証 | 複数の信頼チェーンを検証できること |
| `testInvalidChainWithMissingIntermediate` | 中間証明書欠落時の検証失敗 | 中間証明書が欠落している場合に検証が失敗すること |
| `testInvalidChainWithUnknownRoot` | 未知のルートCAでの検証失敗 | 未知のルートCAでは検証が失敗すること |

---

## JWT x5cヘッダーテスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testJwtWithX5CHeaderValidation` | JWT x5cヘッダーの検証 | x5cヘッダー付きJWTの検証が成功すること |
| `testJwtWithX5CHeaderInvalidChain` | 無効なチェーンでのJWT検証失敗 | 無効なチェーンではJWT検証が失敗すること |

---

## x5cチェーンテスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testX5cWithChain_LeafAndIntermediate` | x5cにリーフ+中間証明書を含む場合 | リーフと中間証明書を含むx5cチェーンが検証できること |
| `testX5cWithLeafOnly_FailsWithoutIntermediate` | x5cにリーフのみで中間証明書がない場合 | 中間証明書がない場合に検証が失敗すること |
| `testJwtWithX5CChain_LeafAndIntermediate` | JWT x5cに完全チェーン | 完全なチェーンを含むJWT x5cが検証できること |
| `testJwtWithX5CLeafOnly_SucceedsWithTrustAnchorManagerIntermediate` | TrustAnchorManagerの中間証明書で補完 | TrustAnchorManagerの中間証明書で補完して検証が成功すること |

---

## フォーマット検証テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testInvalidX5cFormat_CommaSeparatedCertificates` | カンマ区切り形式のエラー検出 | カンマ区切り形式（不正）がエラーとして検出されること |
