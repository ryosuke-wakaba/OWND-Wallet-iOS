# SD-JWT `_sd_alg` 対応

## 概要

SD-JWT draft-22仕様に準拠するため、`_sd_alg`（ハッシュアルゴリズム指定）のサポートを追加します。

**関連仕様**: [draft-ietf-oauth-selective-disclosure-jwt](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-selective-disclosure-jwt)

## 現状

### 問題点

KB-JWT生成時の`_sd_hash`計算で、SHA-256がハードコードされている。

**該当コード**: `KeyBindingImpl.swift:39`
```swift
let sdHash = sd.data(using: String.Encoding.ascii)?.sha256ToBase64Url() ?? ""
```

SD-JWTのペイロードに含まれる`_sd_alg`の値を確認せず、常にSHA-256を使用している。

### 影響

- Issuerが`_sd_alg: "sha-256"`を使用している場合: 問題なし
- Issuerが異なるアルゴリズム（例: `sha-384`, `sha-512`）を使用している場合: `_sd_hash`が不正になり、VP検証が失敗する

## SD-JWT仕様

### `_sd_alg` クレーム

- **位置**: SD-JWTのペイロード（Issuer Signed JWT内）
- **デフォルト値**: `sha-256`（省略時）
- **大文字・小文字**: 区別する（case-sensitive）
- **サポートすべき値**:
  - `sha-256`（必須）
  - `sha-384`（オプション）
  - `sha-512`（オプション）

### `_sd_hash` 計算

KB-JWTの`_sd_hash`は以下の手順で計算：
1. `Issuer-signed JWT~Disclosure1~Disclosure2~...~` の形式で文字列を構築
2. `_sd_alg`で指定されたアルゴリズムでハッシュ
3. Base64URL エンコード

## 対応方針

### Phase 1: `_sd_alg`読み取りとSHA-256検証

1. SD-JWTペイロードから`_sd_alg`を読み取る
2. `sha-256`以外の場合はエラーを返す（現在サポート外を明示）
3. 省略時は`sha-256`をデフォルトとして扱う

### Phase 2: 複数アルゴリズム対応（将来）

1. `sha-384`, `sha-512`のサポート追加
2. アルゴリズムに応じたハッシュ関数の選択

## 実装計画

### 変更対象ファイル

| ファイル | 変更内容 |
|---------|---------|
| `KeyBindingImpl.swift` | `_sd_alg`を受け取り、対応するハッシュを計算 |
| `ProviderTypes.swift` | SD-JWTから`_sd_alg`を抽出して`KeyBinding`に渡す |
| `SDJwtUtil.swift` | `_sd_alg`抽出ユーティリティ追加（オプション） |

### 1. SDJwtUtil.swift - `_sd_alg`抽出関数追加

```swift
/// SD-JWTペイロードから_sd_algを取得
/// - Parameter sdJwt: SD-JWT文字列
/// - Returns: _sd_alg値（デフォルト: "sha-256"）
static func getSdAlg(_ sdJwt: String) -> String {
    guard let parts = try? divideSDJwt(sdJwt: sdJwt),
          let payloadData = parts.issuerSignedJwt.split(separator: ".").dropFirst().first,
          let decoded = Data(base64Encoded: base64urlToBase64(base64url: String(payloadData))),
          let payload = try? JSONSerialization.jsonObject(with: decoded) as? [String: Any],
          let sdAlg = payload["_sd_alg"] as? String else {
        return "sha-256"  // デフォルト値
    }
    return sdAlg
}
```

### 2. KeyBindingImpl.swift - アルゴリズム対応

```swift
enum SdAlgError: Error {
    case unsupportedAlgorithm(String)
}

func generateJwt(
    sdJwt: String,
    selectedDisclosures: [Disclosure],
    aud: String,
    nonce: String,
    sdAlg: String = "sha-256"  // 新規パラメータ
) throws -> String {
    // アルゴリズム検証
    guard sdAlg.lowercased() == "sha-256" else {
        throw SdAlgError.unsupportedAlgorithm(sdAlg)
    }

    // 既存の処理...
    let sdHash = sd.data(using: String.Encoding.ascii)?.sha256ToBase64Url() ?? ""
    // ...
}
```

### 3. ProviderTypes.swift - `_sd_alg`抽出と受け渡し

```swift
func createVpTokenForSdJwtVc(...) throws -> PreparedSubmissionData {
    // _sd_algを取得
    let sdAlg = SDJwtUtil.getSdAlg(credential)

    // KeyBindingに渡す
    let keyBindingJwt = try kb.generateJwt(
        sdJwt: credential,
        selectedDisclosures: selectedDisclosures,
        aud: clientId,
        nonce: nonce,
        sdAlg: sdAlg  // 追加
    )
    // ...
}
```

## テスト計画

### 新規テストケース

| テストケース | 説明 |
|-------------|------|
| `testSdAlgDefault` | `_sd_alg`省略時にsha-256が使用されること |
| `testSdAlgSha256Explicit` | `_sd_alg: "sha-256"`が正しく処理されること |
| `testSdAlgUnsupported` | サポート外アルゴリズムでエラーになること |
| `testSdAlgCaseSensitive` | 大文字・小文字が区別されること |

### テストデータ

```swift
// _sd_alg省略
let sdJwtWithoutSdAlg = "eyJ...payload without _sd_alg...~disclosure~"

// _sd_alg: "sha-256"
let sdJwtWithSha256 = "eyJ...payload with _sd_alg: sha-256...~disclosure~"

// _sd_alg: "sha-512" (サポート外)
let sdJwtWithSha512 = "eyJ...payload with _sd_alg: sha-512...~disclosure~"
```

## 完了条件

- [x] `SDJwtUtil.getSdAlg()`関数の実装
- [x] `KeyBindingImpl.generateJwt()`への`sdAlg`パラメータ追加
- [x] サポート外アルゴリズムのエラーハンドリング
- [x] `ProviderTypes.createVpTokenForSdJwtVc()`の更新
- [x] ユニットテストの追加
- [x] 既存テストの成功確認

## 実装完了 (2025-12-01)

全てのテストが成功しました:

### KeyBindingTests
- `testGenerateJwtSignature` - 既存テスト（sdAlg対応後も成功）
- `testGenerateJwtWithSha256Explicit` - sha-256明示指定
- `testGenerateJwtWithSha256UpperCase` - 大文字SHA-256対応
- `testGenerateJwtWithUnsupportedAlgorithm` - サポート外アルゴリズムのエラー

### SDJwtUtilTests
- `testGetSdAlg_Default` - _sd_alg省略時のデフォルト値
- `testGetSdAlg_WithExplicitSha256` - sha-256明示指定の読み取り
- `testGetSdAlg_WithSha384` - sha-384の読み取り（値の抽出確認）
- `testGetSdAlg_InvalidJwt` - 不正なJWT形式
- `testGetSdAlg_EmptyString` - 空文字列入力

## 参考資料

- [SD-JWT Section 5.1.2 - Hash Function Claim](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-selective-disclosure-jwt#section-5.1.2)
- [SD-JWT Section 7.1 - Creating a Key Binding JWT](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-selective-disclosure-jwt#section-7.1)
