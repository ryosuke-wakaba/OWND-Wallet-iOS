# Data Storage

## Overview

OWND Wallet iOSのデータ永続化戦略とストレージアーキテクチャについて説明します。

## Storage Architecture

### Storage Strategy

| Data Type | Storage | Encryption | Backup | Location |
|-----------|---------|------------|--------|----------|
| Private Keys | Keychain/Secure Enclave | Hardware | Excluded | System |
| Credentials | CoreData | File-level | Included | App Sandbox |
| Sharing History | CoreData | File-level | Included | App Sandbox |
| Preferences | UserDefaults | None | Included | App Sandbox |

### Storage Flow

```
Application
    ↓
Data Managers
    ↓
Protocol Buffers (Serialization)
    ↓
Storage Backends (CoreData/Keychain/UserDefaults)
```

## Data Models

### Credential

**CoreData Entity**: `CredentialEntity`
- `id`: UUID
- `format`: String ("jwt_vc_json", "ldp_vc")
- `rawCredential`: Data (Protocol Buffer serialized)
- `issuer`: String
- `issuedAt`: Date
- `expiresAt`: Date?
- `credentialType`: String
- `claims`: Data (JSON)

**Protocol Buffers**: `credential_data.pb.swift`

**Swift Model**: `tw2023_wallet/Models/Credential.swift`
- ビジネスロジック（isExpired、isExpiringSoonなど）を含む

### Sharing History

**CoreData Entity**: `CredentialSharingHistoryEntity`
- `id`: UUID
- `credentialId`: UUID
- `verifier`: String
- `sharedAt`: Date
- `sharedFields`: Data (JSON array)
- `purpose`: String?

**Protocol Buffers**: `credential_sharing_history.pb.swift`

### ID Token History

**Protocol Buffers**: `id_token_sharing_history.pb.swift`
- `id`, `client_id`, `shared_at`, `did`, `claims`

## Implementation

### Data Managers

**Location**: `tw2023_wallet/datastore/`

主要なData Manager:
- **CredentialDataManager**: Credential CRUD操作
- **CredentialSharingHistoryManager**: 共有履歴管理
- **IdTokenSharingHistoryManager**: ID Token履歴管理
- **PreferencesDataStore**: アプリ設定管理

**基本パターン**:
```swift
class CredentialDataManager {
    static let shared = CredentialDataManager()

    func save(_ credential: Credential) async throws
    func fetch(id: UUID) async throws -> Credential?
    func fetchAll() async throws -> [Credential]
    func delete(id: UUID) async throws
}
```

### CoreData Configuration

**File Protection**: `FileProtectionType.complete`
- デバイスロック時はアクセス不可
- セキュアなデータ保護

**Indexing**: 以下のフィールドにインデックス設定
- `id` (Primary Key)
- `issuer`
- `credentialType`
- `issuedAt`

### Keychain Management

**Location**: `tw2023_wallet/Helper/KeychainManager.swift`

**設定**:
- `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`: バックアップ除外、ロック時アクセス不可
- `kSecAttrAccessControl`: 生体認証必須
- Secure Enclave優先使用

**鍵の種類**:
- Signing Keys: VP/ID Token署名用
- Pairwise Keys: RP別識別子用

## Data Migration

### Strategy

**Lightweight Migration**: 自動マイグレーション使用

CoreDataのNSPersistentContainerはデフォルトでLightweight Migrationを有効にしています。
将来的にマイグレーション設定をカスタマイズする場合は以下のように設定可能：

```swift
let description = persistentContainer.persistentStoreDescriptions.first
description?.setOption(true as NSNumber,
    forKey: NSMigratePersistentStoresAutomaticallyOption)
description?.setOption(true as NSNumber,
    forKey: NSInferMappingModelAutomaticallyOption)
```

**対応可能な変更**:
- 新しいエンティティ/属性追加
- 属性削除
- エンティティ/属性リネーム（識別子付き）

**Protocol Buffers Migration戦略**（今後の指針）:
- フィールド番号を変更しない
- 削除時は`reserved`でマーク
- 新フィールドは新番号を使用

### Version Management

**Current**: 初期バージョン
- CredentialDataEntity (11フィールド)
- CredentialSharingHistoryEntity (8フィールド + relation)
- IdTokenSharingHistoryEntity (3フィールド)

マイグレーションが必要になった際は、CoreDataモデルのバージョニングを導入予定。

## Data Lifecycle

### Retention Policy

- **Credentials**: 無制限（ユーザーが手動削除）
- **Sharing History**: 無制限（将来的に保持期間設定を実装予定）
- **Cache**: アプリ再起動時クリア

### Cleanup

現在の実装:
- 手動削除のみ（ユーザーが削除操作を実行）

将来的な実装予定:
- 共有履歴の自動削除（保持期間設定後）
- 期限切れCredentialの通知

### Backup & Restore

**Export**:
- Credentials + History + Preferences → JSON
- バージョン情報含む

**Import**:
- バージョン検証
- データ整合性チェック
- 段階的インポート

**注意**: 秘密鍵は別途エクスポート/インポート（暗号化必須）

## References

**Implementation**:
- Data Models: `tw2023_wallet/datastore/`
- Swift Models: `tw2023_wallet/Models/`
- Keychain: `tw2023_wallet/Helper/KeychainManager.swift`

**Documentation**:
- [CoreData](https://developer.apple.com/documentation/coredata)
- [Keychain Services](https://developer.apple.com/documentation/security/keychain_services)
- [Protocol Buffers](https://protobuf.dev/)
