# カスタムトラストアンカー機能の拡張 - トラストリスト対応

## ステータス
- [x] 調査完了
- [x] 設計案レビュー (案A採用)
- [x] 実装
- [x] テスト作成
- [x] VCIMetadataClientへの統合
- [x] Xcodeプロジェクトへのファイル追加
- [x] ビルド確認
- [x] 動作確認完了
- [ ] レビュー

## TODO（将来対応）
- [ ] NextUpdateフィールドに基づくキャッシュTTLの実装
- [ ] ServiceTypeIdentifierによる検索条件の再有効化

## 概要

TrustAnchorManagerに、ETSI TS 119 602 (LoTE: List of Trusted Entities) 形式のトラストリストから証明書を取得・検証する機能を追加する。

## 実装済みファイル

| ファイル | 責務 | 状態 |
|---------|------|------|
| `tw2023_wallet/Services/TrustedList/TrustedListModels.swift` | LoTE形式のデータモデル | 新規作成 |
| `tw2023_wallet/Services/TrustedList/TrustedListManager.swift` | トラストリストのフェッチ・検索（JSON/JWT両対応） | 新規作成 |
| `tw2023_wallet/Signature/TrustAnchorManager.swift` | 使い捨てインスタンス生成機能追加 | 変更 |
| `tw2023_wallet/Signature/SignatureUtil.swift` | TrustAnchorManagerインスタンス指定オーバーロード追加 | 変更 |
| `tw2023_wallet/Signature/JWTUtil.swift` | TrustedList対応async版verifyJwtByX5C追加 | 変更 |
| `tw2023_wallet/Services/OID/VCI/SignedMetadataValidator.swift` | TrustedList対応async版validate追加 | 変更 |
| `tw2023_wallet/Services/OID/VCI/VCIMetadataClient.swift` | async版SignedMetadataValidator使用 | 変更 |
| `tw2023_wallet.xcodeproj/project.pbxproj` | Copy Certificatesスクリプト修正（dest先クリア） | 変更 |
| `.gitignore` | TrustedListURLs.txt除外追加 | 変更 |

## 暫定対応事項

### キャッシュ無効化
トラストリストのキャッシュは一時的に無効化。将来的にはNextUpdateフィールドに基づくTTL実装が望ましい。

### ServiceTypeIdentifier検索条件の無効化
サービスタイプによる検索条件は一時的にコメントアウト。ServiceSupplyPointsとServiceStatusのみで検索。

## 要件

### 実現したい振る舞い

1. **サービスURLの取得**: OID4VCIの発行者識別子 (例: `https://issuer.example.com`)
2. **リスト内検索**: trusted-list.jsonをパースし、以下の条件でマッチ:
   - ServiceTypeIdentifier: `http://example.com/SvcType/CredentialIssuance`
   - ServiceSupplyPoints: 発行者URLが含まれているか
3. **公開鍵の取得**: マッチしたエントリの`ServiceDigitalIdentity`から証明書を取得
4. **検証**: 取得した証明書でSigned Metadata/JWSを検証

### 設定要件

- ビルド時にトラストリストURLをウォレットに記憶
- URLの指定方法: コミット対象外のテキストファイル

### 追加要件

- **使い捨てインスタンスはシングルトンの証明書を引き継ぐ**: `TrustAnchorManager.createInstance()` で生成されるインスタンスは、シングルトン (`TrustAnchorManager.shared`) が保持するバンドル由来の証明書も含む

## 実装詳細

### TrustedListModels.swift

ETSI TS 119 602に準拠したデータモデル:

```swift
// LoTE (List of Trusted Entities) root structure
struct LoTEDocument: Codable {
    let LoTE: LoTE
}

struct LoTE: Codable {
    let ListAndSchemeInformation: ListAndSchemeInformation
    let TrustedEntitiesList: [TrustedEntity]
}

struct ServiceInformation: Codable {
    let ServiceName: [LocalizedString]
    let ServiceDigitalIdentity: ServiceDigitalIdentity
    let ServiceTypeIdentifier: String
    let ServiceStatus: String
    let StatusStartingTime: String
    let ServiceSupplyPoints: [URIValue]?
}
```

### TrustedListManager.swift

```swift
class TrustedListManager {
    static let shared = TrustedListManager()

    /// トラストリストをフェッチ（JSON/JWT両形式対応）
    func fetchTrustedList(from url: URL) async throws -> LoTEDocument

    /// 発行者URLに対応するサービスエントリを検索
    func findService(
        issuerURL: String,
        serviceType: String = TrustedListServiceType.credentialIssuance
    ) async throws -> TrustedServiceResult

    /// 発行者URLから証明書を取得
    func getCertificates(
        forIssuerURL issuerURL: String,
        serviceType: String = TrustedListServiceType.credentialIssuance
    ) async throws -> [SecCertificate]
}
```

