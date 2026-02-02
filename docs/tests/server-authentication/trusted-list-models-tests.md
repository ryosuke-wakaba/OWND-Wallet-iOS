# TrustedListModelsTests.swift

**パス**: `tw2023_walletTests/TrustedListModelsTests.swift`

**対応実装**: `tw2023_wallet/Services/TrustedList/TrustedListModels.swift`

**概要**: LoTE（List of Trusted Entities）データモデルのパーステストです。

---

## LoTEパーステスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testParseLoTEDocument` | LoTEドキュメントのパース | LoTEドキュメント全体をパースできること |
| `testParseSchemeOperatorName` | 多言語スキームオペレータ名 | 多言語対応のスキームオペレータ名をパースできること |
| `testParseTrustedEntitiesList` | トラステッドエンティティリスト | TrustedEntitiesListをパースできること |
| `testParseServiceInformation` | サービス情報 | ServiceInformationをパースできること |
| `testParseServiceSupplyPoints` | ServiceSupplyPoints | ServiceSupplyPointsをパースできること |
| `testParseServiceDigitalIdentity` | デジタルアイデンティティ（X509証明書） | X509証明書を含むデジタルアイデンティティをパースできること |
| `testServiceTypeConstants` | サービスタイプ定数 | サービスタイプ定数が正しく定義されていること |
| `testServiceStatusConstants` | サービスステータス定数 | サービスステータス定数が正しく定義されていること |
| `testParseRealSampleData` | 実データのパーステスト | 実際のLoTEデータをパースできること |
