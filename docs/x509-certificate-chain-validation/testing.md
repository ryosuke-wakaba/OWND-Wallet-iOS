# テスト

[← README](./README.md)

## テストファイル

| ファイル | 内容 |
|---------|------|
| `TrustAnchorManagerTests.swift` | TrustAnchorManagerの単体テスト |
| `X509ChainValidationTests.swift` | 証明書チェーン検証の統合テスト |

## 主なテストケース

### TrustAnchorManagerTests

- `testSharedInstance` - シングルトンの確認
- `testAddAnchorCertificate` - ルートCA追加
- `testAddIntermediateCertificate` - 中間証明書追加
- `testSelfSignedCertificateDetection` - 自己署名検出
- `testNonSelfSignedCertificateDetection` - 非自己署名検出

### X509ChainValidationTests

- `testValidCertificateChainWithCustomAnchors` - 単一チェーンの検証
- `testValidCertificateChainWithTwoTrustChains` - 複数チェーンの検証
- `testInvalidChainWithMissingIntermediate` - 中間証明書欠落時の検証失敗
- `testInvalidChainWithUnknownRoot` - 未知のルートCAでの検証失敗
- `testJwtWithX5CHeaderValidation` - JWT x5cヘッダーの検証

---

## テスト用証明書の生成

テストでは動的に証明書チェーンを生成：

```swift
// ルートCA生成（自己署名）
let rootCert = try generateRootCACertificate(
    privateKey: rootPrivateKey,
    commonName: "Test Root CA"
)

// 中間CA生成
let intermediateCert = try generateIntermediateCACertificate(
    subjectPrivateKey: intermediatePrivateKey,
    issuerPrivateKey: rootPrivateKey,
    issuerCertificate: rootCert,
    commonName: "Test Intermediate CA"
)

// リーフ証明書生成
let leafCert = try generateLeafCertificate(
    subjectPrivateKey: leafPrivateKey,
    issuerPrivateKey: intermediatePrivateKey,
    issuerCertificate: intermediateCert,
    commonName: "test.example.com"
)
```

---

## 証明書有効期間の注意点

テスト証明書は `notValidBefore` を現在時刻の1時間前に設定：

```swift
let notBefore = Date().addingTimeInterval(-60 * 60)  // 1時間前
let notAfter = Date().addingTimeInterval(60 * 60 * 24 * 365)  // 1年後
```

これにより、タイミングによる「証明書が一時的に無効」エラーを回避します。

---

## トラブルシューティング

### テストが不安定

1. `notValidBefore`の設定を確認
2. テスト間の状態クリア（`setUp`/`tearDown`）を確認
