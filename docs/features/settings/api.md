# Settings - API Reference

**Note**: 現在実装されているのはBackup/Restore機能のみ。その他の設定機能は未実装。

## PreferencesDataStore

**File**: `tw2023_wallet/datastore/PreferencesDataStore.swift`

```swift
class PreferencesDataStore {
    static let shared = PreferencesDataStore()

    private let seedKey = "seed"
    private let lastBackupAtKey = "last_backup_at_key"

    /// Save last backup timestamp
    func saveLastBackupAtKey(_ value: String)

    /// Get last backup timestamp
    func getLastBackupAtKey() -> String?

    /// Save seed (mnemonic)
    func saveSeed(_ value: String) throws

    /// Get seed with biometric authentication
    func getSeed() async throws -> String?
}

class BiometricAuthForPreference {
    /// Authenticate user with biometrics
    func authenticateUser() async throws
}
```

## Backup & Restore ViewModels

### BackupViewModel

**File**: `tw2023_wallet/Feature/Settings/ViewModels/BackupViewModel.swift`

```swift
@Observable
class BackupViewModel {
    var isLoading = false
    var hasLoadedData = false
    var lastCreatedAt: String? = nil
    var seed: String? = nil

    /// Load backup data
    func loadData()

    /// Access pairwise account manager with biometric auth
    func accessPairwiseAccountManager() async -> Bool

    /// Generate backup data as ZIP
    func generateBackupData() -> Data?

    /// Update last backup date
    func updateLastBackupDate()
}
```

### RestoreViewModel

**File**: `tw2023_wallet/Feature/Settings/ViewModels/RestoreViewModel.swift`

```swift
@Observable
class RestoreViewModel {
    var importedDocumentUrl: URL? = nil

    /// Select backup file
    func selectFile() -> Result<Void, Error>
}
```

## Backup Contents

バックアップ・リストア機能の対象:

| Item | Included | Notes |
|------|----------|-------|
| Seed（Mnemonic） | ✅ | アカウント復元に必要 |
| ID Token共有履歴 | ✅ | 認証履歴 |
| Credential共有履歴 | ✅ | VP提示履歴 |
| Credentials | ❌ | Issuerから再発行が必要 |

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/datastore/PreferencesDataStore.swift` | 設定保存 |
| `tw2023_wallet/Feature/Settings/ViewModels/BackupViewModel.swift` | バックアップViewModel |
| `tw2023_wallet/Feature/Settings/ViewModels/RestoreViewModel.swift` | リストアViewModel |
