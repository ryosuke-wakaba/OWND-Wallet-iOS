# CredentialDetail VP モード表示タイミング問題の修正

## 日付
2024-11-26

## 問題の概要

CredentialDetail.swift で VP モード（クレデンシャル共有）時に、提供する項目と提供しない項目が表示されない場合がある。

### 症状
- DCQL クエリの条件を満たしたクレデンシャルの詳細画面で、クレーム（項目）が表示されたりされなかったりする
- タイミングによって表示が不安定

### デバッグログの結果
```
[CredentialDetailViewModel] credential.format: dc+sd-jwt
[CredentialDetailViewModel] query.credentials.count: 1
[CredentialDetailViewModel] matched! disclosures count: 9
[CredentialDetailViewModel] requiredClaims: 7, userSelectable: 0, undisclosed: 2
```
データ自体は正しくロードされていることを確認。

## 根本原因

SwiftUI の非同期処理とビューのレンダリングタイミングの問題。

### 問題のあったコード

```swift
// 問題1: vpMode が @State で、非同期タスク内で設定
@State var vpMode: Bool = false

// 問題2: onAppear 内の Task で状態を更新
.onAppear {
    Task {
        if let model = sharingRequestModel, let query = model.dcqlQuery {
            self.vpMode = true  // ← 非同期で設定されるため、ビューが先にレンダリングされる場合がある
            await viewModel.loadData(credential: credential, dcqlQuery: query)
            self.userSelectableClaims = viewModel.userSelectableClaims
        }
        ...
    }
}
```

### 発生メカニズム

1. ビューが初期レンダリングされる（`vpMode = false`）
2. `.onAppear` の `Task` が開始
3. `vpMode = true` が設定される前にビューがレンダリングされる場合がある
4. `@Observable` の ViewModel の変更が必ずしも再レンダリングをトリガーしない場合がある

## 修正内容

### 1. `vpMode` を computed property に変更

```swift
// Before: @State で管理
@State var vpMode: Bool = false

// After: 環境から直接計算
private var vpMode: Bool {
    sharingRequestModel?.dcqlQuery != nil
}
```

これにより、`vpMode` は常に環境の状態を正確に反映する。

### 2. `dataLoaded` 状態を追加

```swift
@State private var dataLoaded: Bool = false
```

データロードの完了を追跡する状態変数を追加。

### 3. `.onAppear` から `.task` に変更

```swift
// Before
.onAppear {
    Task {
        ...
    }
}

// After
.task {
    ...
    self.dataLoaded = true
}
```

`.task` 修飾子は SwiftUI で推奨される非同期処理の方法で、状態更新が適切に処理される。

### 4. VP モードの表示条件に `dataLoaded` を追加

```swift
// Before
else {
    // VP mode claims...
}

// After
else if dataLoaded {
    // VP mode claims...
}
```

これにより、SwiftUI が `dataLoaded` の状態変化を追跡し、データロード完了後に確実にビューを再レンダリングする。

## 修正したファイル

- `tw2023_wallet/Feature/Credentials/Views/CredentialDetail.swift`
- `tw2023_wallet/Feature/Credentials/ViewModels/CredentialDetailViewModel.swift`（デバッグログ追加）

## 教訓

1. SwiftUI で非同期データロードを行う場合、`.task` 修飾子を使用する
2. ビューの表示条件に影響する値は `@State` で明示的に追跡する
3. 環境から派生する値は computed property として実装し、状態の同期問題を回避する
4. `@Observable` オブジェクトの変更だけに依存せず、`@State` で明示的にビューの更新をトリガーする
