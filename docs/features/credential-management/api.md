# Credential Management - API Reference

**Note**: プロトコルは定義されておらず、以下のクラスに機能が分散実装されています。

## ViewModels

### CredentialListViewModel

**File**: `tw2023_wallet/Feature/Credentials/ViewModels/CredentialListViewModel.swift`

```swift
@Observable
class CredentialListViewModel {
    var credentials: [Credential] = []
    var filteredCredentials: [Credential] = []
    var isLoading: Bool = false

    /// Load all credentials from data store
    func loadData()

    /// Filter credentials by search text
    func filterCredential(filter: String)

    /// Delete a credential
    func deleteCredential(credential: Credential) async
}
```

### CredentialDetailViewModel

**File**: `tw2023_wallet/Feature/Credentials/ViewModels/CredentialDetailViewModel.swift`

```swift
@Observable
class CredentialDetailViewModel {
    var credential: Credential?
    var showQR: Bool = false
    // Credential詳細表示とQRコード表示を管理
}
```

## Data Manager

### CredentialDataManager

**File**: `tw2023_wallet/datastore/CredentialDataManager.swift`

```swift
class CredentialDataManager {
    /// Save credential data
    func saveCredentialData(credentialData: Datastore_CredentialData)

    /// Get all stored credentials
    func getAllCredentials() -> [Datastore_CredentialData]

    /// Get credential by ID
    func getCredentialById(id: String) -> Datastore_CredentialData?

    /// Delete credential by ID
    func deleteCredentialById(id: String)
}
```

### CredentialSharingHistoryManager

**File**: `tw2023_wallet/datastore/CredentialSharingHistoryManager.swift`

```swift
class CredentialSharingHistoryManager {
    /// Get all sharing history
    func getAllCredentialSharingHistory() -> [CredentialSharingHistory]

    /// Save sharing history
    func saveCredentialSharingHistory(history: Datastore_CredentialSharingHistory)

    /// Delete sharing history by RP
    func deleteCredentialSharingHistoryByRp(rp: String)
}
```

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/Feature/Credentials/ViewModels/CredentialListViewModel.swift` | 一覧ViewModel |
| `tw2023_wallet/Feature/Credentials/ViewModels/CredentialDetailViewModel.swift` | 詳細ViewModel |
| `tw2023_wallet/datastore/CredentialDataManager.swift` | Credential管理 |
| `tw2023_wallet/datastore/CredentialSharingHistoryManager.swift` | 共有履歴管理 |
