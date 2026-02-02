# TrustAnchorManagerTests.swift

**パス**: `tw2023_walletTests/TrustAnchorManagerTests.swift`

**対応実装**: `tw2023_wallet/Signature/TrustAnchorManager.swift`

**概要**: TrustAnchorManager（信頼アンカー証明書管理）の単体テストです。

---

## 基本テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testSharedInstance` | シングルトンの確認 | シングルトンインスタンスが正しく取得できること |
| `testInitialState` | 初期状態の確認 | 初期状態が正しいこと |
| `testClearCertificates` | 証明書クリア | 全証明書がクリアされること |

---

## 証明書追加テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testAddAnchorCertificate` | ルートCA追加 | ルートCA証明書を追加できること |
| `testAddIntermediateCertificate` | 中間証明書追加 | 中間証明書を追加できること |
| `testAddAnchorCertificateFromDerData` | DERデータからルートCA追加 | DER形式データからルートCAを追加できること |
| `testAddIntermediateCertificateFromDerData` | DERデータから中間証明書追加 | DER形式データから中間証明書を追加できること |
| `testAddInvalidDerData` | 無効なDERデータの拒否 | 無効なDERデータが拒否されること |
| `testAllCertificates` | 全証明書取得 | 全証明書を取得できること |
| `testReload` | バンドルからの再読み込み | バンドルから証明書を再読み込みできること |

---

## 自己署名検出テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testSelfSignedCertificateDetection` | 自己署名証明書の検出 | 自己署名証明書を正しく検出できること |
| `testNonSelfSignedCertificateDetection` | 非自己署名証明書の検出 | 非自己署名証明書を正しく識別できること |

---

## 使い捨てインスタンステスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testCreateDisposableInstanceWithAdditionalCertificates` | 追加証明書付きインスタンス生成 | 追加証明書を含むインスタンスを生成できること |
| `testCreateDisposableInstanceInheritsSingletonCertificates` | シングルトン証明書の継承 | シングルトンの証明書を継承すること |
| `testDisposableInstanceDoesNotAffectSingleton` | シングルトンへの影響なし | 使い捨てインスタンスがシングルトンに影響しないこと |
| `testDisposableInstanceClassifiesCertificatesCorrectly` | 証明書の正しい分類 | 証明書が正しく分類されること |
| `testDisposableInstanceHasCustomAnchors` | カスタムアンカーの有無確認 | カスタムアンカーの有無を確認できること |
| `testDisposableInstanceWithoutAnchors` | アンカーなしインスタンス | アンカーなしのインスタンスが生成できること |
