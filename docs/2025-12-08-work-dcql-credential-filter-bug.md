# DCQL Credential Filter Bug Fix

## Status
- [x] Investigation
- [x] Implementation
- [ ] Verification

## Problem

DCQLクエリーにマッチするクレデンシャルが複数存在するにも関わらず、UI上で1件しか選択できない。

### Symptoms

ログでは4件のクレデンシャルがマッチ成功しているが、フィルタリング後は1件のみ表示される。

```
[DCQLMatcher] Query[0] MATCHED with 10 claims  (2番目)
[DCQLMatcher] Query[0] MATCHED with 4 claims   (3番目)
[DCQLMatcher] Query[0] MATCHED with 4 claims   (4番目)
[DCQLMatcher] Query[0] MATCHED with 4 claims   (5番目)
[loadFilteredCredentials] Filtered credentials count: 1
```

## Root Cause

`SharingRequestViewModel.filterCredentialByDcql` (line 443) のフィルタリング条件に問題がある。

```swift
// 問題のコード
return match.disclosuresWithOptionality.contains { $0.isUserSelectable || $0.isSubmit }
```

### Analysis

| クレデンシャル | disclosures | direct payload claims | 要求claimsの取得元 | フィルタ結果 |
|---------------|-------------|----------------------|-------------------|-------------|
| 2番目 | 10個 | 0個 | disclosures | **表示される** |
| 3〜5番目 | 4個 | 6個 | direct payload | **除外される** |

3〜5番目のクレデンシャルは、要求されたclaims（6個）が全て「direct payload」（非選択的開示claims）に含まれている。

```
[DCQLMatcher] Required claims from direct payload (no disclosure needed):
  ["achievement_description", "achievement_title", "date_of_expiry",
   "date_of_issuance", "issuing_authority", "issuing_country"]
[DCQLMatcher] Required claims from disclosures: []
```

そのため、`disclosuresWithOptionality` の中には `isSubmit=true` のものが存在せず、フィルタリング条件を満たさない。

### Why This Happens

DCQLMatcherの `matchClaims` メソッドでは、要求されたclaimsがdirect payloadにある場合、disclosureには `isSubmit=true` を設定しない（disclosureは提出不要のため）。

```swift
// DCQLMatcher.swift - matchClaims
return allDisclosures.map { disclosure in
    if requiredPaths.contains(dkey) {
        // disclosureにある場合のみisSubmit=true
        return DisclosureWithOptionality(..., isSubmit: true, ...)
    } else {
        return DisclosureWithOptionality(..., isSubmit: false, ...)
    }
}
```

## Solution

### Option 1: Simplify Filter Condition (Recommended)

マッチした時点で表示対象とする。

```swift
// Before
if let match = dcqlQuery.firstMatchedCredentialQuery(sdJwt: credential.payload) {
    return match.disclosuresWithOptionality.contains { $0.isUserSelectable || $0.isSubmit }
}

// After
return dcqlQuery.firstMatchedCredentialQuery(sdJwt: credential.payload) != nil
```

**Rationale**: DCQLMatcherがマッチを返すということは、要求されたclaimsが（disclosureまたはdirect payloadとして）存在することを意味する。追加のフィルタリングは不要。

### Option 2: Consider Direct Payload Claims in Filter

direct payload claimsも考慮した条件に変更する。ただし、これは複雑になるため推奨しない。

## Files to Modify

- `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestViewModel.swift` (line 443)

## Testing

### Before Fix
1. 4件マッチするクレデンシャルでVP要求を受信
2. 1件のみ選択可能

### After Fix
1. 4件マッチするクレデンシャルでVP要求を受信
2. 4件すべて選択可能

## References

- docs/features/credential-presentation.md
- tw2023_wallet/Services/OID/DCQLMatcher.swift
