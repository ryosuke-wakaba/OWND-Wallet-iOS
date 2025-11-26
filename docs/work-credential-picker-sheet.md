# 証明書選択UIの改善

## 日付
2024-11-26

## 概要

「証明書を選択」から表示する証明書一覧を、画面遷移しないBottom Sheet（Half Sheet）に変更する。

## 現在のフロー

```
SharingRequest → CredentialListForSharing → CredentialDetail → 選択 → SharingRequestに戻る
```

3画面の遷移が必要で、ユーザー体験が煩雑。

## 新しいフロー

```
SharingRequest → Bottom Sheet（証明書一覧）→ 選択 → SharingRequestで項目表示
```

画面遷移なしで、Bottom Sheetから証明書を選択。選択後はSharingRequest画面内で提供項目・非提供項目を表示。

## 実装計画

### Phase 1: Bottom Sheet用の証明書選択コンポーネント作成

**新規ファイル**: `tw2023_wallet/Feature/ShareCredential/Views/CredentialPickerSheet.swift`

```swift
struct CredentialPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    var credentials: [Credential]
    var onSelect: (Credential) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(credentials) { credential in
                        CredentialRow(credential: credential)
                            .onTapGesture {
                                onSelect(credential)
                                dismiss()
                            }
                    }
                }
                .padding()
            }
            .navigationTitle("証明書を選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
```

### Phase 2: SharingRequestの修正

1. `@State private var showCredentialPicker = false` を追加
2. 「証明書を選択」ボタンのアクションを `path.append()` から `showCredentialPicker = true` に変更
3. `.sheet(isPresented: $showCredentialPicker)` でBottom Sheetを表示
4. 選択後の項目表示UIを追加（CredentialDetailのVPモードと同様のレイアウト）

### Phase 3: 選択後の項目表示

SharingRequest内に以下を表示:
- 提供する項目（required claims）
- 提供しない項目（undisclosed claims）
- 任意で提供する項目（user selectable claims）

CredentialDetailのVPモードで使用している`DisclosureRow`コンポーネントを再利用。

### Phase 4: CredentialDetailのVPモード削除

- `CredentialDetail.swift`から`vpMode`関連のコードを削除
- `SharingRequestModel`の`dcqlQuery`チェックを削除
- VPモード専用のUI部分を削除

### Phase 5: 不要になるファイル・コードの整理

- `CredentialListForSharing.swift` - 削除または用途変更を検討
- `ScreensOnFullScreen.credentialList` - SharingRequestからの使用を削除
- `SharingRequest`の`navigationDestination`から`credentialList`と`credentialDetail`を削除

## 修正対象ファイル

- [ ] 新規: `tw2023_wallet/Feature/ShareCredential/Views/CredentialPickerSheet.swift`
- [ ] 修正: `tw2023_wallet/Feature/ShareCredential/Views/SharingRequest.swift`
- [ ] 修正: `tw2023_wallet/Feature/Credentials/Views/CredentialDetail.swift`
- [ ] 検討: `tw2023_wallet/Feature/Credentials/Views/CredentialListForSharing.swift`

## UI仕様

### Bottom Sheet
- `presentationDetents([.medium, .large])` で高さを制御
- ドラッグインジケーター表示
- キャンセルボタン付き

### 選択後の項目表示
- 現在のCredentialDetailのVPモードと同様のレイアウト
- 「提供する項目」「提供しない項目」「任意で提供する項目」のセクション
- `DisclosureRow`コンポーネントを再利用

## 進捗状況

- [x] Phase 1: Bottom Sheet用コンポーネント作成
- [x] Phase 2: SharingRequestの修正
- [x] Phase 3: 選択後の項目表示
- [x] Phase 4: CredentialDetailのVPモード削除
- [x] Phase 5: 不要コードの整理

## 実装完了

### 変更内容のサマリー

1. **SharingRequest.swift**
   - Bottom Sheet用のCredentialPickerSheetを追加
   - 「証明書を選択」でBottom Sheetを表示するように変更
   - 選択後に提供項目・非提供項目・任意項目を直接表示
   - 不要なNavigationStack pathとnavigationDestinationを削除

2. **CredentialDetail.swift**
   - VPモード関連のコードをすべて削除
   - SharingRequestModelへの依存を削除
   - シンプルな証明書詳細表示に特化

3. **削除した機能**
   - SharingScreen enum
   - CredentialDetailのvpMode
   - SharingRequestからCredentialListForSharing/CredentialDetailへの画面遷移
