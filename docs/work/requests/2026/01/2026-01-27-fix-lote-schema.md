# 作業依頼
## 概要
ServiceDigitalIdentityのX509Certificatesの処理形式を公開スキーマ仕様に準拠するよう修正する。

また、ServiceDigitalIdentityに含まれる証明書にはプリアンブルとポストアンブルは含まれない想定の処理に修正する。

### 誤スキーマ

```json
"X509Certificates": {
  "type": "array",
  "items": {
    "type": "string",
    "contentEncoding": "base64",
    "description": "Base64 encoded X.509 certificate per ETSI TS 119 602 clause 6.6.3.1"
  },
  "minItems": 1
}
```

### 公開スキーマ
```json
"X509Certificates": {
  "type": "array",
  "items": {
    "$ref": "#/definitions/pkiOb"
  },
  "minItems": 1
}
```

`pkiOb`:
```json
"pkiOb": {
  "type": "object",
  "properties": {
    "encoding": { "type": "string", "format": "uri" },
    "specRef": { "type": "string" },
    "val": { "type": "string", "contentEncoding": "base64" }
  },
  "required": ["val"],
  "additionalProperties": false
}
```

### 基本情報
- docs/architecture.md
- docs/development.md
- docs/x509-certificate-chain-validation

### ブランチ
- 新しいブランチで対応して下さい。
    - 派生元ブランチ: 現在のブランチ

### 作業ドキュメント
対応内容がまとまったら、まずは進捗が把握できるように作業ドキュメントを作成して下さい。

作業ドキュメントのパスとファイル名の形式

- docs/work/yyyy-mm-dd-xxx.md