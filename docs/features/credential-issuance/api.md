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

    // Pre-Authorized Code Flow用（DPoP対応）
    func issueToken(
        txCode: String?,
        useDPoP: Bool = true,  // DPoPデフォルト有効
        using session: URLSession = URLSession.shared
    ) async throws -> OAuthTokenResponse

    // Nonce取得（OID4VCI 1.0 Nonce Endpoint）
    func fetchNonce(
        accessToken: String,
        using session: URLSession = URLSession.shared
    ) async throws -> NonceResponseWithDPoPNonce

    // Credential発行（DPoP対応）
    func issueCredential(
        payload: any CredentialRequest,
        accessToken: String,
        dpopNonce: String? = nil,  // DPoP-Nonce
        useDPoP: Bool = true,       // DPoPデフォルト有効
        using session: URLSession = URLSession.shared
    ) async throws -> CredentialResponse
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
struct NonceResponseWithDPoPNonce {
    let cNonce: String
    let cNonceExpiresIn: Int?
    let dpopNonce: String?  // From DPoP-Nonce header
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

```swift
// 1. Parse Credential Offer
let offer = CredentialOffer.fromString(qrCodeContent)

// 2. Create VCI Client
let client = try await VCIClient(credentialOffer: offer, metaData: metadata)

// 3. Get Access Token with DPoP
let tokenResponse = try await client.issueToken(txCode: nil, useDPoP: true)

// 4. Fetch Nonce
let nonceResponse = try await client.fetchNonce(accessToken: tokenResponse.accessToken)

// 5. Issue Credential
let credentialResponse = try await client.issueCredential(
    payload: credentialRequest,
    accessToken: tokenResponse.accessToken,
    dpopNonce: nonceResponse.dpopNonce,
    useDPoP: true
)
```

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/Services/OID/VCI/VCIClient.swift` | VCI Client実装 |
| `tw2023_wallet/Services/OID/VCI/DPoPService.swift` | DPoP Service実装 |
| `tw2023_wallet/Services/OID/VCI/Models/` | データモデル定義 |
