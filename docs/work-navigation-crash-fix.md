# NavigationStack クラッシュ問題の修正

## 日付
2024-11-26

## 問題の概要

クレデンシャル選択画面で以下の手順を行うとアプリがクラッシュする:

1. クレデンシャル選択画面を表示して「証明書を選択」をタップ（クレデンシャル詳細画面が表示される）
2. クレデンシャル詳細画面で「教育機関が発行しました」リンクをタップするとクレデンシャル選択画面に戻ってしまう（本来は発行機関の情報を表示するUIが表示される）
3. 「証明書を選択」をタップすると、Fatal errorが発生

### エラーメッセージ
```
SwiftUI/NavigationColumnState.swift:666: Fatal error: 'try!' expression unexpectedly raised an error: SwiftUI.AnyNavigationPath.Error.comparisonTypeMismatch
```

## 根本原因

### 問題1: ネストしたNavigationStack

`IssuerDetail`が自身の`NavigationStack`を持っていた:

```swift
// IssuerDetail.swift (修正前)
var body: some View {
    NavigationStack {  // ← 問題: ネストしたNavigationStack
        VStack { ... }
    }
}
```

`SharingRequest`が`NavigationStack(path: $path)`を使用している中で、`CredentialDetail`から`IssuerDetail`にナビゲートすると、ネストした`NavigationStack`が発生し、ナビゲーション状態が破損。

### 問題2: 異なるナビゲーション方式の混在

- `SharingRequest`: パスベースナビゲーション (`NavigationStack(path: $path)`)
- `CredentialDetail`: Boolean-basedナビゲーション (`navigationDestination(isPresented:)`)

この混在が`comparisonTypeMismatch`エラーの原因:

```swift
// CredentialDetail.swift (修正前)
@State private var navigateToIssuerDetail: Bool = false

.navigationDestination(isPresented: $navigateToIssuerDetail) {
    IssuerDetail(credential: credential)  // ← パスベースのNavigationStack内で使用
}
```

## 修正内容

### 1. IssuerDetailからNavigationStackを削除

**ファイル**: `tw2023_wallet/Feature/IssuerDetail/IssuerDetail.swift`

```swift
// Before
var body: some View {
    NavigationStack {
        VStack { ... }
        .navigationBarTitle(...)
    }
}

// After
var body: some View {
    VStack { ... }
    .navigationBarTitle(...)
}
```

### 2. ScreensOnFullScreenにissuerDetailケースを追加

**ファイル**: `tw2023_wallet/Feature/ScreensOnFullScreen.swift`

```swift
enum ScreensOnFullScreen: Identifiable, Hashable {
    case root
    case credentialList
    case credentialDetail(Credential)
    case issuerDetail(Credential)  // ← 追加
    case credentialOffer
    case sharingRequest
    case verification
    ...
}
```

### 3. CredentialDetailでパスベースナビゲーションに変更

**ファイル**: `tw2023_wallet/Feature/Credentials/Views/CredentialDetail.swift`

```swift
// Before
@State private var navigateToIssuerDetail: Bool = false

.onTapGesture {
    self.navigateToIssuerDetail = true
}

.navigationDestination(isPresented: $navigateToIssuerDetail) {
    IssuerDetail(credential: credential)
}

// After
.onTapGesture {
    path.append(.issuerDetail(credential))  // パスベースナビゲーション
}
// navigationDestination(isPresented:) は削除
```

### 4. SharingRequestにissuerDetailのnavigationDestinationを追加

**ファイル**: `tw2023_wallet/Feature/ShareCredential/Views/SharingRequest.swift`

```swift
.navigationDestination(for: ScreensOnFullScreen.self) { screen in
    switch screen {
        case .credentialList:
            CredentialListForSharing()
        case .credentialDetail(let credential):
            CredentialDetail(credential: credential, path: $path)
        case .issuerDetail(let credential):  // ← 追加
            IssuerDetail(credential: credential)
        default:
            EmptyView()
    }
}
```

### 5. CredentialListでパスベースNavigationStackを使用

**ファイル**: `tw2023_wallet/Feature/Credentials/Views/CredentialList.swift`

通常のクレデンシャル一覧画面からも発行者リンクが機能するように:

1. `NavigationStack`を`NavigationStack(path: $dummyPath)`に変更（パスをバインド）
2. `navigationDestination`を追加

```swift
// Before
NavigationStack {
    ...
}

// After
NavigationStack(path: $dummyPath) {
    ...
    .navigationDestination(for: ScreensOnFullScreen.self) { screen in
        switch screen {
            case .issuerDetail(let credential):
                IssuerDetail(credential: credential)
            default:
                EmptyView()
        }
    }
}
```

**注意**: `dummyPath`は元々`CredentialDetail`のインターフェースを満たすために存在していたが、`NavigationStack`にバインドされていなかったため`path.append()`が機能しなかった。

### 6. IssuerDetailプレビューをNavigationStackでラップ

```swift
#Preview("verified issuer") {
    NavigationStack {  // ← NavigationStackでラップ
        IssuerDetail(
            viewModel: IssuerDetailPreviewModel(),
            issuerMetadata: PreviewSampleData.sampleMetadata()
        )
    }
}
```

## 修正したファイル

- `tw2023_wallet/Feature/IssuerDetail/IssuerDetail.swift`
- `tw2023_wallet/Feature/ScreensOnFullScreen.swift`
- `tw2023_wallet/Feature/Credentials/Views/CredentialDetail.swift`
- `tw2023_wallet/Feature/ShareCredential/Views/SharingRequest.swift`
- `tw2023_wallet/Feature/Credentials/Views/CredentialList.swift`

## 教訓

### SwiftUI NavigationStackのベストプラクティス

1. **NavigationStackのネストを避ける**
   - 子ビューには`NavigationStack`を含めない
   - ルートビューのみが`NavigationStack`を持つ

2. **ナビゲーション方式を統一する**
   - パスベースナビゲーション (`NavigationStack(path:)`) を使用する場合、
     子ビューでは `navigationDestination(isPresented:)` を避ける
   - 代わりに `path.append()` を使用

3. **スクリーン列挙型を活用する**
   - すべてのナビゲーション可能な画面を `enum` で定義
   - `Hashable`に準拠させてパスで使用可能にする

4. **プレビューでのNavigationStack**
   - ビューからNavigationStackを削除した場合、プレビューでラップする
