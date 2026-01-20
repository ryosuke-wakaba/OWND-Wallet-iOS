# セットアップ・テスト・トラブルシューティング

[← README](./README.md)

## セットアップ

### 1. 証明書ファイルの配置

証明書ファイル（`.cer`, `.pem`, `.crt`）を `Certificates/` ディレクトリに配置：

```
Certificates/
├── root.cer           # ルートCA（自己署名）
├── intermediate1.cer  # 中間証明書1
└── intermediate2.cer  # 中間証明書2
```

### 2. Xcode Build Phaseの設定

証明書をアプリバンドルにコピーするRun Scriptを追加：

1. **TARGETS** → `tw2023_wallet` → **Build Phases**
2. **+** → **New Run Script Phase**
3. **Copy Bundle Resources**の前に配置
4. 以下のスクリプトを設定：

```bash
CERT_SOURCE="${SRCROOT}/Certificates"
CERT_DEST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Certificates"

mkdir -p "$CERT_DEST"

if [ -d "$CERT_SOURCE" ]; then
    cp "$CERT_SOURCE"/*.cer "$CERT_DEST/" 2>/dev/null || true
    echo "Certificates copied"
fi
```

5. **Build Settings** → **User Script Sandboxing** → **No**

### 3. 証明書のGit除外

証明書ファイルはコミットしない場合、`.gitignore`に追加：

```gitignore
Certificates/*.cer
Certificates/*.pem
Certificates/*.crt
```

---

## 起動時ログ

アプリ起動時に以下のログが出力されます：

```
TrustAnchorManager: ========== Loading certificates ==========
TrustAnchorManager: Resource path: /path/to/app
TrustAnchorManager: Certificates path: /path/to/app/Certificates
TrustAnchorManager: Certificates directory exists
TrustAnchorManager: Found 3 file(s) in directory
TrustAnchorManager: Found 3 certificate file(s): ["root.cer", "intermediate1.cer", "intermediate2.cer"]
TrustAnchorManager: --- Processing: root.cer ---
TrustAnchorManager:   File size: 2020 bytes
TrustAnchorManager:   Subject: Example Root CA
TrustAnchorManager:   Type: ROOT CA (self-signed)
TrustAnchorManager: --- Processing: intermediate1.cer ---
TrustAnchorManager:   File size: 2484 bytes
TrustAnchorManager:   Subject: Example Intermediate CA 1
TrustAnchorManager:   Type: INTERMEDIATE
TrustAnchorManager: ========== Summary ==========
TrustAnchorManager: Root CAs (anchors): 1
TrustAnchorManager:   [0] Example Root CA
TrustAnchorManager: Intermediates: 2
TrustAnchorManager:   [0] Example Intermediate CA 1
TrustAnchorManager:   [1] Example Intermediate CA 2
TrustAnchorManager: ==============================
```

---

## テスト

### テストファイル

| ファイル | 内容 |
|---------|------|
| `TrustAnchorManagerTests.swift` | TrustAnchorManagerの単体テスト |
| `X509ChainValidationTests.swift` | 証明書チェーン検証の統合テスト |

### 主なテストケース

#### TrustAnchorManagerTests

- `testSharedInstance` - シングルトンの確認
- `testAddAnchorCertificate` - ルートCA追加
- `testAddIntermediateCertificate` - 中間証明書追加
- `testSelfSignedCertificateDetection` - 自己署名検出
- `testNonSelfSignedCertificateDetection` - 非自己署名検出

#### X509ChainValidationTests

- `testValidCertificateChainWithCustomAnchors` - 単一チェーンの検証
- `testValidCertificateChainWithTwoTrustChains` - 複数チェーンの検証
- `testInvalidChainWithMissingIntermediate` - 中間証明書欠落時の検証失敗
- `testInvalidChainWithUnknownRoot` - 未知のルートCAでの検証失敗
- `testJwtWithX5CHeaderValidation` - JWT x5cヘッダーの検証

### テスト用証明書の生成

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

### 証明書有効期間の注意点

テスト証明書は `notValidBefore` を現在時刻の1時間前に設定：

```swift
let notBefore = Date().addingTimeInterval(-60 * 60)  // 1時間前
let notAfter = Date().addingTimeInterval(60 * 60 * 24 * 365)  // 1年後
```

これにより、タイミングによる「証明書が一時的に無効」エラーを回避します。

---

## トラブルシューティング

### 証明書が読み込まれない

1. Run Scriptが実行されているか確認（ビルドログ）
2. `User Script Sandboxing`が`No`になっているか確認
3. 証明書ファイルの形式（DER/PEM）を確認

### チェーン検証が失敗する

1. 起動時ログで証明書の読み込み状況を確認
2. 中間証明書が正しく登録されているか確認
3. 証明書の有効期限を確認

### テストが不安定

1. `notValidBefore`の設定を確認
2. テスト間の状態クリア（`setUp`/`tearDown`）を確認
