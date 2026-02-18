# 設定画面の整理

## 概要

「サーバー認証を要求する」設定をトラストリストセクションに移動し、重複する「トラストリストを使用する」設定を削除する。

## 背景

- 「サーバー認証を要求する」設定はプレゼンテーション時も使用されるため、発行設定セクションに属していることは適切ではない
- 「トラストリストを使用する」設定と「サーバー認証を要求する」設定は役割が重複している

## 作業内容

### 1. Setting.swift のUI変更

- `preferSignedMetadata` トグルを発行設定セクションからトラストリストセクションに移動
- `useTrustList` トグルを削除
- `useTrustList` のState変数を削除

### 2. TrustedListConfig.swift の修正

- `TrustedListConfigLoader.createContextSearchInfos` で `getUseTrustList()` の代わりに `getPreferSignedMetadata()` を使用

### 3. PreferencesDataStore.swift のクリーンアップ

- `useTrustListKey` を削除
- `setUseTrustList()` メソッドを削除
- `getUseTrustList()` メソッドを削除

### 4. ドキュメント更新

- `docs/features/settings/design.md` を更新

## 進捗

- [x] 作業ドキュメント作成
- [x] Setting.swift のUI変更
- [x] TrustedListConfig.swift の修正
- [x] PreferencesDataStore.swift のクリーンアップ
- [x] ドキュメント更新
- [x] ビルド確認

## 関連ファイル

- `tw2023_wallet/Feature/Settings/Setting.swift`
- `tw2023_wallet/Services/TrustedList/TrustedListConfig.swift`
- `tw2023_wallet/datastore/PreferencesDataStore.swift`
- `docs/features/settings/design.md`
