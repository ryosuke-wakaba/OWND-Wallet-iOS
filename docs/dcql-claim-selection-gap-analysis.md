# DCQL Claim Selection ギャップ分析

## 概要

OID4VP 1.0仕様 Section 6.4.1 のクレーム選択ルールと現在の実装を比較し、不足点・誤りを整理する。

**参照仕様**: https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#section-6.4.1

## 仕様のルール

### ルール1: `claims`が存在しない場合

> If claims is absent, the Verifier is requesting no claims that are selectively disclosable; the Wallet MUST return only the claims that are mandatory to present (e.g., SD-JWT and Key Binding JWT for a Credential of format IETF SD-JWT VC).

**意味**: `claims`がない場合、選択的開示可能なクレームは要求されていない。Walletは必須クレームのみ（SD-JWTとKB-JWT）を返す必要がある。

### ルール2: `claims`が存在し、`claim_sets`が存在しない場合

> If claims is present, but claim_sets is absent, the Verifier requests all claims listed in claims.

**意味**: `claims`があり`claim_sets`がない場合、Verifierは`claims`に列挙されたすべてのクレームを要求している。

### ルール3: `claims`と`claim_sets`の両方が存在する場合

> If both claims and claim_sets are present, the Verifier requests one combination of the claims listed in claim_sets. The order of the options conveyed in the claim_sets array expresses the Verifier's preference for what is returned; the Wallet SHOULD return the first option that it can satisfy. If the Wallet cannot satisfy any of the options, it MUST NOT return any claims.

**意味**: 両方がある場合、`claim_sets`に定義された組み合わせの1つを返す。配列の順序はVerifierの優先度を表し、Walletは最初に満たせるオプションを返すべき。どのオプションも満たせない場合、クレームを返してはならない。

### ルール4: `claim_sets`と`claims`の依存関係

> claim_sets MUST NOT be present if claims is absent.

**意味**: `claims`がない場合、`claim_sets`は存在してはならない。

### ルール5: `values`による値の制限

> When a Claims Query contains a restriction on the values of a claim, the Wallet SHOULD NOT return the claim if its value does not match according to the rules for values defined in Section 6.3

**意味**: クレームに`values`制限がある場合、値が一致しないクレームは返すべきではない（ベストエフォート）。

### ルール6: すべてのクレームが必須

> If the Wallet cannot deliver all claims requested by the Verifier according to these rules, it MUST NOT return the respective Credential.

**意味**: 要求されたすべてのクレームを提供できない場合、そのクレデンシャルを返してはならない。

## 現状の実装分析

### 対象ファイル
- `tw2023_wallet/Services/OID/DCQL.swift` - 型定義
- `tw2023_wallet/Services/OID/DCQLMatcher.swift` - マッチングロジック

### ルール別の実装状況

| ルール | 現状 | 詳細 |
|--------|------|------|
| 1. claims absent | ❌ **誤り** | すべてのクレームを開示する実装になっている |
| 2. claims present, claim_sets absent | ✅ 正しい | 要求されたクレームをすべてチェック |
| 3. claims + claim_sets | ❌ **未実装** | `claim_sets`の型定義・ロジックがない |
| 4. claim_sets依存関係 | ❌ **未実装** | claim_sets自体が未実装 |
| 5. values制限 | ❌ **未実装** | `values`プロパティは存在するが使用されていない |
| 6. すべてのクレーム必須 | ✅ 正しい | `requiredPaths.isSubset(of: availableKeys)`で確認 |

## 問題点の詳細

### 問題1: `claims`が存在しない場合の動作（重大）

**現在のコード** (`DCQLMatcher.swift:79-88`):
```swift
guard let claims = credentialQuery.claims else {
    // No claims specified means all claims are acceptable
    return allDisclosures.map { disclosure in
        DisclosureWithOptionality(
            disclosure: disclosure,
            isSubmit: true,  // ← すべてのクレームを開示
            isUserSelectable: false
        )
    }
}
```

**問題**:
- 現在: すべてのDisclosureを`isSubmit: true`で返している
- 仕様: 必須クレームのみ（SD-JWTとKB-JWT）を返すべき

**影響**: プライバシー違反の可能性。Verifierが要求していないクレームまで開示してしまう。

### 問題2: `claim_sets`が未実装

**現在の型定義** (`DCQL.swift`):
```swift
struct DcqlCredentialQuery: Codable {
    let id: String
    let format: String
    let meta: DcqlCredentialMeta?
    let claims: [DcqlClaimQuery]?
    // claim_sets が存在しない
}
```

**問題**: `claim_sets`プロパティが型定義に存在しない。

**影響**: Verifierが複数のクレーム組み合わせオプションを提示するユースケースに対応できない。

### 問題3: `values`による値制限が未実装

**現在の型定義** (`DCQL.swift:43-53`):
```swift
struct DcqlClaimQuery: Codable {
    let id: String?
    let path: [String]
    let values: [AnyCodableValue]?  // 定義はあるが...
}
```

**マッチングロジック** (`DCQLMatcher.swift:90-97`):
```swift
var requiredPaths = Set<String>()
for claim in claims {
    if let lastPath = claim.path.last {
        requiredPaths.insert(lastPath)
    }
    // values は無視されている
}
```

