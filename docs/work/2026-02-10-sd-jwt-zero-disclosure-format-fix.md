# SD-JWT ゼロディスクロージャー時のフォーマット修正

## 概要
VP送信時に選択開示項目を送信しない場合、SD-JWTのフォーマットが `<JWT>~~<KB-JWT>`（ダブルチルダ）となっており、RFC 9901の仕様に違反している問題を修正する。

## 問題の詳細

### 現状の動作
選択開示項目がゼロの場合:
- 現在: `<JWT>~~<KB-JWT>` (ダブルチルダ) ❌

### 期待される動作 (RFC 9901)
- 正しい形式: `<JWT>~<KB-JWT>` (シングルチルダ) ✅

### フォーマット仕様

| ケース | 正しい形式 |
|--------|-----------|
| ディスクロージャーなし、KB-JWTあり | `<JWT>~<KB-JWT>` |
| 1つのディスクロージャー、KB-JWTあり | `<JWT>~<D1>~<KB-JWT>` |
| ディスクロージャーなし、KB-JWTなし | `<JWT>~` |

## 原因分析

### 問題箇所1: ProviderTypes.swift (lines 128-131)
```swift
let vpToken =
    issuerSignedJwt + "~"
    + selectedDisclosures.map { $0.disclosure! }.joined(separator: "~") + "~"
    + keyBindingJwt
```

### 問題箇所2: KeyBindingImpl.swift (lines 46-48)
```swift
let sd =
    issuerSignedJwt + "~"
    + selectedDisclosures.map { $0.disclosure! }.joined(separator: "~") + "~"
```

### 問題の原因
- `selectedDisclosures`が空の場合、`joined(separator: "~")`は空文字列を返す
- その結果、`<JWT>~` + `""` + `~` = `<JWT>~~` となる
- KB-JWTを付加すると `<JWT>~~<KB-JWT>` になる

## 修正内容

### 修正方針
ディスクロージャーが存在する場合のみ、ディスクロージャー用のチルダを追加する。

### 修正ファイル
1. `tw2023_wallet/Services/OID/Provider/ProviderTypes.swift`
2. `tw2023_wallet/Services/OID/KeyBindingImpl.swift`

## 進捗

- [x] 問題箇所の特定
- [x] 修正方針の策定
- [x] ProviderTypes.swift の修正
- [x] KeyBindingImpl.swift の修正
- [x] テストの確認・追加
- [x] 動作確認

## 修正済みコード

### ProviderTypes.swift (lines 128-134)
```swift
// RFC 9901: SD-JWT+KB format
// - With disclosures: <JWT>~<D1>~<D2>~<KB-JWT>
// - Without disclosures: <JWT>~<KB-JWT> (single tilde, not double)
let disclosurePart = selectedDisclosures.isEmpty
    ? ""
    : selectedDisclosures.map { $0.disclosure! }.joined(separator: "~") + "~"
let vpToken = issuerSignedJwt + "~" + disclosurePart + keyBindingJwt
```

### KeyBindingImpl.swift (lines 46-52)
```swift
// RFC 9901: SD-JWT format for sd_hash calculation
// - With disclosures: <JWT>~<D1>~<D2>~
// - Without disclosures: <JWT>~ (single tilde, not double)
let disclosurePart = selectedDisclosures.isEmpty
    ? ""
    : selectedDisclosures.map { $0.disclosure! }.joined(separator: "~") + "~"
let sd = issuerSignedJwt + "~" + disclosurePart
```

## 追加テスト

### KeyBindingTests.swift
`testGenerateJwtWithZeroDisclosures()` テストを追加し、ゼロディスクロージャーのケースで正しく動作することを確認。

## テスト結果
全テストパス:
- testGenerateJwtSignature: passed
- testGenerateJwtWithSha256UpperCase: passed
- testGenerateJwtWithUnsupportedAlgorithm: passed
- testGenerateJwtWithZeroDisclosures: passed (新規追加)
- testPerformanceExample: passed

## 参考資料
- https://datatracker.ietf.org/doc/rfc9901/
- https://datatracker.ietf.org/doc/html/draft-ietf-oauth-selective-disclosure-jwt
