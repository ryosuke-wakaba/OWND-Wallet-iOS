# DCQLMatcherTests.swift

**パス**: `tw2023_walletTests/DCQLMatcherTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/DCQLMatcher.swift`

**概要**: OID4VP 1.0 Section 6.4.1に基づくDCQL（Digital Credentials Query Language）の資格情報マッチングロジックをテストします。

---

## 基本テスト（全クレームがDisclosure形式のSD-JWT）

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testClaimsAbsent_AllDisclosuresShouldNotBeSubmitted` | claims欠落時の動作 | 全Disclosureが`isSubmit=false`になること |
| `testClaimsPresent_AllClaimsAvailable_MatchedClaimsShouldBeSubmitted` | claims指定時の動作 | 要求クレームのみ`isSubmit=true`になること |
| `testClaimsPresent_SomeClaimsMissing_ShouldReturnNil` | 要求クレーム不足時 | マッチ失敗（nil返却）すること |
| `testFormatMismatch_ShouldReturnNil` | フォーマット不一致時 | マッチ失敗すること |
| `testFormatDcSdJwt_ShouldMatch` | dc+sd-jwtフォーマット | dc+sd-jwtフォーマットが正しくマッチすること |
| `testSingleClaimRequest_ShouldMatchOnlyThatClaim` | 単一クレーム要求 | 指定した1クレームのみマッチすること |
| `testAllClaimsRequest_ShouldMatchAllClaims` | 全クレーム要求 | 全クレームがマッチすること |
| `testInvalidSdJwt_EmptyString_ShouldReturnNil` | 不正なSD-JWT | 空文字列でマッチ失敗すること |
| `testVctMatch_ShouldMatch` | VCTマッチング | VCT（Verifiable Credential Type）値がマッチすること |

---

## ハイブリッドSD-JWTテスト（JWTペイロード直接 + Disclosure混在）

SD-JWT VC Type Metadataの`selectivelyDisclosable: "never"`設定により、一部クレームがJWTペイロードに直接含まれ、一部がDisclosure形式になるケースをテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testHybridSdJwt_DirectPayloadClaimsRequested_ShouldMatch` | ペイロード直接クレーム要求 | JWTペイロード内の直接クレームを検索・マッチできること |
| `testHybridSdJwt_BothDirectAndDisclosureClaimsRequested_ShouldMatch` | 両方のクレーム要求 | 直接クレーム＋Disclosureクレーム両方をマッチできること |
| `testHybridSdJwt_NonExistentClaimRequested_ShouldReturnNil` | 存在しないクレーム要求 | 存在しないクレーム要求でマッチ失敗すること |
| `testHybridSdJwt_ClaimsAbsent_AllDisclosuresShouldNotBeSubmitted` | claims欠落時（ハイブリッド） | ハイブリッドSD-JWTでclaims省略時の正しい動作 |
| `testHybridSdJwt_ReservedClaimsNotTreatedAsCredentialClaims` | 予約済みクレーム除外 | iss, vct, _sd等の予約済みJWTクレームが検索対象外であること |

---

## ハイブリッドSD-JWT対応

DCQLMatcherは以下の2種類のクレームソースを検索します：

1. **Disclosureベースクレーム**: `_sd`配列経由で開示される選択的開示クレーム
2. **JWTペイロード直接クレーム**: `selectivelyDisclosable: "never"`指定されたクレーム

```swift
// 予約済みJWTクレーム（検索対象外）
private static let reservedJwtClaims: Set<String> = [
    "iss", "sub", "aud", "exp", "nbf", "iat", "jti",  // 標準JWTクレーム
    "vct", "cnf", "_sd", "_sd_alg", "status"           // SD-JWT固有クレーム
]
```

---

## テストデータ

### 基本テスト用SD-JWT（全クレームがDisclosure）

テストで使用するSD-JWTには以下のクレームが含まれます：
- `verified_at`
- `last_name`
- `first_name`
- `is_older_than_15`
- `is_older_than_18`
- `is_older_than_20`
- `is_older_than_65`

### ハイブリッドテスト用SD-JWT

`createHybridSdJwt()`メソッドで生成されるテストデータ：

| クレーム | 格納場所 | 説明 |
|---------|---------|------|
| `issuing_authority` | JWTペイロード直接 | `selectivelyDisclosable: "never"` 相当 |
| `issuing_country` | JWTペイロード直接 | `selectivelyDisclosable: "never"` 相当 |
| `family_name` | Disclosure | 選択的開示クレーム |
| `given_name` | Disclosure | 選択的開示クレーム |
| `vct` | JWTペイロード直接 | `urn:example:hybrid_credential` |

---

## OID4VP 1.0 Section 6.4.1 選択的開示ルール

| claims | 動作 |
|--------|------|
| absent（欠落） | 選択的開示クレームなし。必須クレーム（SD-JWT + KB-JWT）のみ返す |
| present（指定あり） | 指定されたクレームのみ開示 (`isSubmit: true`) |
| present（空配列） | 選択的開示クレームなし |
