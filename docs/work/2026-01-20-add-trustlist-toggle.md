# トラストリスト使用トグル追加

## 概要

設定画面にトラストリストセクションを追加し、「使用する」トグルを実装する。
トグルの状態に応じて証明書チェーン検証パターンを切り替える。

## 作業内容

### 1. PreferencesDataStore への設定追加

- `useTrustList` プロパティを追加
- デフォルト値: `true`（トラストリストを使用する）

### 2. Setting.swift への UI 追加

- 「Trust List」セクションを追加
- 「Use Trust List」トグルを追加

### 3. ローカライズ文字列の追加

- `trust_list`: Trust List / トラストリスト
- `use_trust_list`: Use Trust List / トラストリストを使用する

### 4. TrustedListConfigLoader の分岐追加

`TrustedListConfigLoader.createContextSearchInfos`で`useTrustList`設定を確認:
- `useTrustList = true`: 設定ファイルを読み込み、LoTEContextSearchInfo配列を返す（パターンA）
- `useTrustList = false`: 設定ファイルを読まずに空配列を返す → X5CJWTVerifierでシングルトン使用（パターンB）

**パターンA (useTrustList = true)**
```
contextSearchInfosが指定されている場合:
  1. TrustedListManagerがx5cの末尾証明書のAKI/SKIで発行者を検索
  2. 見つかった発行者証明書で使い捨てTrustAnchorManagerを生成
  3. 生成したTrustAnchorManagerで証明書チェーンを検証
```

**パターンB (useTrustList = false)**
```
TrustAnchorManager.sharedの証明書で検証
```

## 進捗

- [x] 作業ドキュメント作成
- [x] PreferencesDataStore への設定追加
- [x] Setting.swift への UI 追加
- [x] ローカライズ文字列の追加
- [x] X5CJWTVerifier の検証ロジック修正
- [ ] 動作確認

## 関連ファイル

- `tw2023_wallet/datastore/PreferencesDataStore.swift`
- `tw2023_wallet/Feature/Settings/Setting.swift`
- `tw2023_wallet/Localizable.xcstrings`
- `tw2023_wallet/Services/TrustedList/TrustedListConfig.swift`

## 参照ドキュメント

- [docs/x509-certificate-chain-validation/chain-validation.md](../x509-certificate-chain-validation/chain-validation.md)
- [docs/features/settings/design.md](../features/settings/design.md)
