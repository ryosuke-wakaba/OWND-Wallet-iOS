# Settings - Testing

## Unit Tests

- 設定の保存/読み込み
- データ削除ロジック
- エクスポート/インポート

## UI Tests

- 設定変更フロー
- データ削除フロー
- バックアップ/リストアフロー

## Error Handling

### RestoreError

**File**: `tw2023_wallet/Feature/Settings/ViewModels/RestoreViewModel.swift`

```swift
enum RestoreError: Error {
    case invalidBackupFile
    case saveError
}
```

**Note**: BackupViewModelでは明示的なエラー型を定義せず、do-catchで汎用的にハンドリング。
App Lock、Privacy、Data Management関連のエラー型は未定義（機能自体が未実装）。

## Performance Metrics

| Metric | Target |
|--------|--------|
| 設定読み込み | < 100ms |
| 設定保存 | < 200ms |
| キャッシュクリア | < 1秒 |
| データ削除 | < 3秒 |

## Test Files

| File | Description |
|------|-------------|
| `tw2023_walletTests/PreferencesDataStoreTests.swift` | 設定保存単体テスト |
| `tw2023_walletTests/BackupViewModelTests.swift` | バックアップ単体テスト |
| `tw2023_walletUITests/SettingsUITests.swift` | UIテスト |
