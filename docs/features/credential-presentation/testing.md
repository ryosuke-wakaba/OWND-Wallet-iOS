# Credential Presentation - Testing

## Unit Tests

### DCQLMatcher Tests

**File**: `tw2023_walletTests/DCQLMatcherTests.swift`

| テストケース | 説明 |
|-------------|------|
| `testClaimsAbsent_AllDisclosuresShouldNotBeSubmitted` | claims absent時、全Disclosureが`isSubmit=false` |
| `testClaimsPresent_AllClaimsAvailable_MatchedClaimsShouldBeSubmitted` | claims present時、要求クレームのみ`isSubmit=true` |
| `testClaimsPresent_SomeClaimsMissing_ShouldReturnNil` | 要求クレームが不足時、マッチ失敗 |
| `testFormatMismatch_ShouldReturnNil` | フォーマット不一致時、マッチ失敗 |
| `testFormatDcSdJwt_ShouldMatch` | dc+sd-jwtフォーマット対応確認 |
| `testVctMatching` | VCT値マッチング確認 |

### Integration Tests

- End-to-endプレゼンテーションフロー
- 実際のVerifierとの連携

## Error Handling

### AuthorizationRequestError

```swift
enum AuthorizationRequestError: Error {
    case authRequestInputError(reason: AuthRequestInputErrorReason)
    case authRequestUnexpectedError(reason: Error)
}

enum AuthRequestInputErrorReason {
    case compliantError(reason: String)
    case queryFetchError
    case parseJsonError
    case clientMetadataFetchError
    case clientMetadataSerializationError
}
```

### OpenIdProviderIllegalStateException

```swift
enum OpenIdProviderIllegalStateException: Error {
    case illegalResponseTypeState
    case illegalResponseModeState
    case illegalClientIdState
    case illegalNonceState
    case illegalState
}
```

### Error Scenarios

| Error | Cause | User Message |
|-------|-------|--------------|
| `queryFetchError` | Request URI取得失敗 | "リクエストの取得に失敗しました" |
| `parseJsonError` | JSON解析失敗 | "リクエストの解析に失敗しました" |
| `clientMetadataFetchError` | Client Metadata取得失敗 | "Verifier情報の取得に失敗しました" |
| No matching credentials | DCQLマッチ失敗 | "該当するクレデンシャルがありません" |

## Performance Metrics

| Metric | Target |
|--------|--------|
| Request解析 | < 1秒 |
| Credential照合 | < 1秒 |
| VP生成 | < 2秒 |
| VP暗号化 | < 1秒 |
| VP送信 | < 3秒 |
| 全体フロー | < 10秒 |

## Test Files

| File | Description |
|------|-------------|
| `tw2023_walletTests/DCQLMatcherTests.swift` | DCQLMatcher単体テスト |
| `tw2023_walletTests/OpenIdProviderTests.swift` | OpenIdProvider単体テスト |
| `tw2023_walletUITests/PresentationUITests.swift` | UIテスト |
