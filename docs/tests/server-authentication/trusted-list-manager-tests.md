# TrustedListManagerTests.swift

**パス**: `tw2023_walletTests/TrustedListManagerTests.swift`

**対応実装**: `tw2023_wallet/Services/TrustedList/TrustedListManager.swift`

**概要**: TrustedListManager（トラストリスト管理）の単体テストです。

---

## フェッチテスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testFetchTrustedList` | トラストリストの取得 | トラストリストを正しく取得できること |
| `testFetchTrustedListCaching` | キャッシュ動作 | 取得したトラストリストがキャッシュされること |
| `testFetchTrustedListHTTPError` | HTTPエラー処理 | HTTPエラー時に適切なエラーが返されること |

---

## Certificate-Based Search（AKI/SKI）テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testFindIssuerCertificateByAKISKI` | AKI/SKIマッチングによる発行者検索 | Authority Key Identifier / Subject Key Identifierで発行者証明書を検索できること |
| `testFindIssuerCertificateByDN` | DNマッチングによる発行者検索（フォールバック） | Distinguished Nameで発行者証明書を検索できること（AKI/SKI未対応時のフォールバック） |
| `testFindIssuerCertificateNotFound` | 発行者証明書が見つからない場合 | 発行者証明書が見つからない場合に適切なエラーが返されること |
| `testFindIssuerCertificateWithConditionFilter` | 条件フィルタリング | 検索条件でフィルタリングできること |
| `testGetIssuerCertificatesForChain` | x5cチェーンの発行者証明書取得 | x5cチェーンに対する発行者証明書を取得できること |
