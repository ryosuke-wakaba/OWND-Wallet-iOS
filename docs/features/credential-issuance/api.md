# Credential Issuance - API Reference

## VCI Client

**Note**: 現在はPre-Authorized Code Flowのみサポート。`issueToken()`はPre-Authorized Code Grantを使用。DPoPはデフォルトで有効。

```swift
// tw2023_wallet/Services/OID/VCI/VCIClient.swift
class VCIClient {
    private var metadata: Metadata
    private var tokenEndpoint: URL
    private var credentialEndpoint: URL
    private(set) var credentialOffer: CredentialOffer

    init(credentialOffer: CredentialOffer, metaData: Metadata) async throws

    // Pre-Authorized Code Flow用（DPoP & Client Attestation対応）
    func issueToken(
        txCode: String?,
        useDPoP: Bool = false,
        useClientAttestation: Bool = false,
        using session: URLSession = URLSession.shared
    ) async throws -> OAuthTokenResponse

    // Nonce取得（OID4VCI 1.0 Nonce Endpoint）
    func fetchNonce(
        using session: URLSession = URLSession.shared
    ) async throws -> NonceResponseWithDPoPNonce

    // Credential発行（DPoP対応）
    func issueCredential(
        payload: CredentialRequestV1,
        accessToken: String,
        dpopNonce: String? = nil,
        useDPoP: Bool = false,
        using session: URLSession = URLSession.shared
    ) async throws -> CredentialResponse

    // Endpoint URL取得
    func getTokenEndpoint() -> URL
    func getCredentialEndpoint() -> URL
}
```

## DPoP Service

```swift
// tw2023_wallet/Services/OID/VCI/DPoPService.swift
enum DPoPService {
    /// Token Endpoint用のDPoP Proof生成（athなし）
    static func createProof(
        httpMethod: String,
        httpUri: String,
        nonce: String? = nil
    ) throws -> String

    /// Resource Server用のDPoP Proof生成（ath付き）
    static func createProofWithAccessToken(
        httpMethod: String,
        httpUri: String,
        accessToken: String,
        nonce: String? = nil
    ) throws -> String

    /// Access Token Hash計算
    static func calculateAth(accessToken: String) throws -> String
}
```

## Wallet Attestation Service

OAuth 2.0 Attestation-Based Client Authentication用のサービス。

```swift
// tw2023_wallet/Services/WalletAttestation/WalletAttestationService.swift
class WalletAttestationService {
    static let shared: WalletAttestationService

    /// Client Attestationが有効かチェック
    func isAttestationEnabled() -> Bool

    /// Client Attestation JWTを生成・保存（設定有効化時に呼び出し）
    func generateAndStoreClientAttestation() async throws

    /// 保存済みClient Attestation JWTを取得（期限切れの場合は再生成）
    func getClientAttestation() throws -> String

    /// Client Attestation PoP JWTを生成
    /// - Parameter audience: Authorization ServerのIssuer URL
    func generateClientAttestationPoP(audience: String) throws -> String
}
```

### Client Attestation JWT Format

**Header:**
```json
{
  "typ": "oauth-client-attestation+jwt",
  "alg": "ES256",
  "x5c": ["<base64-cert>", ...]
}
```

**Payload:**
```json
{
  "iss": "https://wallet-provider.ownd-project.com",
  "sub": "https://wallet.ownd-project.com",
  "nbf": 1234567890,
  "exp": 1234571490,
  "cnf": { "jwk": { "kty": "EC", "crv": "P-256", ... } },
  "wallet_name": "OWND Wallet",
  "wallet_link": "https://www.ownd-project.com/wallet/"
}
```

### Client Attestation PoP JWT Format

**Header:**
```json
{
  "typ": "oauth-client-attestation-pop+jwt",
  "alg": "ES256"
}
```

**Payload:**
```json
{
  "iss": "https://wallet.ownd-project.com",
  "aud": "https://issuer.example.com",
  "jti": "unique-id",
  "iat": 1234567890
}
```

## Data Models

### Credential Offer

```swift
struct CredentialOffer: Codable {
    let credentialIssuer: String
    let credentialConfigurationIds: [String]
    let grants: Grant?

    static func fromString(_ credentialOffer: String) -> CredentialOffer?
}

struct Grant: Codable {
    let authorizationCode: GrantAuthorizationCode?
    let preAuthorizedCode: GrantPreAuthorizedCode?
}

struct GrantPreAuthorizedCode: Codable {
    let preAuthorizedCode: String
    let txCode: TxCode?
    var interval: Int? = 5
    let authorizationServer: String?
}
```

### Issuer Metadata

