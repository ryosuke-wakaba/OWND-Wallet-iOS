# IssuerDetail.swift 調査レポート

## 概要
IssuerDetail.swiftのUI実装状況と、JWTクレデンシャルの`iss`値を表示する適切な場所についての調査結果。

## 現在のUI実装状況

### IssuerDetail.swift (tw2023_wallet/Feature/IssuerDetail/IssuerDetail.swift)

**表示項目:**
1. **発行者名** (28-34行目)
   - `issuerMetadata?.display?[0].name` から取得
   - 取得できない場合は "Unknown Issuer Name" を表示

2. **証明書情報** (37-68行目) - X509証明書がある場合のみ表示
   - 認証バッジ: "verified by [組織名]"
   - 所在地: street, locality, state
   - 国: country
   - ドメイン: domain

### IssuerDetailViewModel.swift (tw2023_wallet/Feature/IssuerDetail/ViewModels/IssuerDetailViewModel.swift)

**主な機能:**
- `loadData()`: クレデンシャルからX509証明書情報を読み込み
- X509証明書の検証と表示情報の抽出（x5cまたはx5uヘッダーから）

## JWTの`iss`クレームに関する現状

### データフロー

```
JWT credential
    ↓ JWTParsingUtil.extractInfoFromJwt()
Datastore_CredentialData.iss (保存時に抽出)
    ↓ CredentialDataManager.saveCredentialData()
CoreData (暗号化して保存)
    ↓ toCredential()
Credential.issuer ← metaData.credentialIssuer (※JWTのissではない)
```

### 重要な発見

**`iss`の値が2種類存在する:**

| 項目 | 値の取得元 | 現在の使用箇所 |
|------|-----------|--------------|
| `metaData.credentialIssuer` | OpenID4VCIメタデータ | `Credential.issuer`に設定 |
| JWT payload内の`iss` | JWT自体 | `Datastore_CredentialData.iss`に保存されているが、`Credential`モデルに渡されていない |

**関連コード箇所:**
- `CredentialStorageService.swift:77` - JWTから`iss`を抽出して保存
- `CredentialDataManager.swift:163` - `Credential.issuer`は`metaData.credentialIssuer`から設定
- `JWTParsingUtil.swift:36` - JWT payloadから`iss`を抽出するユーティリティ

## `iss`値表示に適切な場所

### 推奨: IssuerDetail.swift

**理由:**
- 発行者に関する詳細情報を表示する画面として適切
- 既に証明書関連の技術的情報（ドメイン等）を表示している
- ユーザーが発行者の技術的な識別子を確認したい場合の適切な場所

### 実装方法の提案

**方法1: IssuerDetailViewModelで`iss`を取得して表示**
```swift
// IssuerDetailViewModel.swift
@Observable
class IssuerDetailViewModel {
    var certInfo: CertificateInfo? = nil
    var jwtIssuer: String? = nil  // 追加

    func loadData(credential: Credential?) async {
        if let credential = credential {
            // JWTからissを抽出
            let format = credential.format
            let credentialFormat = CredentialFormat(formatString: format)
            if credentialFormat?.isSDJWT == true {
                let info = JWTParsingUtil.extractSDJwtInfo(
                    credential: credential.payload, format: format)
                jwtIssuer = info["iss"] as? String
            } else {
                let info = JWTParsingUtil.extractInfoFromJwt(
                    jwt: credential.payload, format: format)
                jwtIssuer = info["iss"] as? String
            }
            // ...existing code...
        }
    }
}
```

**方法2: Credentialモデルに`jwtIssuer`フィールドを追加**
- `Credential.swift`に新しいフィールド追加
- `CredentialDataManager.toCredential()`で`Datastore_CredentialData.iss`の値を設定

### UIへの追加案

```swift
// IssuerDetail.swift内
if let jwtIssuer = viewModel.jwtIssuer {
    VStack(alignment: .leading, spacing: 0) {
        Text("issuer_identifier").modifier(SubHeadLineGray())
        Text(jwtIssuer).modifier(BodyBlack())
    }
    .padding(.vertical, 6)
}
```

## まとめ

- IssuerDetail.swiftは発行者情報を表示するビューとして適切に実装されている
- JWTの`iss`値は保存されているが、現在UIに表示されていない
- `iss`値を表示する最適な場所は**IssuerDetail.swift**
- 実装には`IssuerDetailViewModel`の拡張またはCredentialモデルの修正が必要

---

## 実装内容

### 変更ファイル

1. **IssuerDetailViewModel.swift** (`tw2023_wallet/Feature/IssuerDetail/ViewModels/IssuerDetailViewModel.swift`)
   - `jwtIssuer: String?` プロパティを追加
   - `extractJwtIssuer(credential:)` メソッドを追加
   - `loadData()` から `extractJwtIssuer()` を呼び出し

2. **IssuerDetail.swift** (`tw2023_wallet/Feature/IssuerDetail/IssuerDetail.swift`)
   - `viewModel.jwtIssuer` が存在する場合に「発行者識別子」セクションを表示

3. **Localizable.xcstrings** (`tw2023_wallet/Localizable.xcstrings`)
   - `issuer_identifier` キーを追加（英語: "Issuer Identifier", 日本語: "発行者識別子"）

### ブランチ

- `feature/display-jwt-iss`

### ビルド確認

- ✅ ビルド成功
