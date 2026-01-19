# クレデンシャル発行フローの改善

## 概要

クレデンシャル発行時に以下の2つの問題を修正します：

1. **画面遷移の問題**: 発行成功後に発行要求画面が残り、Home画面に戻らない
2. **不要な画面の削除**: 「その他の証明書」画面（AddCertificates）をスキップ

## 現在のフロー

```
CredentialList
  └─ FloatingActionButton（+）押下
      └─ fullScreenCover: AddCertificates (「その他の証明書」画面) ← 不要
          └─ 「その他の証明書」タップ
              └─ fullScreenCover: QRReaderView
                  └─ QRスキャン成功 → dismiss → onDismiss
                      └─ fullScreenCover: CredentialOfferView
                          └─ 発行成功 → navigateToHome = true ← 問題箇所
                              └─ NavigationStack内でHome()表示 (fullScreenCoverは閉じない)
```

**問題点**:
1. AddCertificates画面が不要なステップになっている
2. 3階層のfullScreenCoverがネストしている
3. CredentialOfferView内でNavigationStack経由の画面遷移が失敗

## 修正後のフロー

```
CredentialList
  └─ FloatingActionButton（+）押下
      └─ fullScreenCover: QRReaderView (直接起動)
          └─ QRスキャン成功 → dismiss → onDismiss
              └─ fullScreenCover: CredentialOfferView
                  └─ 発行成功 → dismiss() → onDismiss
                      └─ CredentialListに戻る (ContentView → Home)
```

## 修正対象ファイル

| ファイル | 修正内容 |
|---------|---------|
| `CredentialList.swift` | AddCertificatesをスキップしてQRReaderViewを直接表示、CredentialOfferView表示ロジックを追加 |
| `CredentialOffer.swift` | `navigateToHome`による遷移を`dismiss()`に変更 |
| `PinCodeInput.swift` | `navigateToCredentialList`による遷移を`dismiss()`に変更、不要なNavigationStack削除 |
| `AddCertificates.swift` | 削除（または将来のマイナンバーカード対応用に保持） |

## 修正詳細

### 1. CredentialList.swift

**Before**:
```swift
@State private var navigateToAddCertificates = false

FloatingActionButton(onButtonTap: {
    navigateToAddCertificates = true
})

.fullScreenCover(isPresented: $navigateToAddCertificates, onDismiss: onDismiss) {
    AddCertificates()
}
```

**After**:
```swift
@State private var showQRReader = false
@State private var showCredentialOffer = false
@State private var nextScreen: ScreensOnFullScreen = .root
@State private var sharedArgs = SharedArgs()

FloatingActionButton(onButtonTap: {
    showQRReader = true
})

.fullScreenCover(isPresented: $showQRReader, onDismiss: didDismissQRReader) {
    QRReaderView(nextScreen: $nextScreen)
        .environment(sharedArgs)
}
.fullScreenCover(isPresented: $showCredentialOffer, onDismiss: didDismissCredentialOffer) {
    if let args = sharedArgs.credentialOfferArgs {
        CredentialOfferView().environment(args)
    }
}

func didDismissQRReader() {
    if nextScreen == .credentialOffer {
        showCredentialOffer = true
        nextScreen = .root
    }
}

func didDismissCredentialOffer() {
    viewModel.loadData()  // クレデンシャル一覧を更新
}
```

### 2. CredentialOffer.swift

**Before**:
```swift
@State private var navigateToHome = false

Task {
    do {
        try await viewModel.sendRequest(txCode: nil)
    } catch {
        showErrorDialog = true
    }
    navigateToHome = true
}

.navigationDestination(isPresented: $navigateToHome, destination: { Home() })
```

**After**:
```swift
@Environment(\.dismiss) private var dismiss

Task {
    do {
        try await viewModel.sendRequest(txCode: nil)
        dismiss()  // fullScreenCoverを閉じる
    } catch {
        showErrorDialog = true
    }
}

// navigationDestination(Home())は削除
```

### 3. PinCodeInput.swift

**Before**:
```swift
@State private var navigateToCredentialList = false

NavigationStack {
    // ...
    Task {
        try await viewModel.sendRequest(txCode: pinCode)
        self.navigateToCredentialList = true
    }
    .navigationDestination(isPresented: $navigateToCredentialList, destination: { CredentialList() })
}
```

**After**:
```swift
@Environment(\.dismiss) private var dismiss

// NavigationStackを削除（親のCredentialOfferViewのNavigationStackを使用）
Group {
    // ...
    Task {
        try await viewModel.sendRequest(txCode: pinCode)
        dismiss()  // CredentialOfferViewに戻り、さらにそこでdismiss()
    }
}
```

**注意**: PinCodeInputからのdismiss()はCredentialOfferViewに戻るだけなので、CredentialOfferView側でも発行成功を検知してdismiss()する仕組みが必要。

### 4. PinCodeInput成功時の画面遷移（改善案）

PinCodeInputでの発行成功時、複数階層のfullScreenCoverを閉じる必要があるため、コールバックパターンを使用：

**CredentialOffer.swift**:
```swift
PinCodeInput(viewModel: self.viewModel, onSuccess: {
    dismiss()  // CredentialOfferViewを閉じる
})
```

**PinCodeInput.swift**:
```swift
var onSuccess: (() -> Void)?

Task {
    try await viewModel.sendRequest(txCode: pinCode)
    onSuccess?()  // 親に成功を通知
}
```

## 完了条件

- [x] CredentialList.swiftの修正（AddCertificatesスキップ）
- [x] CredentialOffer.swiftの修正（dismiss使用）
- [x] PinCodeInput.swiftの修正（コールバック追加）
- [x] CredentialListViewModel.swiftにreloadData()追加
- [x] ビルド確認
- [ ] PIN不要ケースでの動作確認（スキップ）
- [x] PIN必要ケースでの動作確認
- [x] キャンセル時の動作確認
- [x] エラー時の動作確認
- [x] クレデンシャル一覧の更新確認

## 削除対象

- `AddCertificates.swift` - 不要になる（将来のマイナンバーカード対応で復活の可能性あり）

## 参考

- [docs/features/credential-issuance.md](features/credential-issuance.md)
