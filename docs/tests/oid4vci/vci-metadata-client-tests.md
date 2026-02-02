# VCIMetadataClientTests.swift

**パス**: `tw2023_walletTests/VCIMetadataClientTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/VCIMetadataClient.swift`

**概要**: メタデータエンドポイントからのデータ取得をテストします。

---

## テストクラス: CredentialIssuerMetadataTests

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testFetchCredentialIssuerMetadata` | Issuerメタデータ取得 | `/.well-known/openid-credential-issuer`からメタデータを取得できること |
| `testFetchAuthServerMetadata` | 認可サーバーメタデータ取得 | `/.well-known/oauth-authorization-server`からメタデータを取得できること |
| `testRetrieveAllMetadata` | 全メタデータ取得 | IssuerメタデータとAuthサーバーメタデータを同時に取得できること |
| `testEnumDocode` | Enumデコード | ResponseMode等のEnum値が正しくデコードされること |

---

## Well-Known エンドポイント

| エンドポイント | 取得データ |
|--------------|----------|
| `/.well-known/openid-credential-issuer` | Credential Issuerメタデータ |
| `/.well-known/oauth-authorization-server` | Authorization Serverメタデータ |
