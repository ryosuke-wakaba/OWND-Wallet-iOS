# Settings - Data Model

## UserDefaults Keys

**File**: `tw2023_wallet/datastore/PreferencesDataStore.swift`

```swift
// 実装されているキー
private let seedKey = "seed"
private let lastBackupAtKey = "last_backup_at_key"
private let preferSignedMetadataKey = "prefer_signed_metadata"
private let useDPoPKey = "use_dpop"
```

**Note**: App Lock、Privacy、Data Management関連のキーは未実装。

## Backup Format

### BackupData

**File**: `tw2023_wallet/Feature/Settings/Models/BackupModel.swift`

```swift
struct BackupData: Codable {
    let seed: String
    let idTokenSharingHistories: [IdTokenSharingHistory]
    let credentialSharingHistories: [CredentialSharingHistory]
}
```

### File Format

- **形式**: ZIP圧縮されたJSON
- **拡張子**: `.zip`
- **内容**: `backup.json` (BackupData)

### Security Notes

| Item | Status |
|------|--------|
| パスワード暗号化 | ❌ 未実装 |
| 生体認証保護 | ✅ Seedアクセス時 |
| Credentials含有 | ❌ 含まれない |

**重要**: バックアップファイルは機密情報を含むため、安全に保管する必要があります。

## Future Keys (未実装)

```swift
// App Lock
private let appLockEnabledKey = "app_lock_enabled"
private let lockTimeoutKey = "lock_timeout"

// Privacy
private let analyticsEnabledKey = "analytics_enabled"
private let crashReportsEnabledKey = "crash_reports_enabled"
private let historyRetentionKey = "history_retention"
```

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/datastore/PreferencesDataStore.swift` | UserDefaults管理 |
| `tw2023_wallet/Feature/Settings/Models/BackupModel.swift` | バックアップ形式 |