```swift
struct CredentialIssuerMetadata: Codable {
    let credentialIssuer: String
    let authorizationServers: [String]?
    let credentialEndpoint: String
    let batchCredentialEndpoint: String?
    let deferredCredentialEndpoint: String?
    let notificationEndpoint: String?
    let display: [IssuerDisplay]?
    let credentialConfigurationsSupported: [String: CredentialConfiguration]
}
```

### Token Response

```swift
struct OAuthTokenResponse: Codable {
    let accessToken: String
    let tokenType: String  // "DPoP" or "Bearer"
    let expiresIn: Int?
    let cNonce: String?
    let cNonceExpiresIn: Int?
}
```

### Nonce Response

```swift
// OID4VCI 1.0: Nonce endpoint response body
struct NonceResponse: Codable {
    let cNonce: String
}

// Extended response including DPoP-Nonce from header
struct NonceResponseWithDPoPNonce {
    let cNonce: String       // From response body
    let dpopNonce: String?   // From DPoP-Nonce response header
}
```

### Credential Response

```swift
struct CredentialResponse: Codable {
    let credential: String?
    let credentials: [String]?
    let transactionId: String?
    let cNonce: String?
    let cNonceExpiresIn: Int?
}
```

## Usage Example

### Basic Usage

```swift
// 1. Parse Credential Offer
let offer = CredentialOffer.fromString(qrCodeContent)

// 2. Create VCI Client
let client = try await VCIClient(credentialOffer: offer, metaData: metadata)

// 3. Get settings from preferences
let useDPoP = PreferencesDataStore.shared.getUseDPoP()
let useClientAttestation = PreferencesDataStore.shared.getUseClientAttestation()

// 4. Get Access Token (with DPoP and/or Client Attestation)
let tokenResponse = try await client.issueToken(
    txCode: nil,
    useDPoP: useDPoP,
    useClientAttestation: useClientAttestation
)

// 5. Fetch Nonce
let nonceResponse = try await client.fetchNonce()

// 6. Issue Credential
let credentialResponse = try await client.issueCredential(
    payload: credentialRequest,
    accessToken: tokenResponse.accessToken,
    dpopNonce: nonceResponse.dpopNonce,
    useDPoP: useDPoP
)
```

### Using CredentialIssuanceService (Recommended)

```swift
// Use the facade service for simplified flow
let issuanceService = CredentialIssuanceService()

try await issuanceService.issueCredential(
    credentialOffer: offer,
    metadata: metadata,
    credentialConfigurationId: "IdentityCredential",
    txCode: nil,
    useDPoP: PreferencesDataStore.shared.getUseDPoP(),
    useClientAttestation: PreferencesDataStore.shared.getUseClientAttestation()
)
```

### Manual Client Attestation Usage

```swift
// Get or generate Client Attestation
let attestation = try WalletAttestationService.shared.getClientAttestation()

// Generate PoP for specific Authorization Server
let pop = try WalletAttestationService.shared.generateClientAttestationPoP(
    audience: "https://issuer.example.com"
)

// These are automatically added by VCIClient when useClientAttestation = true:
// - OAuth-Client-Attestation: <attestation>
// - OAuth-Client-Attestation-PoP: <pop>
```

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/Services/OID/VCI/VCIClient.swift` | VCI Client実装 |
| `tw2023_wallet/Services/OID/VCI/DPoPService.swift` | DPoP Service実装 |
| `tw2023_wallet/Services/WalletAttestation/WalletAttestationService.swift` | Wallet Attestation Service実装 |
| `tw2023_wallet/Services/CredentialIssuance/CredentialIssuanceService.swift` | Credential Issuance Facade |
| `tw2023_wallet/Services/CredentialIssuance/TokenIssuanceService.swift` | Token Issuance Service |
| `tw2023_wallet/Services/CredentialIssuance/CredentialIssuanceServiceProtocols.swift` | Service Protocols |
| `tw2023_wallet/Utils/PEMUtils.swift` | PEM file loading utilities |
| `tw2023_wallet/datastore/PreferencesDataStore.swift` | Settings storage |

## HTTP Headers

### Token Request Headers

| Header | Condition | Description |
|--------|-----------|-------------|
| `Content-Type` | Always | `application/x-www-form-urlencoded` |
| `DPoP` | `useDPoP = true` | DPoP Proof JWT |
| `OAuth-Client-Attestation` | `useClientAttestation = true` | Client Attestation JWT |
| `OAuth-Client-Attestation-PoP` | `useClientAttestation = true` | Client Attestation PoP JWT |

### Credential Request Headers

| Header | Condition | Description |
|--------|-----------|-------------|
| `Content-Type` | Always | `application/json` |
| `Authorization` | `useDPoP = true` | `DPoP <access_token>` |
| `Authorization` | `useDPoP = false` | `Bearer <access_token>` |
| `DPoP` | `useDPoP = true` | DPoP Proof JWT (with ath) |
