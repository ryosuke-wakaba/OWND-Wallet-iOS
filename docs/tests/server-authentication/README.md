# サーバー認証テストコード一覧

## 概要

サーバー認証機能（X.509証明書チェーン検証、トラストリスト管理）に対するテストコードの一覧とテスト内容を記載します。

**関連ドキュメント**: [docs/features/server-authentication/README.md](../../features/server-authentication/README.md)

## テストファイル一覧

| テストファイル | テスト対象 | ドキュメント |
|--------------|----------|------------|
| TrustAnchorManagerTests.swift | TrustAnchorManagerの単体テスト | [詳細](./trust-anchor-manager-tests.md) |
| X509ChainValidationTests.swift | 証明書チェーン検証の統合テスト | [詳細](./x509-chain-validation-tests.md) |
| X509HashValidationTests.swift | x509_hash Client ID検証テスト（OID4VP 1.0） | [詳細](./x509-hash-validation-tests.md) |
| TrustedListManagerTests.swift | TrustedListManagerの単体テスト | [詳細](./trusted-list-manager-tests.md) |
| TrustedListModelsTests.swift | LoTEデータモデルのパーステスト | [詳細](./trusted-list-models-tests.md) |

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

## モックURLProtocol

`TrustedListManagerTests`ではネットワークリクエストをモックするために`MockURLProtocol`を使用：

```swift
override func setUp() {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [MockURLProtocol.self]
    mockSession = URLSession(configuration: config)

    MockURLProtocol.mockResponses = [:]
    manager = TrustedListManager(urlSession: mockSession)
}

// モックレスポンスの設定
MockURLProtocol.mockResponses[".*trusted-list\\.json"] = (responseData, response)
```

---

## トラブルシューティング

### テストが不安定

1. `notValidBefore`の設定を確認
2. テスト間の状態クリア（`setUp`/`tearDown`）を確認
3. `TrustAnchorManager.shared.clear()`が各テスト前後で呼ばれているか確認

### モックレスポンスが機能しない

1. URLパターンの正規表現が正しいか確認
2. `MockURLProtocol.mockResponses`がテスト前にクリアされているか確認
3. `URLSessionConfiguration.protocolClasses`に`MockURLProtocol`が設定されているか確認
