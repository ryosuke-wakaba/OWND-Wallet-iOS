# Authentication - Data Model

## ID Token Sharing History

認証履歴を記録し、ユーザーがどのRPにいつ認証したかを確認できます。

### Protocol Buffers

**File**: `tw2023_wallet/proto/id_token_sharing_history.proto`

```proto
message IdTokenSharingHistory {
  string rp = 1;                           // Relying Party identifier
  int32 accountIndex = 2;                  // Pairwise account index used
  google.protobuf.Timestamp createdAt = 3; // Authentication timestamp
}
```

### Swift Model

**File**: `tw2023_wallet/Models/IdTokenSharingHistory.swift`

```swift
struct IdTokenSharingHistory: Codable, Hashable, History {
    let rp: String          // RP identifier (client_id)
    let accountIndex: Int   // Account index used for this RP
    let createdAt: String   // ISO 8601 timestamp
}
```

### CoreData Entity

**Entity**: `IdTokenSharingHistoryEntity`

| Attribute | Type | Description |
|-----------|------|-------------|
| `rp` | String | Relying Party identifier |
| `accountIndex` | Int32 | Pairwise account index |
| `createdAt` | Date | Authentication timestamp |

## Account-RP Mapping

RPとPairwise Account Indexの紐付けを管理します。

```swift
// 保存形式
[
    "example.com": 0,
    "another.org": 1,
    "service.io": 2
]
```

## Data Flow

```
ID Token送信成功
        ↓
IdTokenSharingHistory作成
        ↓
Protocol Buffers シリアライズ
        ↓
CoreData保存
        ↓
履歴画面に表示
```

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/proto/id_token_sharing_history.proto` | Protocol Buffers定義 |
| `tw2023_wallet/Models/IdTokenSharingHistory.swift` | Swift Model |
| `tw2023_wallet/datastore/IdTokenSharingHistoryManager.swift` | 履歴管理 |
