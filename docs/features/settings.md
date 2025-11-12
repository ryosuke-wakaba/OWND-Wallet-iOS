# Settings

## Status
- [x] Draft
- [ ] Review
- [ ] Approved
- [x] Implemented (一部機能のみ)
- [ ] Verified

## Overview

アプリの設定と環境設定を管理する機能です。

## User Stories

- As a user, I want to configure app lock settings
- As a user, I want to manage my backup and restore options
- As a user, I want to view app information and version
- As a user, I want to clear app data
- As a user, I want to configure privacy settings
- As a user, I want to see terms of service and privacy policy

## Requirements

### Functional Requirements

1. **Security Settings**
   - App Lock有効/無効
   - App Lockタイムアウト設定
   - 生体認証設定
   - パスコード設定

2. **Backup & Restore**
   - アカウントエクスポート
   - アカウントインポート
   - バックアップ暗号化

3. **Privacy Settings**
   - アナリティクス許可/拒否
   - クラッシュレポート許可/拒否
   - 共有履歴の保持期間

4. **Data Management**
   - すべてのデータ削除
   - キャッシュクリア
   - 共有履歴削除

5. **App Information**
   - バージョン情報
   - ライセンス情報
   - オープンソースライセンス

6. **Legal**
   - 利用規約
   - プライバシーポリシー
   - サポート情報

### Non-Functional Requirements

1. **Security**
   - データ削除時の確認
   - エクスポート時の暗号化
   - インポート時の復号化

2. **Usability**
   - わかりやすい設定項目
   - 適切な説明文
   - 危険な操作の警告

## Design

### UI/UX Design

#### Screens

1. **Settings Screen**
   - セクション分けされた設定項目
   - Security
   - Backup & Restore
   - Privacy
   - Data Management
   - About
   - Legal

2. **App Lock Settings Screen**
   - Enable/Disable トグル
   - Timeout設定（30秒、1分、5分、10分）
   - 生体認証タイプ表示

3. **Backup Screen**
   - Export Accountボタン
   - Import Accountボタン
   - 最終バックアップ日時表示

4. **Privacy Settings Screen**
   - Analytics トグル
   - Crash Reports トグル
   - History Retention設定

5. **Data Management Screen**
   - Clear Cache ボタン
   - Clear Sharing History ボタン
   - Delete All Data ボタン（赤色）

6. **About Screen**
   - アプリバージョン
   - ビルド番号
   - Licenses ボタン
   - Contact Support ボタン

### Settings Structure

```
Settings
├── Security
│   ├── App Lock (Toggle)
│   ├── Lock Timeout (Picker)
│   └── Biometric Type (Display Only)
├── Backup & Restore
│   ├── Export Account
│   ├── Import Account
│   └── Last Backup (Display)
├── Privacy
│   ├── Analytics (Toggle)
│   ├── Crash Reports (Toggle)
│   └── History Retention (Picker)
├── Data Management
│   ├── Clear Cache
│   ├── Clear Sharing History
│   └── Delete All Data
├── About
│   ├── Version
│   ├── Build Number
│   ├── Open Source Licenses
│   └── Contact Support
└── Legal
    ├── Terms of Service
    └── Privacy Policy
```

## Implementation Plan

**実装済み**:
- [x] Settings画面の基本構造
- [x] Backup/Restore画面（Export/Import）
- [x] Legal画面（Privacy Policy、Terms of Use）
- [x] About画面（Version表示）

**未実装**:
- [ ] App Lock設定（Enable/Disable、Timeout）
- [ ] Privacy設定（Analytics、Crash Reports、History Retention）
- [ ] データ削除機能（Clear Cache、Clear History、Delete All Data）
- [ ] About画面の拡張（Build Number、Licenses、Contact Support）

## API Overview

**Note**: 現在実装されているのはBackup/Restore機能のみ。その他の設定機能は未実装。

### PreferencesDataStore

**File**: `tw2023_wallet/datastore/PreferencesDataStore.swift`

```swift
class PreferencesDataStore {
    static let shared = PreferencesDataStore()

    private let seedKey = "seed"
    private let lastBackupAtKey = "last_backup_at_key"

    func saveLastBackupAtKey(_ value: String)
    func getLastBackupAtKey() -> String?

    func saveSeed(_ value: String) throws
    func getSeed() async throws -> String?
}

class BiometricAuthForPreference {
    func authenticateUser() async throws
}
```

### Backup & Restore ViewModels

**File**: `tw2023_wallet/Feature/Settings/ViewModels/BackupViewModel.swift`

```swift
@Observable
class BackupViewModel {
    var isLoading = false
    var hasLoadedData = false
    var lastCreatedAt: String? = nil
    var seed: String? = nil

    func loadData()
    func accessPairwiseAccountManager() async -> Bool
    func generateBackupData() -> Data?
    func updateLastBackupDate()
}
```

**File**: `tw2023_wallet/Feature/Settings/ViewModels/RestoreViewModel.swift`

