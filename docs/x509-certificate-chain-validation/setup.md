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

### 2. TrustedListConfig.jsonの配置

トラストリスト（LoTE）の設定ファイルをプロジェクトルートに配置：

```
TrustedListConfig.json
```

設定ファイルの形式については [TrustedListConfig.swift](../../tw2023_wallet/Services/TrustedList/TrustedListConfig.swift) を参照してください。

### 3. Xcode Build Phaseの設定

証明書とTrustedListConfig.jsonをアプリバンドルにコピーするRun Scriptを追加します。

1. **TARGETS** → `tw2023_wallet` → **Build Phases**
2. **+** → **New Run Script Phase**
3. **Copy Bundle Resources**の前に配置
4. **Build Settings** → **User Script Sandboxing** → **No**

#### Copy Certificates

```bash
# Copy certificates from certs-pub if they exist
echo "SRCROOT: ${SRCROOT}"
echo "Looking for: ${SRCROOT}/Certificates"
ls -la "${SRCROOT}/Certificates" || echo "Directory not found"
CERT_SOURCE="${SRCROOT}/Certificates"
CERT_DEST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/Certificates"

# Clear destination directory first
rm -rf "$CERT_DEST"

if [ -d "$CERT_SOURCE" ]; then
    mkdir -p "$CERT_DEST"
    cp -R "$CERT_SOURCE"/*.cer "$CERT_DEST/" 2>/dev/null || true
    cp -R "$CERT_SOURCE"/*.pem "$CERT_DEST/" 2>/dev/null || true
    cp -R "$CERT_SOURCE"/*.crt "$CERT_DEST/" 2>/dev/null || true
    echo "Certificates copied from $CERT_SOURCE to $CERT_DEST"
else
    echo "No certificates directory found at $CERT_SOURCE (skipping)"
fi
```

#### Copy Trusted List Config

```bash
# Copy Trusted List Config
CONFIG_SOURCE="${SRCROOT}/TrustedListConfig.json"
CONFIG_DEST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/TrustedListConfig.json"

if [ -f "$CONFIG_SOURCE" ]; then
    cp "$CONFIG_SOURCE" "$CONFIG_DEST"
    echo "TrustedListConfig.json copied to bundle"
else
    echo "TrustedListConfig.json not found (optional)"
fi
```

### 4. Git除外設定

証明書ファイルや設定ファイルをコミットしない場合、`.gitignore`に追加：

```gitignore
Certificates/*.cer
Certificates/*.pem
Certificates/*.crt
TrustedListConfig.json
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

テストについては [テスト](./testing.md) を参照してください。

---

## トラブルシューティング

### 証明書が読み込まれない

1. Run Scriptが実行されているか確認（ビルドログ）
2. `User Script Sandboxing`が`No`になっているか確認
3. 証明書ファイルの形式（DER/PEM）を確認

### TrustedListConfig.jsonが読み込まれない

1. ビルドログで「TrustedListConfig.json copied to bundle」が出力されているか確認
2. ファイルがプロジェクトルートに存在するか確認
3. JSONの形式が正しいか確認

### チェーン検証が失敗する

1. 起動時ログで証明書の読み込み状況を確認
2. 中間証明書が正しく登録されているか確認
3. 証明書の有効期限を確認

テスト関連のトラブルシューティングは [テスト](./testing.md#トラブルシューティング) を参照してください。
