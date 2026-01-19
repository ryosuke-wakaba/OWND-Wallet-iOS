# クレデンシャル一覧表示の不具合修正

## 概要

Credentials List Screenを表示した際、保存されているデータがあるにもかかわらず0件で表示されることがある問題を修正。

## 問題の現象

- Credentials List Screenを表示した際、表示すべきデータが保存されているのに0件の表示となることがある
- ボトムタブで別の画面に移動してから再表示すると正しく表示される

## 原因分析

### 根本原因

`CredentialList.swift`の`viewModel`プロパティに`@State`修飾子が付いていないことが問題。

### 詳細

```swift
// 問題のあるコード (CredentialList.swift:11)
struct CredentialList: View {
    var viewModel: CredentialListViewModel  // @Stateがない
```

iOS 17以降で導入された`@Observable`マクロを使用したクラスをSwiftUI Viewで所有する場合、`@State`修飾子を付ける必要がある。

**理由**:
1. `@State`なしでは、SwiftUIがViewModelのライフサイクルを管理できない
2. Viewの再構築時（TabView切り替え等）にViewModelが再作成される可能性がある
3. 再作成されても`hasLoadedData`がリセットされるため、`onAppear`でデータが再ロードされるはずだが、タイミングの問題で表示が更新されないケースがある
4. `@State`を付けることで、SwiftUIが適切にViewModelの状態を追跡し、変更時にViewを再レンダリングする

### 関連コード

- `tw2023_wallet/Feature/Credentials/Views/CredentialList.swift:11` - 問題のある宣言
- `tw2023_wallet/Feature/Credentials/ViewModels/CredentialListViewModel.swift` - `@Observable`クラス
- `tw2023_wallet/Feature/Credentials/Models/CredentialListModel.swift` - データモデル

## 修正内容

### 変更ファイル

`tw2023_wallet/Feature/Credentials/Views/CredentialList.swift`

### 変更内容

1. `viewModel`プロパティに`@State`修飾子を追加
2. イニシャライザでの初期化方法を`@State`に対応した形式に変更

```swift
// Before
var viewModel: CredentialListViewModel

init(viewModel: CredentialListViewModel = CredentialListViewModel()) {
    self.viewModel = viewModel
}

// After
@State var viewModel: CredentialListViewModel

init(viewModel: CredentialListViewModel = CredentialListViewModel()) {
    _viewModel = State(initialValue: viewModel)
}
```

## テスト方法

### 手動テスト手順

1. アプリを起動
2. Credentials Listタブを開く
3. クレデンシャルがある場合、正しく表示されることを確認
4. 別のタブに移動
5. Credentials Listタブに戻る
6. クレデンシャルが正しく表示されていることを確認
7. アプリを再起動して同様の確認を行う

### 確認ポイント

- [ ] 初回表示時にクレデンシャルが正しく表示される
- [ ] タブ切り替え後も正しく表示される
- [ ] アプリ再起動後も正しく表示される
- [ ] クレデンシャルがない場合は「no_certificate」メッセージが表示される

## ブランチ

`bugfix/credential-list-not-loading`

## ステータス

- [x] 原因分析完了
- [x] 修正実装
- [ ] 動作確認
- [ ] レビュー依頼