```swift
@Observable
class RestoreViewModel {
    var importedDocumentUrl: URL? = nil

    func selectFile() -> Result<Void, Error>
}
```

**Note**: バックアップ・リストア機能は以下を対象:
- Seed（Mnemonic）
- ID Token共有履歴
- Credential共有履歴
- Credentialsそのものは含まれない（Issuerから再発行が必要）

## Data Model

### UserDefaults Keys

**File**: `tw2023_wallet/datastore/PreferencesDataStore.swift`

```swift
// 実装されているキー
private let seedKey = "seed"
private let lastBackupAtKey = "last_backup_at_key"
```

**Note**: App Lock、Privacy、Data Management関連のキーは未実装。

### Backup Format

**File**: `tw2023_wallet/Feature/Settings/Models/BackupModel.swift`

```swift
struct BackupData: Codable {
    let seed: String
    let idTokenSharingHistories: [IdTokenSharingHistory]
    let credentialSharingHistories: [CredentialSharingHistory]
}
```

**形式**: ZIP圧縮されたJSON

**重要な注意点**:
- パスワード暗号化は**実装されていません**
- Seedへのアクセスは生体認証で保護
- Credentialsそのものは含まれない（共有履歴のみ）
- バックアップファイルは機密情報なので安全に保管する必要がある

## Security Considerations

### Threats

1. **Unauthorized Backup File Access**
   - Threat: バックアップファイルが暗号化されていないため、ファイルが流出すると全データが露出
   - Current Mitigation: 生体認証によるSeedアクセス制限
   - Future Mitigation: バックアップファイル自体の暗号化実装

2. **Accidental Data Loss**
   - Threat: Seed紛失によるアカウント復元不可
   - Mitigation: バックアップ推奨、最終バックアップ日時表示

3. **Backup File Tampering**
   - Threat: バックアップファイルの改ざん
   - Mitigation: インポート時のJSON形式検証、ZIP整合性チェック
   - Future Mitigation: バックアップファイルの署名検証

### Security Checklist

- [ ] バックアップ暗号化実装（現在未実装）
- [x] Seedアクセス時の生体認証
- [ ] データ削除前の確認（データ削除機能自体が未実装）
- [x] エクスポート時の認証（生体認証）
- [x] インポート時の検証（ZIPとJSON形式チェック）
- [ ] バックアップファイルの暗号化（将来の実装）

## Testing Strategy

### Unit Tests

- 設定の保存/読み込み
- データ削除ロジック
- エクスポート/インポート

### UI Tests

- 設定変更フロー
- データ削除フロー
- バックアップ/リストアフロー

## Error Handling

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

- 設定読み込み: < 100ms
- 設定保存: < 200ms
- キャッシュクリア: < 1秒
- データ削除: < 3秒

## Accessibility

- VoiceOver対応
- Dynamic Type対応
- 設定項目の明確な説明
- スイッチのラベル

## Localization

- 設定項目名の多言語対応
- 説明文の多言語対応
- エラーメッセージの多言語対応

## Privacy Considerations

### Data Collection

**現在の実装**:
- Analytics: 未実装（将来の実装予定）
- Crash Reports: 未実装（将来の実装予定）
- Sharing History: 保存される（保持期間設定は未実装）

### Data Retention

**現在の実装**:
- Seed: 生体認証で保護、手動バックアップのみ
- 共有履歴: 無制限保存（将来的に保持期間設定を実装予定）
- Credentials: 手動削除のみ（自動削除機能なし）

**将来の実装予定**:
- 共有履歴の保持期間設定（30日、90日、180日、無期限）
- キャッシュクリア機能
- すべてのデータ削除機能

## Future Enhancements

1. **Security**
   - バックアップファイルのパスワード暗号化
   - App Lock設定（Enable/Disable、Timeout）
   - バックアップファイルの署名検証

2. **Privacy**
   - Analytics設定（Enable/Disable）
   - Crash Reports設定（Enable/Disable）
   - 共有履歴の保持期間設定（30日、90日、180日、無期限）

3. **Data Management**
   - キャッシュクリア機能
   - 共有履歴削除機能
   - すべてのデータ削除機能

4. **UI/UX**
   - iCloud同期
   - テーマ設定（ライト/ダーク）
   - 言語設定

5. **Advanced**
   - Trusted Issuer/Verifierリスト管理
   - Build Number、Licenses、Contact Support表示

## References

- Settings UI: `tw2023_wallet/Feature/Settings/Setting.swift`
- Backup UI: `tw2023_wallet/Feature/Settings/Backup.swift`
- Restore UI: `tw2023_wallet/Feature/Settings/Restore.swift`
- ViewModels: `tw2023_wallet/Feature/Settings/ViewModels/`
- Data Models: `tw2023_wallet/Feature/Settings/Models/BackupModel.swift`
- Preferences: `tw2023_wallet/datastore/PreferencesDataStore.swift`
