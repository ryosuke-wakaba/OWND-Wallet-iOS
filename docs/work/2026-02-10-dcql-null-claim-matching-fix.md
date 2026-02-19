# DCQL クレームマッチング: Null/空値対応修正

## 概要
SD-JWT形式のクレデンシャルで、DCQLクエリによる選択開示時に、クレーム値がnull/空の場合にクレデンシャルが選択できない問題を修正。

## 問題の詳細

### 現状の動作
- DCQLクエリで特定のクレームを要求した際、クレームの値がnullまたは空の場合にマッチングに失敗
- 結果として、該当クレデンシャルが選択できない

### 期待される動作
- クレームのKEYが存在すれば、値がnull/空でもマッチングに成功すべき
- Verifierは「このクレームが存在するか」をチェックしており、値の有無は問わない

## 原因分析

### 問題箇所1: DCQLMatcher.swift (lines 38-51)
```swift
// 修正前: 値がnilの場合はsourcePayloadに追加されない
var sourcePayload = Dictionary(
    uniqueKeysWithValues: allDisclosures.compactMap { disclosure in
        if let key = disclosure.key, let value = disclosure.value {
            return (key, value)
        } else {
            return nil  // ← 値がnilの場合、クレームキーも除外される
        }
    }
)
```

### 問題箇所2: 直接ペイロードクレームのNSNull処理
JWTペイロードにnull値のクレームがある場合、明示的なNSNull処理がなかった。

## 修正内容

### 修正1: sourcePayload構築ロジック
```swift
// 修正後: クレームキーが存在すれば、値がnilでも追加
var sourcePayload = Dictionary(
    uniqueKeysWithValues: allDisclosures.compactMap { disclosure in
        if let key = disclosure.key {
            return (key, disclosure.value ?? "")
        } else {
            return nil
        }
    }
)
```

### 修正2: 直接ペイロードクレームのNSNull対応
```swift
// NSNullを明示的に処理
let stringValue: String
if value is NSNull {
    stringValue = ""
} else if let strVal = value as? String {
    // ...
}
```

## 修正ファイル
- `tw2023_wallet/Services/OID/DCQLMatcher.swift`
- `tw2023_walletTests/DCQLMatcherTests.swift` (テスト追加・更新)

## 追加テスト
- `testNullValueClaim_ShouldMatchWhenRequested`: null値クレームのマッチングテスト
- `testMixedNullAndValueClaims_ShouldMatchAll`: null値と通常値の混合テスト
- `testEmptyStringValueClaim_ShouldMatch`: 空文字列値のテスト

## テスト結果
全22テストがパス:
- 新規追加テスト3件: パス
- 既存テスト19件: パス (一部期待値を更新)

## 進捗
- [x] 問題箇所の特定
- [x] 修正方針の策定
- [x] DCQLMatcher.swift の修正
- [x] テストの追加・更新
- [x] 動作確認
