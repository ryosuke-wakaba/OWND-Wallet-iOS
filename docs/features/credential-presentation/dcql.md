# Credential Presentation - DCQL (Digital Credentials Query Language)

## Overview

DCQL (Digital Credentials Query Language) は OID4VP 1.0 で定義されたクレデンシャルクエリ言語です。Verifierが要求するクレデンシャルの条件を指定します。

## Data Structures

**File**: `tw2023_wallet/Services/OID/DCQL.swift`

```swift
/// DCQL Query - Root structure for credential queries
struct DcqlQuery: Codable {
    let credentials: [DcqlCredentialQuery]
}

/// DCQL Credential Query - Defines requirements for a single credential
struct DcqlCredentialQuery: Codable {
    let id: String
    let format: String
    let meta: DcqlCredentialMeta?
    let claims: [DcqlClaimQuery]?
}

/// DCQL Credential Metadata
struct DcqlCredentialMeta: Codable {
    let vctValues: [String]?
}

/// DCQL Claim Query - Defines requirements for claims within a credential
struct DcqlClaimQuery: Codable {
    let id: String?
    let path: [String]
    let values: [AnyCodableValue]?
}
```

## DCQLMatcher

**File**: `tw2023_wallet/Services/OID/DCQLMatcher.swift`

```swift
class DCQLMatcher {
    /// Match credentials against a DCQL query
    func matchCredential(
        query: DcqlQuery,
        sdJwt: String
    ) -> DcqlCredentialMatch?
}

/// Result of matching a credential against a DCQL query
struct DcqlCredentialMatch {
    let credentialQuery: DcqlCredentialQuery
    let disclosuresWithOptionality: [DisclosureWithOptionality]
}

/// Disclosure with submission optionality
struct DisclosureWithOptionality: Codable {
    var disclosure: Disclosure
    var isSubmit: Bool          // true if this claim should be submitted
    var isUserSelectable: Bool  // true if user can toggle submission
}

extension DcqlQuery {
    /// Find the first matching credential query for an SD-JWT
    func firstMatchedCredentialQuery(sdJwt: String) -> DcqlCredentialMatch?
}
```

## Credential Matching Implementation

マッチング処理の流れ：

1. **フォーマット確認** - `vc+sd-jwt` または `dc+sd-jwt` であることを確認
2. **VCT照合** - クレデンシャルの `vct` が `meta.vct_values` に含まれるか確認
3. **クレーム照合** - 要求されたすべてのクレームがクレデンシャルに存在するか確認

```swift
// DCQLMatcher.swift - マッチングの要点
func matchCredential(query: DcqlQuery, sdJwt: String) -> DcqlCredentialMatch? {
    // 1. SD-JWTからDisclosureを抽出
    let allDisclosures = SDJwtUtil.decodeDisclosure(sdJwtParts.disclosures)

    // 2. 各credential queryに対してマッチング
    for credentialQuery in query.credentials {
        // フォーマット確認
        guard credentialQuery.format == "vc+sd-jwt" || credentialQuery.format == "dc+sd-jwt" else {
            continue
        }

        // VCT照合
        if let vctValues = credentialQuery.meta?.vctValues {
            guard let vct = jwtPayload["vct"] as? String,
                  vctValues.contains(vct) else {
                continue
            }
        }

        // クレーム照合
        let matchedClaims = matchClaims(credentialQuery, sourcePayload, allDisclosures)
        if matchedClaims != nil {
            return DcqlCredentialMatch(credentialQuery, matchedClaims)
        }
    }
    return nil
}
```

## Selective Disclosure

SD-JWT形式のクレデンシャルでは、Verifierが要求したクレームのみを開示できます。

### Selective Disclosure Rules (OID4VP 1.0 Section 6.4.1)

| claims | 動作 |
|--------|------|
| absent | 選択的開示クレームなし。必須クレーム（SD-JWT + KB-JWT）のみ返す |
| present (with items) | 指定されたクレームのみ開示 (`isSubmit: true`) |
| present (empty array) | 選択的開示クレームなし |

### Implementation

```swift
// DCQLMatcher.swift - クレーム照合ロジック
private func matchClaims(
    credentialQuery: DcqlCredentialQuery,
    sourcePayload: [String: String],
    allDisclosures: [Disclosure]
) -> [DisclosureWithOptionality]? {
    guard let claims = credentialQuery.claims else {
        // クレーム指定なし = すべてのクレームを開示可能
        return allDisclosures.map {
            DisclosureWithOptionality(disclosure: $0, isSubmit: true, isUserSelectable: false)
        }
    }

    // 要求されたクレームパスを収集
    var requiredPaths = Set<String>()
    for claim in claims {
        if let lastPath = claim.path.last {
            requiredPaths.insert(lastPath)
        }
    }

    // 要求されたすべてのクレームがクレデンシャルに存在するか確認
    let availableKeys = Set(sourcePayload.keys)
    guard requiredPaths.isSubset(of: availableKeys) else {
        return nil  // マッチ失敗
    }

    // Disclosureごとに開示フラグを設定
    return allDisclosures.map { disclosure in
        let isRequired = requiredPaths.contains(disclosure.key ?? "")
        return DisclosureWithOptionality(
            disclosure: disclosure,
            isSubmit: isRequired,      // 要求されたクレームのみ開示
            isUserSelectable: false
        )
    }
}
```

## Implementation Notes

1. **すべての要求クレームが必須**: 現在の実装では、DCQLクエリで指定されたすべてのクレームがクレデンシャルに存在する必要があります。1つでも欠けているとマッチングが失敗します。

2. **発行時の考慮点**: クレデンシャル発行時に、Verifierが要求する可能性のあるすべてのクレームを含めることが重要です。

3. **将来の拡張**:
   - `claim_sets` 対応（複数のクレームセットから選択）
   - `values` 制限対応（特定の値のみ許可）

## Related Files

| File | Description |
|------|-------------|
| `tw2023_wallet/Services/OID/DCQL.swift` | DCQL型定義 |
| `tw2023_wallet/Services/OID/DCQLMatcher.swift` | マッチングロジック |
| `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift` | OID4VPプロバイダー |
| `docs/dcql-claim-selection-gap-analysis.md` | Gap Analysis |

## References

- [DCQL Section 6](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#name-digital-credentials-query-l)
- [Claim Selection Rules Section 6.4.1](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#section-6.4.1)
