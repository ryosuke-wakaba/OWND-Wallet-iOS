# Credential Management

## Status
- [x] Draft
- [ ] Review
- [ ] Approved
- [x] Implemented
- [ ] Verified

## Overview

ウォレット内のVerifiable Credentialsを管理する機能です。

## User Stories

- As a user, I want to view all my credentials in one place
- As a user, I want to see detailed information about each credential
- As a user, I want to delete credentials I no longer need
- As a user, I want to search and filter my credentials
- As a user, I want to see the sharing history of each credential

## Requirements

### Functional Requirements

1. **Credential List**
   - すべてのCredentialの一覧表示
   - Credentialカードビュー
   - ソート機能（日付、Issuer、タイプ）

2. **Credential Detail**
   - Credential詳細情報表示
   - Claims/Attributes表示
   - Issuer情報
   - 発行日・有効期限
   - QRコード表示（共有用）

3. **Credential Deletion**
   - Credentialの削除
   - 確認ダイアログ
   - 削除の取り消し不可の警告

4. **Search & Filter**
   - テキスト検索
   - タイプフィルター
   - Issuerフィルター
   - 有効期限フィルター

5. **Sharing History**
   - Credential別の共有履歴
   - 共有先（Verifier）
   - 共有日時
   - 共有した属性

### Non-Functional Requirements

1. **Performance**
   - Credential一覧の高速表示
   - スムーズなスクロール
   - 検索のリアルタイム応答

2. **Usability**
   - 直感的なUI
   - わかりやすいCredential表示
   - 簡単な操作

3. **Accessibility**
   - VoiceOver対応
   - Dynamic Type対応

## Implementation Status

- [x] Credential一覧表示
- [x] Credentialカードコンポーネント
- [x] Credential詳細画面
- [x] Credential削除機能
- [ ] 検索機能
- [ ] フィルター機能
- [ ] ソート機能
- [x] 共有履歴表示
- [x] QRコード生成・表示
- [ ] 有効期限通知
- [ ] 有効期限チェック機能（`isExpired`, `isExpiringSoon`）

## Related Documents

- [Design](./design.md) - UI/UX、データフロー
- [API Reference](./api.md) - ViewModels、Data Manager
- [Data Model](./data-model.md) - Credential、共有履歴
- [Security](./security.md) - セキュリティ考慮事項
- [Testing](./testing.md) - テスト戦略

## References

- Implementation: `tw2023_wallet/Feature/Credentials/`
- Data Manager: `tw2023_wallet/datastore/CredentialDataManager.swift`
- Models: `tw2023_wallet/Models/Credential.swift`
