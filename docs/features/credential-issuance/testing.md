# Credential Issuance - Testing

## Unit Tests

```swift
class CredentialIssuanceTests: XCTestCase {
    func testParseValidOffer() async throws {
        // Test credential offer parsing
    }

    func testParseInvalidOffer() async throws {
        // Test error handling
    }

    func testGetIssuerMetadata() async throws {
        // Test metadata retrieval
    }

    func testGenerateKBJWT() throws {
        // Test KB-JWT generation
    }
}
```

### Test Cases

| Test | Description |
|------|-------------|
| `testParseValidOffer` | 有効なCredential Offerの解析 |
| `testParseInvalidOffer` | 不正なOfferのエラーハンドリング |
| `testGetIssuerMetadata` | Issuerメタデータ取得 |
| `testGenerateKBJWT` | Key Binding JWT生成 |
| `testDPoPProofGeneration` | DPoP Proof生成 |
| `testAccessTokenHash` | Access Token Hash計算 |

## Integration Tests

- End-to-end発行フローテスト
- 実際のIssuerとの連携テスト（テスト環境）

### Test Scenarios

1. **Happy Path**: QRスキャン → メタデータ取得 → トークン取得 → Credential発行 → 保存
2. **Network Error**: ネットワーク切断時の適切なエラーハンドリング
3. **Invalid Offer**: 不正なQRコードのハンドリング
4. **Token Expiry**: 期限切れトークンの処理

## UI Tests

- QRコードスキャンフロー
- エラーハンドリング
- キャンセルフロー

## Error Handling

### Error Types

```swift
enum CredentialIssuanceError: Error {
    case invalidOffer(String)
    case networkError(Error)
    case invalidMetadata(String)
    case authorizationFailed(String)
    case credentialRequestFailed(String)
    case invalidCredential(String)
    case storageFailed(Error)
}
```

### User-Facing Messages

| Error | User Message |
|-------|--------------|
| `invalidOffer` | "Invalid QR code. Please scan a valid credential offer." |
| `networkError` | "Network error. Please check your connection and try again." |
| `authorizationFailed` | "Authorization failed. Please try again." |
| `credentialRequestFailed` | "Failed to receive credential. Please contact the issuer." |
| `invalidCredential` | "Received credential is invalid." |
| `storageFailed` | "Failed to save credential. Please try again." |

## Performance Metrics

| Metric | Target |
|--------|--------|
| QR Code scan to display | < 1 second |
| Metadata retrieval | < 2 seconds |
| Token exchange | < 3 seconds |
| Credential issuance | < 5 seconds |
| Total flow | < 10 seconds |

## Analytics & Monitoring

### Events to Track

| Event | Description |
|-------|-------------|
| `credential_issuance_started` | 発行フロー開始 |
| `credential_issuance_completed` | 発行成功 |
| `credential_issuance_failed` | 発行失敗 |
| `qr_scan_success` | QRスキャン成功 |
| `qr_scan_failed` | QRスキャン失敗 |

### Metrics

- 発行成功率
- 平均発行時間
- エラー発生率（種類別）

## Test Files

| File | Description |
|------|-------------|
| `tw2023_walletTests/VCIClientTests.swift` | VCI Client単体テスト |
| `tw2023_walletTests/DPoPServiceTests.swift` | DPoP Service単体テスト |
| `tw2023_walletUITests/CredentialIssuanceUITests.swift` | UIテスト |
