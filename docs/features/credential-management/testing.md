# Credential Management - Testing

## Unit Tests

- Credential一覧取得
- 検索ロジック
- フィルターロジック
- ソートロジック
- 削除処理

## UI Tests

- Credentialリスト表示
- Credential詳細表示
- 削除フロー
- 検索/フィルター

## Performance Metrics

| Metric | Target |
|--------|--------|
| Credential一覧表示 | < 500ms |
| 詳細画面表示 | < 200ms |
| 検索応答 | < 300ms |
| 削除処理 | < 500ms |

## Test Files

| File | Description |
|------|-------------|
| `tw2023_walletTests/CredentialDataManagerTests.swift` | Data Manager単体テスト |
| `tw2023_walletUITests/CredentialManagementUITests.swift` | UIテスト |
