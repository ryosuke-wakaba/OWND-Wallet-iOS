# X509証明書からの提供先情報表示

## 概要

クライアントメタデータに提供先情報（clientName等）がない場合、Request ObjectのX5C証明書から提供先情報を取得して表示する機能を実装する。

## 背景

`SharingRequest`画面でクレデンシャル提供先の情報を表示するが、以下のようなケースで提供先情報が表示できない：

- `clientMetadata.clientName`がnil
- `clientMetadata.logoUri`がnil
- `client_id`が`x509_san_dns:`または`x509_hash:`プレフィックスを持つ場合

これらのケースでは、Request ObjectのJWTヘッダーに含まれるx5c証明書チェーンから情報を取得できる可能性がある。

## 対象ファイル

- `tw2023_wallet/Utils/CertificateUtil.swift` - ヘルパー関数追加
- `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestViewModel.swift` - x509スキーム時の証明書情報取得
- `tw2023_wallet/Feature/ShareCredential/Views/SharingRequest.swift` - タイトル表示・ProvideAge削除
- `tw2023_wallet/Feature/ShareCredential/Views/RecipientOrgInfo.swift` - 表示制御の改善

## X.509証明書から取得可能な情報

| フィールド | OID | 用途 |
|-----------|-----|------|
| Common Name (CN) | 2.5.4.3 | ドメイン名 |
| Organization (O) | 2.5.4.10 | 組織名 |
| Locality (L) | 2.5.4.7 | 市区町村 |
| State (ST) | 2.5.4.8 | 都道府県 |
| Country (C) | 2.5.4.6 | 国 |
| Issuer | - | 発行者情報 |

## 実装計画

### タスク一覧

- [x] 1. JWTのx5cから CertificateInfo を取得するヘルパー関数を追加
- [x] 2. SharingRequestViewModel.loadData でx509スキーム時に証明書情報を取得
- [x] 3. RecipientOrgInfo の表示制御を改善（certificateInfoがない場合の非表示処理）
- [x] 4. ビルド確認
- [x] 5. 追加課題対応（DCQL ID削除、ProvideAge削除、項目の条件付き表示）

## 実装詳細

### 1. ヘルパー関数の追加

`CertificateUtil.swift`に以下の関数を追加：

```swift
/// Extract CertificateInfo from JWT's x5c header
/// - Parameter jwt: JWT string containing x5c header
/// - Returns: CertificateInfo from the leaf certificate, or nil if extraction fails
func extractCertificateInfoFromJwt(jwt: String) -> CertificateInfo?
```

### 2. SharingRequestViewModel の修正

`loadData`メソッドのx509スキーム処理部分を修正：

```swift
if clientId.hasPrefix("x509_san_dns:") || clientId.hasPrefix("x509_hash:") {
    // For x509 schemes, certificate is verified via JWT x5c header
    verified = processedRequestData.requestIsSigned
    // Extract certificate info from x5c header for display
    cert = extractCertificateInfoFromJwt(jwt: processedRequestData.requestObjectJwt)
} else {
```

### 3. SharingRequest の修正

- タイトルセクションからDCQLクエリーID表示を削除
- 証明書のOrganizationまたはclientNameを表示するように変更
- ProvideAgeコンポーネントの呼び出しを削除

### 4. RecipientOrgInfo の表示制御

以下の改善を実施：

1. バリデーションヘルパー関数を追加:
   - `isValidDomain`: ドメイン名の妥当性チェック（ドットを含み、スペースを含まない）
   - `isValidUrl`: URL形式のチェック
   - `isValidCountry`: 国コードの妥当性チェック

2. 各項目を条件付きで表示:
   - **ドメイン**: 有効なドメイン形式の場合のみ表示
   - **所在地**: state/localityが存在する場合のみ表示
   - **国名**: 有効な国コード/名称の場合のみ表示
   - **連絡先**: 有効なドメインまたはメールアドレスがある場合のみ表示
   - **利用規約/プライバシーポリシー**: 有効なURLの場合のみ表示

3. Force unwrap の削除 - nilの場合のクラッシュを防止

## 進捗

| 日時 | 作業内容 | 状態 |
|------|----------|------|
| 2025-12-08 | 調査・計画作成 | 完了 |
| 2025-12-08 | ヘルパー関数追加 (`extractCertificateInfoFromJwt`) | 完了 |
| 2025-12-08 | SharingRequestViewModel修正 | 完了 |
| 2025-12-08 | RecipientOrgInfo表示制御改善 | 完了 |
| 2025-12-08 | ビルド確認 | 完了 |
| 2025-12-08 | DCQLクエリーID表示削除 | 完了 |
| 2025-12-08 | ProvideAge表示削除 | 完了 |
| 2025-12-08 | RecipientOrgInfo各項目の条件付き表示 | 完了 |
| 2025-12-08 | 利用規約/プライバシーポリシーの条件付き表示 | 完了 |

## 参考

- `docs/features/credential-presentation.md`
- `tw2023_wallet/Utils/CertificateUtil.swift`
- `tw2023_wallet/Signature/JWTUtil.swift`
