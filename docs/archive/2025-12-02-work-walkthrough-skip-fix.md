# ウォークスルー「スキップ」後のHome遷移問題の修正

## 概要

アプリの初回起動時、ウォークスルー画面で「スキップ」→「新しく始める」をタップするとHome遷移せず、ウォークスルー画面に戻ってしまう問題を修正します。

## 問題の詳細

### 現象

- ウォークスルー画面で「スキップ」→「新しく始める」をタップ
- Home画面に遷移せず、ウォークスルー画面に戻る

### 正常ケース

- ウォークスルーを一つずつ遷移（WalkThrough1→2→3→4）した場合は「新しく始める」で正しくHome遷移

## 原因分析

### 現在の実装

```
ContentView.swift
  └─ @State private var isNotFirstLaunch = UserDefaults.standard.bool(...)
      ├─ isNotFirstLaunch == true → Home()
      └─ isNotFirstLaunch == false → WalkThrough1(isNotFirstLaunch: $isNotFirstLaunch)
          └─ NavigationStack
              ├─ 通常遷移 → WalkThrough2() → WalkThrough3() → WalkThrough4()
              └─ スキップ → WalkThrough4()
```

### 問題点

1. **`@State`はUserDefaultsの変更を監視しない**
   - `@State private var isNotFirstLaunch = UserDefaults.standard.bool(...)` は初期化時に一度だけ値を読み込む
   - WalkThrough4で `UserDefaults.standard.set(true, ...)` を実行しても、ContentViewの`@State`は更新されない

2. **`isNotFirstLaunch`バインディングが渡されていない**
   - WalkThrough1は `@Binding var isNotFirstLaunch` を受け取っている
   - しかし、WalkThrough2, 3, 4には渡されていない
   - スキップボタンの `NavigationLink(destination: WalkThrough4())` でもバインディングを渡していない

3. **各WalkThrough画面がNavigationStackを持つ**
   - WalkThrough1, 2, 3, 4がそれぞれNavigationStackを持つ
   - スキップ時にNavigationStackが複雑にネストする

## 修正方針

### 解決策: `@AppStorage` を使用

`@AppStorage` はUserDefaultsの変更を自動的に監視し、値が変更されるとViewを再評価します。

### 修正対象ファイル

| ファイル | 修正内容 |
|---------|---------|
| `ContentView.swift` | `@State` を `@AppStorage` に変更 |
| `WalkThrough1.swift` | `@Binding` を削除（不要になる） |
| `WalkThrough4.swift` | `@AppStorage` を使用してフラグを設定 |

## 修正詳細

### 1. ContentView.swift

**Before**:
```swift
@State private var isNotFirstLaunch = UserDefaults.standard.bool(forKey: "isNotFirstLaunch")

var body: some View {
    if isNotFirstLaunch {
        Home()
    }
    else {
        WalkThrough1(isNotFirstLaunch: $isNotFirstLaunch)
    }
}
```

**After**:
```swift
@AppStorage("isNotFirstLaunch") private var isNotFirstLaunch = false

var body: some View {
    if isNotFirstLaunch {
        Home()
    }
    else {
        WalkThrough1()
    }
}
```

### 2. WalkThrough1.swift

**Before**:
```swift
struct WalkThrough1: View {
    @Binding var isNotFirstLaunch: Bool
    // ...
}
```

**After**:
```swift
struct WalkThrough1: View {
    // isNotFirstLaunchバインディングを削除（使用していなかった）
    // ...
}
```

### 3. WalkThrough4.swift

**Before**:
```swift
ActionButtonBlack(
    title: "begin_anew",
    action: {
        self.navigateToCredentialList = true
        UserDefaults.standard.set(true, forKey: "isNotFirstLaunch")
    }
)
.navigationDestination(isPresented: $navigateToCredentialList) {
    Home()
}
```

**After**:
```swift
@AppStorage("isNotFirstLaunch") private var isNotFirstLaunch = false

ActionButtonBlack(
    title: "begin_anew",
    action: {
        isNotFirstLaunch = true  // ContentViewが自動的に再評価されHome()を表示
    }
)
// navigationDestinationは不要（ContentViewがHome()を表示する）
```

## 完了条件

- [x] ContentView.swiftの修正（@AppStorage使用）
- [x] WalkThrough1.swiftの修正（@Binding削除）
- [x] WalkThrough4.swiftの修正（@AppStorage使用、navigationDestination削除）
- [x] ビルド確認
- [x] スキップ→「新しく始める」でHome遷移確認
- [x] 通常遷移→「新しく始める」でHome遷移確認

## 参考

- [Apple Documentation: AppStorage](https://developer.apple.com/documentation/swiftui/appstorage)
