# LoTEサービスタイプ指定機能の実装

## ブランチ

`refactor/metadata-validation-cleanup`

## ステータス
- [x] 調査完了
- [x] Phase 1: 設定ファイル形式の変更
  - [x] TrustedListConfig.json形式の設計（JSON形式を採用）
  - [x] 設定モデルの実装（TrustedListConfig.swift）
- [x] Phase 2: TrustedListManagerの更新
  - [x] サービスタイプによる検索条件の追加（loteInfos引数）
  - [x] レガシーコードの削除（trustedListURLs, loadTrustedListURLs等）
  - [x] テストコード作成
- [x] Phase 3: X5CJWTVerifier/SignedMetadataValidatorの更新
  - [x] loteSearchInfos引数を追加
  - [x] テストコード更新
- [x] Phase 4: VCIMetadataClientの更新
  - [x] loteSearchInfos引数を追加
  - [x] テストコード更新
- [x] Phase 5: ViewModelの更新
  - [x] TrustedListConfigLoaderを使用してLoTE情報を読み込む
  - [x] VCIMetadataClientにLoTE情報を渡す
- [x] ビルド確認
- [x] 全テスト実行・確認
- [ ] レビュー

## 概要

VCIメタデータ取得時に、ビューモデルからLoTE（List of Trusted Entities）の情報を指定できるようにする。
具体的には「JPのトラストリストに含まれるOID4VCの発行サービス」という形式で検索条件を指定する。

### 要件サマリー

1. **設定ファイル形式の変更**: TrustedListURLs.txt → TrustedListConfig.yaml（YAML形式）
2. **サービスタイプの指定**: TrustedListManagerの検索条件にサービスタイプを外部から渡せるようにする
3. **複数LoTE対応**: VCIMetadataClientが複数のLoTEを受け付ける
4. **ドメイン知識の分離**: 設定ファイルの構造はビューモデルまでが知り、VCIMetadataClient以降はURLとサービスリストのペアで情報を受け取る

## 設計

### 設定ファイル形式

**現在（TrustedListURLs.txt）**:
```text
https://tl.eujp.ownd-project.com/api/trusted-list.jwt
```

**変更後（TrustedListConfig.json）**:
```json
{
  "lotes": {
    "jp-lote": {
      "url": "https://tl.eujp.ownd-project.com/api/trusted-list.jwt",
      "services": {
        "oid4vci": {
          "identifier": "http://tl.eujp.ownd-project.com/SvcType/OID4VCI/Issuance"
        },
        "oid4vp": {
          "identifier": "http://tl.eujp.ownd-project.com/SvcType/OID4VP/Verification"
        },
        "diw": {
          "identifier": "http://tl.eujp.ownd-project.com/SvcType/WalletSolution/WalletProvider"
        }
      }
    }
  }
}
```

※ 当初YAMLを検討したが、新規依存関係（Yams）の追加を避けるためJSON形式を採用

### データモデル設計

```swift
// TrustedListConfig.swift

/// LoTE設定ファイルのルート構造
struct TrustedListConfig: Codable {
    let lotes: [String: LoTEConfig]
}

/// 個別のLoTE設定
struct LoTEConfig: Codable {
    let url: String
    let services: [String: ServiceConfig]
}

/// サービス設定
struct ServiceConfig: Codable {
    let identifier: String
}

/// VCIMetadataClient等に渡すLoTE検索情報
struct LoTESearchInfo {
    let url: URL
    let serviceType: String?  // オプショナル: 指定がなければフィルタリングしない
}
```

### アーキテクチャ設計

```
┌─────────────────────────────────────────────────────────────────┐
│  CredentialOfferViewModel                                        │
│  - TrustedListConfig.yamlを読み込み                              │
│  - LoTESearchInfo配列を生成                                      │
│  - VCIMetadataClient/SignedMetadataValidatorに渡す               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  SignedMetadataValidator / X5CJWTVerifier                        │
│  - LoTESearchInfo配列を受け取る                                  │
│  - TrustedListManagerに検索を委譲                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│  TrustedListManager                                              │
│  - findService(serviceURL:, in: LoTESearchInfo)                  │
│  - サービスタイプがnilならフィルタリングしない                   │
│  - 指定されたLoTEのURLからのみ検索                               │
└─────────────────────────────────────────────────────────────────┘
```

### インターフェース変更

#### TrustedListManager

```swift
// 変更: loteInfosを受け取り、指定されたLoTEから検索
func findService(
    serviceURL: String,
    loteInfos: [LoTESearchInfo]
) async throws -> TrustedServiceResult

func getCertificates(
    forServiceURL serviceURL: String,
    loteInfos: [LoTESearchInfo]
) async throws -> [SecCertificate]
```

#### X5CJWTVerifier

```swift
// 変更: loteSearchInfosを受け取る
static func verifyJwtWithX5C(
    jwt: String,
    issuerURL: String?,
    loteSearchInfos: [LoTESearchInfo],
    verifyCertChain: Bool = true
) async -> Result<VerifiedX5CJwt, JWTVerificationError>
```

#### SignedMetadataValidator

```swift
// 変更: loteSearchInfosを受け取る
static func validate(
    jwt: String,
    expectedIssuerIdentifier: String,
    loteSearchInfos: [LoTESearchInfo]
) async -> Result<SignedMetadataValidationResult, SignedMetadataError>
```

#### VCIMetadataClient

