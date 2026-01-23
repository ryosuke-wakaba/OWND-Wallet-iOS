# Wallet Attestation Implementation

## Status
- [x] Draft
- [ ] Review
- [ ] Approved
- [x] Implemented
- [ ] Verified

## Overview

ウォレットアテステーション機能を実装します。本来は外部のWallet Providerがアテステーションを発行しますが、本実装ではウォレット内部で擬似的にWallet Provider機能を持ちます。

### 関連仕様
- [OID4VCI Appendix E - Wallet Attestations](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#appendix-E)
- [OAuth 2.0 Attestation-Based Client Authentication](https://drafts.oauth.net/draft-ietf-oauth-attestation-based-client-auth/draft-ietf-oauth-attestation-based-client-auth.html)
- [HAIP 4.4.1 - Wallet Attestation](https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-1_0-05.html#name-wallet-attestation)

## Requirements

### 1. Settings Toggle
- 設定画面に「クライアント認証」トグルを追加
- 有効/無効をUserDefaultsに保存

### 2. Pseudo Wallet Provider
- ビルド時にProvider用のキーペア（秘密鍵PEM + 証明書PEM）をバンドル
- トグル有効時にClient Attestation JWTを生成・保存

### 3. Client Attestation JWT
```
Header:
  typ: oauth-client-attestation+jwt
  alg: ES256
  x5c: [certificate chain]

Payload:
  iss: <wallet-provider-identifier>
  sub: <client_id> (全ウォレットインスタンス共通)
  exp: <expiration>
  nbf: <not-before>
  cnf: { jwk: <public-key-from-key-alias> }
  wallet_name: "OWND Wallet" (optional)
  wallet_link: <url> (optional)
```

### 4. Client Attestation PoP JWT
```
Header:
  typ: oauth-client-attestation-pop+jwt
  alg: ES256

Payload:
  iss: <client_id> (= sub of Client Attestation)
  aud: <authorization-server-issuer>
  jti: <unique-identifier>
  iat: <issued-at>
```

### 5. Token Endpoint Integration
- クライアント認証有効時、トークンリクエストに以下のヘッダーを追加:
  - `OAuth-Client-Attestation: <client-attestation-jwt>`
  - `OAuth-Client-Attestation-PoP: <client-attestation-pop-jwt>`

## Implementation Plan

### Phase 1: Infrastructure

#### 1.1 Provider Key Bundle
- [ ] Provider秘密鍵 (`WalletProviderCert/wallet-provider-private.key`) を配置 (要準備)
- [ ] Provider証明書 (`WalletProviderCert/wallet-provider.cer`) を配置 (要準備)
- [x] PEM読み込みユーティリティを実装 (`tw2023_wallet/Utils/PEMUtils.swift`)
- [x] ビルドスクリプトでWalletProviderCertからバンドルにコピー

#### 1.2 Settings & Storage
- [x] `PreferencesDataStore` に `useClientAttestation` 設定を追加
- [x] `PreferencesDataStore` に Client Attestation JWT 保存機能を追加
- [x] Settings UI にトグルを追加

### Phase 2: Client Attestation Generation

#### 2.1 WalletAttestationService
新規ファイル: `tw2023_wallet/Services/WalletAttestation/WalletAttestationService.swift`

```swift
class WalletAttestationService {
    static let shared = WalletAttestationService()

    // Key alias for attestation key pair (cnf claim)
    static let keyAlias = "walletAttestationKey"

    /// Generate Client Attestation JWT
    func generateClientAttestation() throws -> String

    /// Generate Client Attestation PoP JWT
    func generateClientAttestationPoP(audience: String) throws -> String

    /// Check if attestation is enabled and valid
    func isAttestationEnabled() -> Bool

    /// Get stored Client Attestation (or regenerate if expired)
    func getClientAttestation() throws -> String
}
```

#### 2.2 PEM Utilities
新規ファイル: `tw2023_wallet/Utils/PEMUtils.swift`

```swift
enum PEMUtils {
    /// Load private key from bundled PEM file
    static func loadPrivateKey(filename: String) throws -> SecKey

    /// Load certificate from bundled PEM file
    static func loadCertificate(filename: String) throws -> SecCertificate

    /// Get certificate chain as base64 strings for x5c header
    static func getCertificateChain(filename: String) throws -> [String]
}
```

### Phase 3: VCI Integration

#### 3.1 VCIClient Updates
ファイル: `tw2023_wallet/Services/OID/VCI/VCIClient.swift`

- [x] `issueToken()` にクライアント認証パラメータを追加
- [x] `postTokenRequest()` にAttestation HTTPヘッダーを追加

```swift
func issueToken(
    txCode: String?,
    useDPoP: Bool = true,
    useClientAttestation: Bool = false,  // 追加
    authorizationServerIssuer: String? = nil,  // 追加 (PoP用)
    using session: URLSession = URLSession.shared
) async throws -> OAuthTokenResponse
```

### Phase 4: Testing

#### 4.1 Unit Tests
- [x] `WalletAttestationServiceTests` - JWT生成テスト
- [x] `PEMUtilsTests` - PEM読み込みテスト
- [x] `VCIClientTests` - Attestationヘッダー送信テスト

#### 4.2 Integration Tests
- [ ] トグル有効化 → Attestation生成フロー
- [ ] トークンリクエスト with Attestationヘッダー

## Test Cases

### PEMUtilsTests (`tw2023_walletTests/Utils/PEMUtilsTests.swift`)

PEM形式のファイル解析ユーティリティのテスト。

| テストケース | 説明 |
|------------|------|
| `testCreatePrivateKeyFromPKCS8PEM` | PKCS#8形式のPEMから秘密鍵を作成できることを確認 |
| `testCreatePrivateKeyFromInvalidPEMThrows` | 無効なPEMからは`PEMError`がスローされることを確認 |
| `testCreatePrivateKeyFromEmptyStringThrows` | 空文字列からは`PEMError`がスローされることを確認 |
| `testExtractCertificateChainForX5C` | 複数証明書を含むPEMからx5cヘッダー用のbase64チェーンを抽出できることを確認 |
| `testExtractSingleCertificateChain` | 単一証明書PEMから1つの証明書を抽出できることを確認 |
| `testExtractCertificateChainFromInvalidPEMThrows` | 無効なPEMからは`invalidPEMFormat`エラーがスローされることを確認 |
| `testExtractedBase64HasNoNewlines` | 抽出されたbase64に改行が含まれないことを確認（x5c要件） |
| `testCreateCertificateFromPEM` | PEMから`SecCertificate`を作成できることを確認 |
| `testCreateCertificateFromInvalidPEMThrows` | 無効なPEMからは`PEMError`がスローされることを確認 |
| `testPEMErrorDescriptions` | 全ての`PEMError`にローカライズされた説明があることを確認 |
| `testFileNotFoundErrorIncludesFilename` | `fileNotFound`エラーにファイル名が含まれることを確認 |

### WalletAttestationServiceTests (`tw2023_walletTests/Services/WalletAttestation/WalletAttestationServiceTests.swift`)

Wallet Attestation JWT生成サービスのテスト。

| テストケース | 説明 | 仕様参照 |
|------------|------|---------|
| `testClientAttestationPoPJWTHeaderFormat` | PoP JWTのヘッダー形式を検証（`typ: oauth-client-attestation-pop+jwt`, `alg: ES256`） | OAuth Attestation-Based Client Auth |
| `testClientAttestationPoPJWTRequiredClaims` | PoP JWTに必須クレーム（`iss`, `aud`, `jti`, `iat`）が含まれることを確認 | OAuth Attestation-Based Client Auth |
| `testClientAttestationPoPJWTAudienceMatchesInput` | PoP JWTの`aud`が入力されたaudience（認可サーバーissuer）と一致することを確認 | OAuth Attestation-Based Client Auth |
| `testClientAttestationPoPJWTUniqueJti` | 各PoP JWTが一意の`jti`を持つことを確認（リプレイ攻撃防止） | OAuth Attestation-Based Client Auth |
| `testClientAttestationPoPJWTIssMatchesClientId` | PoP JWTの`iss`がClient Attestationの`sub`（client_id）と一致することを確認 | OAuth Attestation-Based Client Auth |
| `testGeneratePoPThrowsWhenNotEnabled` | アテステーションが無効の場合に`attestationNotEnabled`エラーがスローされることを確認 | - |
| `testIsAttestationEnabledReflectsSettings` | `isAttestationEnabled()`が設定値を正しく反映することを確認 | - |

### VCIClientTests - Attestationヘッダーテスト (`tw2023_walletTests/VCIClientTests.swift`)

トークンリクエストにおけるAttestationヘッダー送信のテスト。

| テストケース | 説明 |
|------------|------|
| `testTokenRequestIncludesAttestationHeaders` | クライアント認証有効時、トークンリクエストに`OAuth-Client-Attestation`と`OAuth-Client-Attestation-PoP`ヘッダーが含まれることを確認。各ヘッダーが有効なJWT形式（3パート）であることも検証 |
| `testTokenRequestExcludesAttestationHeadersWhenDisabled` | クライアント認証無効時、トークンリクエストにAttestationヘッダーが含まれないことを確認 |

### テスト実行時の注意事項

- `testTokenRequestIncludesAttestationHeaders`は、Provider証明書がバンドルに含まれていない場合はスキップされます
- テスト用の証明書データはテストファイル内にハードコードされています（実際のProvider証明書は不要）

## File Changes

### New Files
| Path | Description |
|------|-------------|
| `tw2023_wallet/Services/WalletAttestation/WalletAttestationService.swift` | Attestation生成サービス |
| `tw2023_wallet/Utils/PEMUtils.swift` | PEMファイル読み込みユーティリティ |
| `WalletProviderCert/wallet-provider-private.key` | Provider秘密鍵 (要準備、ビルド時コピー) |
| `WalletProviderCert/wallet-provider.cer` | Provider証明書 (要準備、ビルド時コピー) |
| `tw2023_walletTests/Utils/PEMUtilsTests.swift` | PEMUtilsユニットテスト |
| `tw2023_walletTests/Services/WalletAttestation/WalletAttestationServiceTests.swift` | WalletAttestationServiceユニットテスト |

### Modified Files
| Path | Changes |
|------|---------|
| `tw2023_wallet/datastore/PreferencesDataStore.swift` | `useClientAttestation` 設定追加 |
| `tw2023_wallet/Feature/Settings/Setting.swift` | トグルUI追加 |
| `tw2023_wallet/Feature/Constants.swift` | キーエイリアス追加 |
| `tw2023_wallet/Services/OID/VCI/VCIClient.swift` | Attestationヘッダー送信 |
| `Localizable.strings` | 多言語対応文字列追加 |
| `tw2023_walletTests/VCIClientTests.swift` | Attestationヘッダーテスト追加 |
| `tw2023_walletTests/AsynTestRunner.swift` | XCTSkipエラー処理の改善 |

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ Settings: Enable "Client Authentication"                         │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ WalletAttestationService.generateClientAttestation()            │
│   1. Ensure attestation key pair exists (Secure Enclave)        │
│   2. Load provider private key from bundled PEM                 │
│   3. Load provider certificate chain from bundled PEM           │
│   4. Build JWT header (typ, alg, x5c)                           │
│   5. Build JWT payload (iss, sub, exp, cnf with jwk)            │
│   6. Sign with provider private key                             │
│   7. Save to PreferencesDataStore                               │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ Credential Issuance Flow                                         │
│   Token Request:                                                 │
│   1. Check if client attestation is enabled                     │
│   2. Get stored Client Attestation JWT                          │
│   3. Generate Client Attestation PoP JWT                        │
│   4. Add HTTP headers:                                          │
│      - OAuth-Client-Attestation: <attestation>                  │
│      - OAuth-Client-Attestation-PoP: <pop>                      │
│   5. Send POST to token endpoint                                │
└─────────────────────────────────────────────────────────────────┘
```

## Security Considerations

### Key Storage
- **Provider Key**: ビルド時にバンドル（本番環境では外部Providerを使用すべき）
- **Attestation Key**: Secure Enclaveに保存、`kSecAttrAccessibleWhenUnlockedThisDeviceOnly`

### JWT Expiration
- Client Attestation: 短い有効期限を設定（例: 1時間）
- トークンリクエスト時に有効期限をチェックし、必要に応じて再生成

### Privacy
- `sub` claim は全ウォレットインスタンスで共通の値を使用
- 個別のウォレットインスタンスを識別可能な情報を含めない

## Open Questions

1. **Provider Key/Certificate**: テスト用のキーペア・証明書をどのように準備するか？
2. **Client ID (sub claim)**: 具体的な値は何を使用するか？
3. **Wallet Provider Identifier (iss claim)**: 具体的なURLは？
4. **有効期限**: Client Attestationの有効期限はどの程度が適切か？

## References

### Implementation Files
- Settings: `tw2023_wallet/Feature/Settings/Setting.swift`
- Preferences: `tw2023_wallet/datastore/PreferencesDataStore.swift`
- VCI Client: `tw2023_wallet/Services/OID/VCI/VCIClient.swift`
- DPoP Service: `tw2023_wallet/Services/OID/VCI/DPoPService.swift`
- Key Utils: `tw2023_wallet/Utils/KeyPairUtil.swift`
- JWT Operations: `tw2023_wallet/Signature/JWTOperations.swift`

### Documentation
- [Architecture](../architecture.md)
- [Data Storage](../data-storage.md)
- [Credential Issuance](../features/credential-issuance/README.md)
