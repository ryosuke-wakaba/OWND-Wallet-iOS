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

## Implementation Status

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

## Related Documents

- [Design](./design.md) - UI/UX、設定構造
- [API Reference](./api.md) - PreferencesDataStore、ViewModels
- [Data Model](./data-model.md) - UserDefaults、バックアップ形式
- [Security](./security.md) - セキュリティ考慮事項、プライバシー
- [Testing](./testing.md) - テスト戦略

## References

- Settings UI: `tw2023_wallet/Feature/Settings/Setting.swift`
- Backup UI: `tw2023_wallet/Feature/Settings/Backup.swift`
- Restore UI: `tw2023_wallet/Feature/Settings/Restore.swift`
- ViewModels: `tw2023_wallet/Feature/Settings/ViewModels/`
- Preferences: `tw2023_wallet/datastore/PreferencesDataStore.swift`