**問題**: `values`プロパティは型定義に存在するが、マッチングロジックで使用されていない。

**影響**: 値の制限を指定したクエリに対して、制限を無視してクレームを返してしまう。

## 対応予定

### Phase 1: `claims` absent時の動作修正（優先度: 高）

**作業内容**:
- [ ] `matchClaims`関数で`claims`がnilの場合、`isSubmit: false`を返すように修正
- [ ] SD-JWTの必須部分（Issuer-signed JWT + KB-JWT）のみを返す

**修正案**:
```swift
guard let claims = credentialQuery.claims else {
    // claims absent: return only mandatory claims (no selectively disclosable claims)
    return allDisclosures.map { disclosure in
        DisclosureWithOptionality(
            disclosure: disclosure,
            isSubmit: false,  // 選択的開示クレームは含めない
            isUserSelectable: false
        )
    }
}
```

### Phase 2: `claim_sets`の実装（優先度: 中）

**作業内容**:
- [ ] `DcqlCredentialQuery`に`claimSets`プロパティを追加
- [ ] `DcqlClaimSet`型を定義
- [ ] `matchClaims`関数で`claim_sets`ロジックを実装
- [ ] 優先度順に最初に満たせるオプションを選択するロジック

**型定義案**:
```swift
struct DcqlCredentialQuery: Codable {
    let id: String
    let format: String
    let meta: DcqlCredentialMeta?
    let claims: [DcqlClaimQuery]?
    let claimSets: [[String]]?  // 各要素はclaimのid配列

    enum CodingKeys: String, CodingKey {
        case id, format, meta, claims
        case claimSets = "claim_sets"
    }
}
```

### Phase 3: `values`制限の実装（優先度: 低）

**作業内容**:
- [ ] `matchClaims`関数で`values`チェックを追加
- [ ] クレームの値が`values`配列に含まれるか確認
- [ ] 一致しない場合はそのクレームを除外

**修正案**:
```swift
for claim in claims {
    if let lastPath = claim.path.last {
        // Check values restriction if present
        if let values = claim.values, !values.isEmpty {
            guard let claimValue = sourcePayload[lastPath],
                  values.contains(where: { $0.matches(claimValue) }) else {
                continue  // Value doesn't match, skip this claim
            }
        }
        requiredPaths.insert(lastPath)
    }
}
```

## 実装完了: Phase 1

### 修正内容

**ファイル**: `tw2023_wallet/Services/OID/DCQLMatcher.swift:79-90`

```swift
guard let claims = credentialQuery.claims else {
    // OID4VP 1.0 Section 6.4.1: If claims is absent, the Verifier is requesting
    // no claims that are selectively disclosable; the Wallet MUST return only
    // the claims that are mandatory to present (SD-JWT and KB-JWT only).
    return allDisclosures.map { disclosure in
        DisclosureWithOptionality(
            disclosure: disclosure,
            isSubmit: false,  // Do not submit selectively disclosable claims
            isUserSelectable: false
        )
    }
}
```

### テストカバレッジ

**ファイル**: `tw2023_walletTests/DCQLMatcherTests.swift`

| テストケース | 説明 |
|-------------|------|
| testClaimsAbsent_AllDisclosuresShouldNotBeSubmitted | claims absent時、全Disclosureが`isSubmit=false` |
| testClaimsAbsent_ShouldReturnAllDisclosures | claims absent時、マッチは成功しDisclosureは返される |
| testClaimsPresent_AllClaimsAvailable_MatchedClaimsShouldBeSubmitted | claims present時、要求クレームのみ`isSubmit=true` |
| testClaimsPresent_SomeClaimsMissing_ShouldReturnNil | 要求クレームが不足時、マッチ失敗 |
| testClaimsPresent_EmptyClaimsArray_ShouldMatchWithNoClaimsSubmitted | 空claims配列時、全Disclosure`isSubmit=false` |
| testFormatMismatch_ShouldReturnNil | フォーマット不一致時、マッチ失敗 |
| testFormatDcSdJwt_ShouldMatch | dc+sd-jwtフォーマット対応確認 |
| testMultipleCredentialQueries_FirstFails_SecondMatches | 複数クエリの優先度処理 |
| testSingleClaimRequest_ShouldMatchOnlyThatClaim | 単一クレーム要求の動作確認 |
| testAllClaimsRequest_ShouldMatchAllClaims | 全クレーム要求の動作確認 |
| testInvalidSdJwt_ShouldReturnNil | 無効SD-JWT時の動作確認 |
| testDcqlQueryExtension_FirstMatchedCredentialQuery | 拡張メソッドの動作確認 |

## 進捗状況

| Phase | タスク | ステータス | 完了日 |
|-------|--------|-----------|--------|
| 1 | claims absent時の動作修正 | ✅ 完了 | 2025-11-25 |
| 2 | claim_sets実装 | 📋 予定 | - |
| 3 | values制限実装 | 📋 予定 | - |

## 参考資料

- [OID4VP 1.0 Section 6.4.1 - Selecting Claims](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#section-6.4.1)
- [OID4VP 1.0 Section 6.3 - Claims Query](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#section-6.3)
- 実装: `tw2023_wallet/Services/OID/DCQLMatcher.swift`
- 型定義: `tw2023_wallet/Services/OID/DCQL.swift`
