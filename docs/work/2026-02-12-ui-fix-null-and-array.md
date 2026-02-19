# UI修正: null値と配列表示の改善

## 依頼内容
- クレデンシャルの項目で、null値が`<null>`と表示されるUIがあるので空白表示にする
- クレデンシャルの項目で、配列の項目が`[value1, value2,]`とカッコ付きで表示されるUIがあるのでカッコを除外する

## ブランチ
- 派生元: `fix/dcql-null-claim-matching`
- 作業ブランチ: `fix/ui-null-and-array-display`

## 調査結果

### 問題の原因
1. **`<null>`表示の問題**:
   - `SDJwtUtil.swift`の`convertDisclosureValue`関数で`String(describing: value)`を使用
   - nilやNSNull値が`<null>`として文字列化される

2. **配列のカッコ表示の問題**:
   - `DCQLMatcher.swift`でJWTペイロードの値を変換する際に`JSONSerialization`を使用
   - JSON形式のため配列が`["value1","value2"]`のようにカッコ付きで表示される

### 影響範囲
- `CredentialDetail.swift` - クレデンシャル詳細画面
- `SharingRequest.swift` - クレデンシャル共有リクエスト画面
- `DisclosureRow.swift` - 開示項目の行表示

## 修正内容

### 1. SDJwtUtil.swift (tw2023_wallet/Utils/SDJwtUtil.swift)

`convertDisclosureValue`関数を改善:
- NSNull値のチェックを追加し、空文字を返す
- Optionalのnilチェックをミラーを使って追加
- String型とNSNumber型の明示的な処理を追加
- フォールバックの`String(describing:)`結果から`<null>`等をフィルタリング

```swift
func convertDisclosureValue(value: Any) -> String {
    // Handle nil/null values - return empty string for display
    if value is NSNull {
        return ""
    }

    // Check if value is Optional.none (nil) using reflection
    let mirror = Mirror(reflecting: value)
    if mirror.displayStyle == .optional && mirror.children.isEmpty {
        return ""
    }

    if let boolValue = value as? Bool {
        return boolValue ? "Yes" : "No"
    }
    else if let arrayValue = value as? [Any] {
        // Convert array elements to strings and join with comma (no brackets)
        return arrayValue.map { convertDisclosureValue(value: $0) }.joined(separator: ", ")
    }
    else if let stringValue = value as? String {
        return stringValue
    }
    else if let numberValue = value as? NSNumber {
        return numberValue.stringValue
    }
    else {
        // For other complex types, try to create readable representation
        let described = String(describing: value)
        // Filter out <null> representation
        if described == "<null>" || described == "nil" || described == "Optional(nil)" {
            return ""
        }
        return described
    }
}
```

### 2. DCQLMatcher.swift (tw2023_wallet/Services/OID/DCQLMatcher.swift)

JWTペイロードの値変換を`convertDisclosureValue`関数に統一:
- 個別のif-else分岐を削除
- 共通関数を使用することで一貫したフォーマットを保証

```swift
// Before (各型ごとに分岐、JSONSerializationで配列にカッコ)
if value is NSNull { ... }
else if let strVal = value as? String { ... }
else if let boolVal = value as? Bool { ... }
else if let numVal = value as? NSNumber { ... }
else {
    // JSONSerialization - 配列がカッコ付きになる
    if let data = try? JSONSerialization.data(withJSONObject: value),
       let str = String(data: data, encoding: .utf8) {
        stringValue = str
    } else {
        stringValue = String(describing: value)
    }
}

// After (共通関数に統一)
let stringValue = convertDisclosureValue(value: value)
```

## テスト確認

- [x] ビルド成功
- [x] SDJwtUtilTests - 全てパス (8テスト)
- [ ] null値を持つクレデンシャルで`<null>`が表示されないこと (手動確認)
- [ ] 配列値を持つクレデンシャルでカッコなしで表示されること (手動確認)

## 変更ファイル

1. `tw2023_wallet/Utils/SDJwtUtil.swift`
2. `tw2023_wallet/Services/OID/DCQLMatcher.swift`

## 完了日
2026-02-12