```swift
// 変更: loteSearchInfosを受け取る
func fetchCredentialIssuerMetadata(
    from url: URL,
    issuerIdentifier: String,
    preferSignedMetadata: Bool = false,
    loteSearchInfos: [LoTESearchInfo],
    using session: URLSession = URLSession.shared
) async throws -> CredentialIssuerMetadata

func retrieveAllMetadata(
    issuer: String,
    preferSignedMetadata: Bool = false,
    loteSearchInfos: [LoTESearchInfo],
    using session: URLSession = URLSession.shared
) async throws -> Metadata
```

## 実装計画

### Phase 1: 設定ファイル形式の変更

#### 1.1 YAMLパーサーの追加

Swift Package ManagerにYamsを追加:

```swift
// Package.swift or Xcode project dependency
.package(url: "https://github.com/jpsim/Yams.git", from: "5.0.0")
```

#### 1.2 設定モデルの実装

**新規ファイル**: `tw2023_wallet/Services/TrustedList/TrustedListConfig.swift`

```swift
import Foundation

/// LoTE設定ファイルのルート構造
struct TrustedListConfig: Codable {
    let lotes: [String: LoTEConfig]
}

/// 個別のLoTE設定
struct LoTEConfig: Codable {
    let url: String
    let services: [String: ServiceConfig]
}

/// サービス設定
struct ServiceConfig: Codable {
    let identifier: String
}

/// VCIMetadataClient等に渡すLoTE検索情報
struct LoTESearchInfo {
    let url: URL
    let serviceType: String?  // nil = フィルタリングなし

    init(url: URL, serviceType: String? = nil) {
        self.url = url
        self.serviceType = serviceType
    }
}
```

#### 1.3 設定ファイルの作成

**新規ファイル**: `TrustedListConfig.yaml`

```yaml
lotes:
  jp-lote:
    url: https://tl.eujp.ownd-project.com/api/trusted-list.jwt
    services:
      oid4vci:
        identifier: http://tl.eujp.ownd-project.com/SvcType/OID4VCI/Issuance
      oid4vp:
        identifier: http://tl.eujp.ownd-project.com/SvcType/OID4VP/Verification
      diw:
        identifier: http://tl.eujp.ownd-project.com/SvcType/WalletSolution/WalletProvider
```

### Phase 2: TrustedListManagerの更新

#### 2.1 設定ファイル読み込み機能

```swift
// TrustedListManager.swift

/// Load trusted list configuration from YAML file
func loadTrustedListConfig() -> TrustedListConfig? {
    guard let resourcePath = Bundle.main.resourcePath else { return nil }
    let configPath = (resourcePath as NSString).appendingPathComponent("TrustedListConfig.yaml")

    guard FileManager.default.fileExists(atPath: configPath) else {
        // Fall back to legacy TrustedListURLs.txt
        return nil
    }

    do {
        let content = try String(contentsOfFile: configPath, encoding: .utf8)
        return try YAMLDecoder().decode(TrustedListConfig.self, from: content)
    } catch {
        print("TrustedListManager: [ERROR] Failed to parse config: \(error)")
        return nil
    }
}
```

#### 2.2 サービスタイプによる検索

```swift
// 新規メソッド
func findService(
    serviceURL: String,
    in loteInfo: LoTESearchInfo
) async throws -> TrustedServiceResult {
    let document = try await fetchTrustedList(from: loteInfo.url)

    if let result = searchInDocument(
        document,
        serviceURL: serviceURL,
        serviceType: loteInfo.serviceType  // nilならフィルタリングなし
    ) {
        return result
    }

    throw TrustedListError.serviceNotFound(
        serviceURL: serviceURL,
        serviceType: loteInfo.serviceType ?? "(any)"
    )
}

// searchInDocumentを更新
private func searchInDocument(
    _ document: LoTEDocument,
    serviceURL: String,
    serviceType: String?  // nilなら全サービスタイプを検索
) -> TrustedServiceResult? {
    // ...
    for service in entity.TrustedEntityServices {
        let info = service.ServiceInformation

        // サービスタイプが指定されていればフィルタリング
        if let requiredType = serviceType {
            guard info.ServiceTypeIdentifier == requiredType else {
                continue
            }
        }
        // ...
    }
}
```

### Phase 3: X5CJWTVerifier/SignedMetadataValidatorの更新

引数に`loteSearchInfos: [LoTESearchInfo]`を追加し、指定されたLoTEから証明書を取得する。

### Phase 4: ViewModelの更新

CredentialOfferViewModelで設定ファイルを読み込み、適切なLoTESearchInfoを生成してVCIMetadataClientに渡す。

## テスト計画

### 新規テスト

| テストケース | 説明 |
|-------------|------|
| `testLoadTrustedListConfig_validYAML` | 有効なYAML設定ファイルの読み込み |
| `testLoadTrustedListConfig_fallbackToLegacy` | YAML不在時のレガシーファイルへのフォールバック |
| `testFindService_withServiceType` | サービスタイプ指定での検索 |
| `testFindService_withoutServiceType` | サービスタイプなしでの検索（フィルタリングなし） |
| `testFindService_inSpecificLoTE` | 特定のLoTEからの検索 |

## 依存関係

なし（JSON形式を採用したため新規依存関係は不要）

## 参考ドキュメント

- [docs/features/credential-issuance/metadata-verification.md](../features/credential-issuance/metadata-verification.md)
- [2026-01-08-metadata-validation-refactoring.md](./2026-01-08-metadata-validation-refactoring.md)
- [ETSI TS 119 602 - Service type identifier](https://www.etsi.org/deliver/etsi_ts/119600_119699/119602/)
