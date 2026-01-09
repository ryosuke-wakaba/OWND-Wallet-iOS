# Authentication - Testing

## Unit Tests

### Test Cases

| Test | Description |
|------|-------------|
| `testParseSiopRequest` | SIOP Request解析 |
| `testPairwiseAccountGeneration` | Pairwise Account生成 |
| `testIdTokenGeneration` | ID Token生成 |
| `testIdTokenSignature` | ID Token署名検証 |
| `testHdKeyDerivation` | HD鍵派生 |
| `testMnemonicBackupRestore` | Mnemonic バックアップ/リストア |

### Example Tests

```swift
class AuthenticationTests: XCTestCase {
    func testParseSiopRequest() async throws {
        // Test SIOP request parsing
    }

    func testPairwiseAccountGeneration() throws {
        // Test pairwise account is unique per RP
        let account1 = pairwiseAccount.getAccount(rp: "example.com")
        let account2 = pairwiseAccount.getAccount(rp: "another.org")
        XCTAssertNotEqual(account1?.thumbprint, account2?.thumbprint)
    }

    func testIdTokenGeneration() throws {
        // Test ID Token structure and claims
    }

    func testIdTokenSignature() throws {
        // Test signature verification
    }
}
```

## Integration Tests

- End-to-end認証フロー
- 実際のRPとの連携
- Backup/Restoreフロー

## Error Handling

### Error Types

```swift
enum AuthorizationRequestError: Error {
    case authRequestInputError(reason: AuthRequestInputErrorReason)
    case authRequestUnexpectedError(reason: Error)
}

enum AuthRequestInputErrorReason {
    case compliantError(reason: String)
    case queryFetchError
    case parseJsonError
}
```

### Error Scenarios

| Error | Cause | User Message |
|-------|-------|--------------|
| `queryFetchError` | Request URI取得失敗 | "リクエストの取得に失敗しました" |
| `parseJsonError` | JSON解析失敗 | "リクエストの解析に失敗しました" |
| Invalid signature | 署名検証失敗 | "リクエストの検証に失敗しました" |

## Performance Metrics

| Metric | Target |
|--------|--------|
| Request解析 | < 1秒 |
| Account生成 | < 2秒 |
| ID Token生成 | < 1秒 |
| 全体フロー | < 5秒 |

## Test Files

| File | Description |
|------|-------------|
| `tw2023_walletTests/OpenIdProviderTests.swift` | OpenIdProvider単体テスト |
| `tw2023_walletTests/PairwiseAccountTests.swift` | PairwiseAccount単体テスト |
| `tw2023_walletTests/HDKeyRingTests.swift` | HDKeyRing単体テスト |
