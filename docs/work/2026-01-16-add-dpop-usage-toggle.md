# DPoP使用設定トグルの追加

## 概要

設定画面にDPoP (Demonstrating Proof of Possession) 使用のオン/オフを切り替えるトグルを追加する。

## 背景

DPoP (RFC 9449) はアクセストークンを送信者に紐付けるセキュリティ機能。現在は常に有効だが、テストやデバッグ目的でオフにできるようにする必要がある。

## 変更内容

### 1. PreferencesDataStore

`tw2023_wallet/datastore/PreferencesDataStore.swift`

- DPoP設定用のキーを追加
- get/setメソッドを追加（デフォルト値: true）

```swift
private let useDPoPKey = "use_dpop"

func setUseDPoP(_ value: Bool) {
    defaults.set(value, forKey: useDPoPKey)
}

func getUseDPoP() -> Bool {
    // キーが未設定の場合はtrue（DPoP有効）をデフォルトとする
    if defaults.object(forKey: useDPoPKey) == nil {
        return true
    }
    return defaults.bool(forKey: useDPoPKey)
}
```

### 2. 設定画面UI

`tw2023_wallet/Feature/Settings/Setting.swift`

- 「発行設定」セクションに新しいトグルを追加
- 既存の「サーバー認証を要求」トグルの下に配置

```swift
@State private var useDPoP = true

Toggle(isOn: $useDPoP) {
    Text("use_dpop").modifier(BodyBlack())
}
.padding(.vertical, 16)
.onChange(of: useDPoP) { _, newValue in
    PreferencesDataStore.shared.setUseDPoP(newValue)
}
```

### 3. ローカライゼーション

`tw2023_wallet/Localizable.xcstrings`

- 英語: "Use DPoP"
- 日本語: "DPoPを使用"

### 4. CredentialOfferViewModel

`tw2023_wallet/Feature/IssueCredential/ViewModels/CredentialOfferViewModel.swift`

- `sendRequest`メソッドでPreferencesDataStoreからDPoP設定を読み取り
- `issueCredential`メソッドに設定値を渡す

```swift
func sendRequest(txCode: String?) async throws {
    // ...
    let useDPoP = PreferencesDataStore.shared.getUseDPoP()
    try await issuanceService.issueCredential(
        credentialOffer: offer,
        metadata: metadata,
        credentialConfigurationId: configId,
        txCode: txCode,
        useDPoP: useDPoP
    )
}
```

## ファイル一覧

| ファイル | 変更内容 |
|---------|---------|
| `tw2023_wallet/datastore/PreferencesDataStore.swift` | DPoP設定の保存/取得 |
| `tw2023_wallet/Feature/Settings/Setting.swift` | トグルUI追加 |
| `tw2023_wallet/Localizable.xcstrings` | ローカライゼーション文字列追加 |
| `tw2023_wallet/Feature/IssueCredential/ViewModels/CredentialOfferViewModel.swift` | DPoP設定読み取り |

## テスト方法

### 手動テスト手順

1. アプリを起動
2. 設定画面を開く
3. 「発行設定」セクションに「DPoPを使用」トグルが表示されることを確認
4. トグルがデフォルトでオンになっていることを確認
5. トグルをオフに切り替え
6. アプリを再起動
7. 設定画面を開き、トグルがオフの状態で保持されていることを確認
8. クレデンシャル発行フローを実行し、DPoPなしで発行が行われることを確認

### 確認ポイント

- [ ] 設定画面に「DPoPを使用」トグルが表示される
- [ ] トグルのデフォルト値がオン（true）である
- [ ] トグルの状態がアプリ再起動後も保持される
- [ ] DPoP有効時、クレデンシャル発行でDPoPが使用される
- [ ] DPoP無効時、クレデンシャル発行でDPoPが使用されない

## ブランチ

`feature/add-dpop-usage-toggle`

## ステータス

- [x] 設計完了
- [x] 実装
- [ ] 動作確認
- [ ] レビュー依頼
