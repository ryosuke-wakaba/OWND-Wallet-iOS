# 作業ドキュメント: LoTE X509Certificates スキーマ修正

## 概要
ServiceDigitalIdentityのX509Certificatesの処理形式を公開スキーマ仕様 (pkiOb形式) に準拠するよう修正する。

## 変更対象ファイル

### 1. TrustedListModels.swift
- `PKIOb` 構造体を追加
- `ServiceDigitalIdentity.X509Certificates` の型を `[String]?` から `[PKIOb]?` に変更

### 2. TrustedListManager.swift
- `extractCertificates()` メソッドを `[PKIOb]?` 対応に更新
- `searchForIssuerInDocument()` メソッドを `pkiOb.val` から証明書を抽出するように更新
- `createCertificate()` メソッドをプリアンブル/ポストアンブル無しのbase64 DER対応に更新
- `convertPEMToX509Certificate()` → `convertToX509Certificate()` にリネームし、base64 DER優先で処理

### 3. テストファイル
- `TrustedListModelsTests.swift`: テストJSONデータをpkiOb形式に更新
- `TrustedListManagerTests.swift`: テストJSONデータをpkiOb形式に更新

## スキーマ変更

### 変更前 (誤スキーマ)
```json
"X509Certificates": {
  "type": "array",
  "items": {
    "type": "string"
  }
}
```

### 変更後 (公開スキーマ準拠)
```json
"X509Certificates": {
  "type": "array",
  "items": {
    "$ref": "#/definitions/pkiOb"
  }
}

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

## 実装状況

- [x] 作業ドキュメント作成
- [x] TrustedListModels.swift 更新
- [x] TrustedListManager.swift 更新
- [x] TrustedListModelsTests.swift 更新
- [x] TrustedListManagerTests.swift 更新
- [x] trustedlist.json 更新 (サンプルデータ)
- [x] テスト実行・確認 (全テスト成功)
