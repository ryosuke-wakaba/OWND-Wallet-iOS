# 作業依頼
## 機能追加
設定メニューにトラストリストセクションを追加して、「使用する」トグルを追加してください。
使用する設定の場合はパターンA、しない場合はパターンBで検証する様にしてください。

### パターンA: TrustedListから発行者証明書を取得

```
contextSearchInfos指定あり:
  1. TrustedListManagerがx5cの末尾証明書のAKI/SKIで発行者を検索
  2. 見つかった発行者証明書で使い捨てTrustAnchorManagerを生成
  3. 生成したTrustAnchorManagerで証明書チェーンを検証

JWT x5c Header: [Leaf Certificate]
              ↓
TrustedListManager: AKI/SKI検索 → [Issuer Certificate(s)]
              ↓
TrustAnchorManager.createInstance(): 使い捨てインスタンス生成
              ↓
SecTrust: Leaf → Issuer → Root ✓
```

### パターンB: シングルトンTrustAnchorManagerを使用

```
contextSearchInfos未指定またはTrustedList検索失敗:
  TrustAnchorManager.sharedの証明書で検証

JWT x5c Header: [Leaf Certificate]
              ↓
TrustAnchorManager.shared: [Intermediate1, Intermediate2] + [Root]
              ↓
SecTrust: Leaf → Intermediate → Root ✓
```
### 基本情報
- docs/architecture.md
- docs/development.md
- docs/features/settings
- docs/x509-certificate-chain-validation

### ブランチ
- 現在のブランチで対応して下さい。

### 作業ドキュメント
対応内容がまとまったら、まずは進捗が把握できるように作業ドキュメントを作成して下さい。

作業ドキュメントのパスとファイル名の形式

- docs/work/yyyy-mm-dd-xxx.md