# テスト

[← README](./README.md)

## テストファイル

| ファイル | 内容 |
|---------|------|
| `TrustAnchorManagerTests.swift` | TrustAnchorManagerの単体テスト |
| `X509ChainValidationTests.swift` | 証明書チェーン検証の統合テスト |
| `X509HashValidationTests.swift` | x509_hash Client ID検証テスト（OID4VP 1.0） |
| `TrustedListManagerTests.swift` | TrustedListManagerの単体テスト |
| `TrustedListModelsTests.swift` | LoTEデータモデルのパーステスト |

---

## 主なテストケース

### TrustAnchorManagerTests

**基本テスト:**
- `testSharedInstance` - シングルトンの確認
- `testInitialState` - 初期状態の確認
- `testClearCertificates` - 証明書クリア

**証明書追加テスト:**
- `testAddAnchorCertificate` - ルートCA追加
- `testAddIntermediateCertificate` - 中間証明書追加
- `testAddAnchorCertificateFromDerData` - DERデータからルートCA追加
- `testAddIntermediateCertificateFromDerData` - DERデータから中間証明書追加
- `testAddInvalidDerData` - 無効なDERデータの拒否
- `testAllCertificates` - 全証明書取得
- `testReload` - バンドルからの再読み込み

**自己署名検出テスト:**
- `testSelfSignedCertificateDetection` - 自己署名証明書の検出
- `testNonSelfSignedCertificateDetection` - 非自己署名証明書の検出

**使い捨てインスタンステスト:**
- `testCreateDisposableInstanceWithAdditionalCertificates` - 追加証明書付きインスタンス生成
- `testCreateDisposableInstanceInheritsSingletonCertificates` - シングルトン証明書の継承
- `testDisposableInstanceDoesNotAffectSingleton` - シングルトンへの影響なし
- `testDisposableInstanceClassifiesCertificatesCorrectly` - 証明書の正しい分類
- `testDisposableInstanceHasCustomAnchors` - カスタムアンカーの有無確認
- `testDisposableInstanceWithoutAnchors` - アンカーなしインスタンス

### X509ChainValidationTests

**基本検証テスト:**
- `testTrustAnchorManagerSetup` - TrustAnchorManager設定確認
- `testValidCertificateChainWithCustomAnchors` - 単一チェーンの検証
- `testValidCertificateChainWithTwoTrustChains` - 複数チェーンの検証
- `testInvalidChainWithMissingIntermediate` - 中間証明書欠落時の検証失敗
- `testInvalidChainWithUnknownRoot` - 未知のルートCAでの検証失敗

**JWT x5cヘッダーテスト:**
- `testJwtWithX5CHeaderValidation` - JWT x5cヘッダーの検証
- `testJwtWithX5CHeaderInvalidChain` - 無効なチェーンでのJWT検証失敗

**x5cチェーンテスト:**
- `testX5cWithChain_LeafAndIntermediate` - x5cにリーフ+中間証明書を含む場合
- `testX5cWithLeafOnly_FailsWithoutIntermediate` - x5cにリーフのみで中間証明書がない場合
- `testJwtWithX5CChain_LeafAndIntermediate` - JWT x5cに完全チェーン
- `testJwtWithX5CLeafOnly_SucceedsWithTrustAnchorManagerIntermediate` - TrustAnchorManagerの中間証明書で補完

**フォーマット検証テスト:**
- `testInvalidX5cFormat_CommaSeparatedCertificates` - カンマ区切り形式のエラー検出

### X509HashValidationTests

**ハッシュ計算テスト:**
- `testCalculateX509CertificateHash_ReturnsValidBase64UrlString` - Base64URL形式の確認
- `testCalculateX509CertificateHash_ReturnsCorrectLength` - SHA-256ハッシュ長の確認（43文字）
- `testCalculateX509CertificateHash_IsDeterministic` - 決定性の確認
- `testCalculateX509CertificateHash_DifferentCertificatesProduceDifferentHashes` - 異なる証明書で異なるハッシュ
- `testCalculateX509CertificateHash_NoBase64Padding` - パディングなし確認
- `testCalculateX509CertificateHash_NoStandardBase64Characters` - `+`/`/`なし確認

**x509_hash検証テスト:**
- `testValidateX509Hash_ValidClientId` - 正しいclient_idの検証成功
- `testValidateX509Hash_WrongHash` - 不正なハッシュの検証失敗
- `testValidateX509Hash_TamperedHash` - 改ざんされたハッシュの検出
- `testValidateX509Hash_WrongPrefix` - 不正なプレフィックスのエラー
- `testValidateX509Hash_EmptyCertificates` - 空の証明書リストのエラー

**統合テスト:**
- `testJwtX5cIntegration_ValidClientId` - JWT x5cとclient_idの統合検証
- `testJwtX5cIntegration_AttackerCertificate` - 攻撃者証明書の検出

**SAN検証テスト:**
- `testIsDomainInSAN_MatchingDomain` - SANドメイン一致
- `testIsDomainInSAN_NonMatchingDomain` - SANドメイン不一致
- `testIsDomainInSAN_SubdomainMismatch` - サブドメイン不一致
- `testIsDomainInSAN_ParentDomainMismatch` - 親ドメイン不一致

### TrustedListManagerTests

**フェッチテスト:**
- `testFetchTrustedList` - トラストリストの取得
- `testFetchTrustedListCaching` - キャッシュ動作
- `testFetchTrustedListHTTPError` - HTTPエラー処理

**Certificate-Based Search（AKI/SKI）テスト:**
- `testFindIssuerCertificateByAKISKI` - AKI/SKIマッチングによる発行者検索
- `testFindIssuerCertificateByDN` - DNマッチングによる発行者検索（フォールバック）
- `testFindIssuerCertificateNotFound` - 発行者証明書が見つからない場合
- `testFindIssuerCertificateWithConditionFilter` - 条件フィルタリング
- `testGetIssuerCertificatesForChain` - x5cチェーンの発行者証明書取得

### TrustedListModelsTests

**LoTEパーステスト:**
- `testParseLoTEDocument` - LoTEドキュメントのパース
- `testParseSchemeOperatorName` - 多言語スキームオペレータ名
- `testParseTrustedEntitiesList` - トラステッドエンティティリスト
- `testParseServiceInformation` - サービス情報
- `testParseServiceSupplyPoints` - ServiceSupplyPoints
- `testParseServiceDigitalIdentity` - デジタルアイデンティティ（X509証明書）
- `testServiceTypeConstants` - サービスタイプ定数
- `testServiceStatusConstants` - サービスステータス定数
- `testParseRealSampleData` - 実データのパーステスト

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