**対応フォーマット:**
- JSON形式: `application/json`
- JWT形式: `.jwt`拡張子または`eyJ`で始まるレスポンス（ペイロードを自動抽出）

### TrustAnchorManager の拡張

使い捨てインスタンス生成（シングルトンの証明書を引き継ぐ）:

```swift
/// 追加の証明書を持つ使い捨てインスタンスを生成
/// シングルトンの証明書 + 追加証明書の両方を含む
static func createInstance(
    withAdditionalCertificates additionalCertificates: [SecCertificate]
) -> TrustAnchorManager

/// 発行者URLからトラストリストの証明書を取得して使い捨てインスタンスを生成
static func createInstance(
    forIssuerURL issuerURL: String,
    serviceType: String = TrustedListServiceType.credentialIssuance
) async throws -> TrustAnchorManager
```

### SignatureUtil の拡張

TrustAnchorManagerインスタンスを指定できるオーバーロード:

```swift
/// 指定したTrustAnchorManagerインスタンスで証明書チェーンを検証
static func validateCertificateChainWithCustomAnchors(
    certificates: [SecCertificate],
    trustAnchorManager: TrustAnchorManager,
    useCustomAnchorsOnly: Bool = false
) -> Result<Void, CertificateValidationError>
```

## 使用フロー

```
1. アプリ起動時
   └─ TrustedListManager.loadTrustedListURLs()
      └─ バンドルからURLリストを読み込み

2. 発行者署名検証時
   ├─ TrustAnchorManager.createInstance(forIssuerURL: "https://issuer.example.com")
   │   ├─ TrustedListManager.getCertificates() を内部で呼び出し
   │   ├─ シングルトンの証明書をコピー
   │   └─ トラストリストの証明書を追加
   │
   └─ SignatureUtil.validateCertificateChainWithCustomAnchors(
        certificates: [leafCert],
        trustAnchorManager: disposableManager
      )
```

## セットアップ手順

### 1. TrustedListURLs.txt の作成

プロジェクトルートに `TrustedListURLs.txt` を作成:

```text
# Trusted List URLs (one per line)
# Lines starting with # are comments
# JSON形式とJWT形式の両方に対応
https://example.jp/trusted-list.json
https://example.jp/trusted-list.jwt
```

### 2. Xcode Build Phase の設定

1. **TARGETS** → `tw2023_wallet` → **Build Phases**
2. **+** → **New Run Script Phase**
3. 名前を「Copy Trusted List URLs」に変更
4. 以下のスクリプトを設定:

```bash
# Copy TrustedListURLs.txt to app bundle
URLS_SOURCE="${SRCROOT}/TrustedListURLs.txt"
URLS_DEST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/TrustedListURLs.txt"

if [ -f "$URLS_SOURCE" ]; then
    cp "$URLS_SOURCE" "$URLS_DEST"
    echo "TrustedListURLs.txt copied to bundle"
else
    echo "TrustedListURLs.txt not found (optional)"
fi
```

### 3. Xcodeプロジェクトへのファイル追加

新規作成したSwiftファイルをXcodeプロジェクトに追加:

1. `tw2023_wallet/Services/TrustedList/` グループを作成
2. 以下のファイルを追加:
   - `TrustedListModels.swift`
   - `TrustedListManager.swift`

### 4. Copy Certificates スクリプトの動作

「Copy Certificates」Build Phaseスクリプトは、ビルド時にdestディレクトリをクリアしてからソースの証明書をコピーする。これにより、古い証明書が残らずトラストリストからの証明書のみでテストが可能。

## サンプルデータ構造 (trustedlist.json)

```json
{
  "LoTE": {
    "TrustedEntitiesList": [
      {
        "TrustedEntityInformation": {
          "TEName": [{ "lang": "en", "value": "Foo University" }]
        },
        "TrustedEntityServices": [
          {
            "ServiceInformation": {
              "ServiceTypeIdentifier": "http://example.com/SvcType/CredentialIssuance",
              "ServiceSupplyPoints": [
                { "uriValue": "https://issuer.eujp.ownd-project.com" }
              ],
              "ServiceDigitalIdentity": {
                "X509Certificates": [
                  "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"
                ]
              }
            }
          }
        ]
      }
    ]
  }
}
```

## 関連ファイル

- `tw2023_wallet/Signature/TrustAnchorManager.swift`
- `tw2023_wallet/Signature/SignatureUtil.swift`
- `tw2023_wallet/Services/TrustedList/TrustedListModels.swift`
- `tw2023_wallet/Services/TrustedList/TrustedListManager.swift`
- `docs/x509-certificate-chain-validation.md`
- `trustedlist.json` (サンプル)

## 参考

- [ETSI TS 119 602](https://www.etsi.org/deliver/etsi_ts/119600_119699/119602/01.01.01_60/ts_119602v010101p.pdf)
