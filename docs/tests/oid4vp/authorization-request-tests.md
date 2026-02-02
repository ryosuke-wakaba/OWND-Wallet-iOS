# AuthorizationRquestTests.swift

**パス**: `tw2023_walletTests/AuthorizationRquestTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/AuthorizationRequest.swift`

**概要**: OID4VPの認可リクエスト処理をテストします。

> **Note**: PresentationDefinition（旧PEX仕様）からDCQLへの移行が実施されたため、PEX関連テストは削除済みです。

---

## テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeUriAsJsonWithVariousTypes` | URIパラメータデコード | 各種データ型のURIパラメータを正しくデコードすること |
| `testUriDecodingAndStructConversion` | URI→構造体変換 | URIをデコードして構造体に正しく変換すること |
| `testProcessRequestObject` | Request Object処理 | JWTフォーマットのRequest Objectを正しく処理すること |
| `testProcessClientMetadata` | Client Metadata処理 | Client MetadataをフェッチしJWKSを正しく処理すること |
| `testProcessClientMetadataFromQueryParameter` | クエリパラメータからのMetadata | クエリパラメータからClient Metadataを正しく解析すること |
| `testProcessClientMetadataUriFromQueryParameter` | Client Metadata URI処理 | Client Metadata URIを正しく処理すること |
| `testFetchAndConvertJWK` | JWK取得・変換 | JWK（JSON Web Key）を正しく取得・変換すること |
| `testExtractKeyIdFromJwt` | Key ID抽出 | JWTから正しくKey IDを抽出すること |
