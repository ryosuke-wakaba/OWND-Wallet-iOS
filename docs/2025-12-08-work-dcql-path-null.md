# DCQLクエリのpathにnull値が含まれる場合のデコードエラー修正

## 概要

DCQLクエリのデコード時に、`claims[].path`配列にnull値が含まれている場合にデコードエラーが発生する問題を修正する。

## 背景

クレデンシャル提供リクエストを処理する際、以下のエラーが発生：

```
valueNotFound(Swift.String, Swift.DecodingError.Context(
  codingPath: [..., CodingKeys(stringValue: "path", intValue: nil), _CodingKey(stringValue: "Index 1", intValue: 1)],
  debugDescription: "Cannot get value of type String -- found null value instead",
  underlyingError: nil
))
```

## 原因

`DCQL.swift`の`DcqlClaimQuery`構造体で`path`が`[String]`として定義されているが、実際のリクエストでは`path`配列にnull値が含まれている。

```swift
struct DcqlClaimQuery: Codable {
    let id: String?
    let path: [String]  // ← null値を許容しない
    let values: [AnyCodableValue]?
}
```

## 対象ファイル

- `tw2023_wallet/Services/OID/DCQL.swift`
- `tw2023_wallet/Services/OID/DCQLMatcher.swift`（pathの使用箇所の確認）

## 実装計画

### タスク一覧

- [x] 1. `DcqlClaimQuery.path`の型を`[AnyCodableValue]`に変更
- [x] 2. `DCQLMatcher`でのpath使用箇所を修正
- [x] 3. その他pathを参照している箇所を確認・修正
- [x] 4. ビルド確認
- [ ] 5. 動作確認

## 実装詳細

### 1. DcqlClaimQuery.pathの型変更

```swift
struct DcqlClaimQuery: Codable {
    let id: String?
    let path: [AnyCodableValue]  // String, Int, null を許容
    let values: [AnyCodableValue]?
}
```

### 2. DCQLMatcherでのpath使用箇所の修正

pathを文字列として使用する箇所で、`AnyCodableValue`から文字列/数値を取り出すように修正。

## 進捗

| 日時 | 作業内容 | 状態 |
|------|----------|------|
| 2025-12-08 | 調査・計画作成 | 完了 |
| 2025-12-08 | DcqlClaimQuery.path型変更 | 完了 |
| 2025-12-08 | DCQLMatcher修正 | 完了 |
| 2025-12-08 | ビルド確認 | 完了 |

## 参考

- `docs/features/credential-presentation.md`
- OID4VP DCQL仕様
