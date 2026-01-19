# TrustedList証明書検索方法の改修

## 概要

TrustedListの構成方法の理解が誤っていたことが判明したため、証明書検索方法を改修する。

### 問題点

- **現状**: サービスURLでサービスを特定し、そのサービスの証明書を取得
- **正しい理解**: リーフ証明書を発行した主体がリストに含まれる。リーフ証明書の発行者情報とリストの上位証明書のサブジェクトを一致させる方法が適切

## 改修内容

### 1. 設定ファイル構造の変更

**Before (TrustedListConfig.json)**:
```json
{
  "lotes": {
    "jp-lote": {
      "url": "https://tl.eujp.ownd-project.com/api/trusted-list.jwt",
      "services": {
        "oid4vci": {
          "identifier": "http://tl.eujp.ownd-project.com/TrstSvc/Svctype/LearningCredential/Issuer"
        }
      }
    }
  }
}
```

**After**:
```json
{
  "lotes": {
    "jp-lote": {
      "url": "https://tl.eujp.ownd-project.com/api/trusted-list.jwt",
      "context": {
        "AccessCertificateVerification": {
          "condition": {
            "loteType": "https://tl.eujp.ownd-project.com/LoTELType/JPWRPACProvidersList",
            "serviceTypeIdentifier": "http://tl.eujp.ownd-project.com/19602/SvcType/WRPAC/Issuance",
            "status": "http://tl.eujp.ownd-project.com/TrstSvc/TrustedList/Svcstatus/granted"
          }
        }
      }
    }
  }
}
```

### 2. 証明書検索方法の変更

- **第一優先**: AKI (Authority Key Identifier) と SKI (Subject Key Identifier) の一致で発行者を特定
- **フォールバック**: AKI/SKIがない場合は Distinguished Name (DN) による一致で確認

### 検索フロー

```
1. リーフ証明書からAKIを取得
2. TrustedListの各サービスから証明書を取得
3. 各証明書のSKIを取得
4. AKI == SKI なら発行者として特定
5. AKI/SKIがない場合:
   - リーフ証明書のIssuer DNを取得
   - サービス証明書のSubject DNと比較
   - 一致すれば発行者として特定
```

## 影響範囲

### 変更対象ファイル

| ファイル | 変更内容 |
|---------|---------|
| `TrustedListConfig.json` | 設定構造を`context`ベースに変更 |
| `TrustedListConfig.swift` | 新しい設定構造に対応するモデルとローダー |
| `TrustedListManager.swift` | 証明書ベースの検索メソッド追加 |
| `TrustedListModels.swift` | LoTETypeフィールドへの対応確認 |
| `X509CertificateOperations.swift` | AKI/SKI抽出メソッド追加 |
| `X5CJWTVerifier.swift` | 新しい検索メソッドを使用するよう変更 |

### 呼び出し元

- `CredentialOfferViewModel.swift`
- `OpenIdProvider.swift`
- `SignedMetadataValidator.swift`

## 実装計画

### Phase 1: 基盤整備

1. [x] コードベース調査
2. [x] X509CertificateOperationsにAKI/SKI抽出メソッドを追加
3. [x] DN比較メソッドの追加

### Phase 2: 設定ファイル改修

1. [x] TrustedListConfig.swiftのモデル更新
2. [x] TrustedListConfig.jsonの構造変更
3. [x] TrustedListConfigLoaderの更新

### Phase 3: 検索ロジック改修

1. [x] TrustedListManagerに証明書ベースの検索メソッド追加
2. [x] 既存のURLベース検索との互換性維持（deprecatedとして残す）

### Phase 4: 統合とテスト

1. [x] X5CJWTVerifierの更新
2. [x] 単体テスト作成・実行
3. [ ] 統合テスト（実際のトラストリストとの連携テスト）

## 技術詳細

### AKI/SKI抽出

X.509証明書の拡張フィールド:
- **Authority Key Identifier (AKI)**: OID 2.5.29.35
- **Subject Key Identifier (SKI)**: OID 2.5.29.14

Swiftでの実装方針:
- `X509`ライブラリの`Certificate.Extensions`を使用
- または`Security.framework`の`SecCertificateCopyValues`を使用

### DN比較

Distinguished Nameの比較は:
- 正規化して比較（空白、大文字小文字の違いを吸収）
- RDN (Relative Distinguished Name) の順序は問わない

## 実装済みの変更

### 変更されたファイル

| ファイル | 変更内容 |
|---------|---------|
| `TrustedListConfig.json` | 新しい`context`構造を追加（旧`services`も互換性のため残す） |
| `TrustedListConfig.swift` | `LoTEContextSearchInfo`, `ContextConfig`, `ConditionConfig`を追加、新しいローダーメソッド `createContextSearchInfos()` を追加 |
| `TrustedListManager.swift` | `findIssuerCertificate()`, `getIssuerCertificatesForChain()` など証明書ベースの検索メソッドを追加 |
| `X509CertificateOperations.swift` | AKI/SKI抽出メソッド、DN比較メソッド、発行者検索メソッドを追加 |
| `X5CJWTVerifier.swift` | 新しい `verifyJwtWithX5CUsingCertificateSearch()` メソッドを追加 |
| `X509CertificateOperationsTest.swift` | AKI/SKI関連のテストを追加 |

### 新しいAPI

```swift
// 1. 設定ファイルからコンテキストベースの検索情報を取得
let searchInfos = TrustedListConfigLoader.createContextSearchInfos([
    (loteName: "jp-lote", contextName: "AccessCertificateVerification")
])

// 2. 証明書ベースの発行者検索（AKI/SKI → DN フォールバック）
let result = try await TrustedListManager.shared.findIssuerCertificate(
    for: leafCertificate,
    searchInfos: searchInfos
)

// 3. JWT検証（証明書ベースの検索を使用）
let verifyResult = await X5CJWTVerifier.verifyJwtWithX5CUsingCertificateSearch(
    jwt: jwtString,
    contextSearchInfos: searchInfos
)
```

### 後方互換性

旧APIは`@available(*, deprecated)`としてマークされていますが、引き続き使用可能です。

## 参考資料

- RFC 5280: Internet X.509 PKI Certificate and CRL Profile
- ETSI TS 119 612: Trusted Lists
- [apple/swift-certificates](https://github.com/apple/swift-certificates) - AKI/SKI実装
- 作業依頼: `docs/work/requests/2026-01-19-fix-spec-misundarstand.md`
