# VCIMetadataUtilTests.swift

**パス**: `tw2023_walletTests/VCIMetadataUtilTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/VCIMetadataUtil.swift`

**概要**: メタデータ処理のユーティリティ関数をテストします。

---

## テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testFindMatchingCredentialsJwtVc` | JWT VC検索 | jwt_vc_json形式のCredential Configurationを検索できること |
| `testFindMatchingCredentialsSdJwt` | SD-JWT検索 | dc+sd-jwt形式のCredential Configurationを検索できること |
| `testExtractDisplayByClaim` | Display抽出 | Credential Configurationからクレームごとのdisplay情報を抽出できること |
| `testSerializationAndDeserialization` | シリアライズ | DisplayByClaimMapのシリアライズ・デシリアライズが正しく動作すること |
