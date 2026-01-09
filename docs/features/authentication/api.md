# Authentication - API Reference

## OpenIdProvider (SIOP)

**File**: `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift`

```swift
class OpenIdProvider {
    /// Process SIOP authorization request
    func processAuthRequest(_ url: String) async
        -> Result<ProcessedRequestData, AuthorizationRequestError>

    /// Send ID Token response to RP
    func respondToken(credentials: [SubmissionCredential]?) async
        -> Result<TokenSendResult, Error>

    /// Create Self-Issued ID Token
    private func createSiopIdToken()
        -> Result<([String: String], String), Error>
}
```

### ProcessedRequestData

```swift
struct ProcessedRequestData {
    var authorizationRequest: AuthorizationRequestPayload
    var requestObjectJwt: String
    var requestObject: RequestObjectPayload?
    var clientMetadata: RPRegistrationMetadataPayload
    var presentationDefinition: PresentationDefinition?
    var requestIsSigned: Bool
}
```

## PairwiseAccount

**File**: `tw2023_wallet/Services/OID/Provider/PairwiseAccount.swift`

Pairwise識別子を管理し、RP毎に異なるAccountを提供します。

```swift
class PairwiseAccount {
    /// Get existing account for RP, or nil if not found
    func getAccount(rp: String, index: Int = -1) -> Account?

    /// Generate next available account
    func nextAccount() -> Account

    /// Get account by index
    func indexToAccount(index: Int, rp: String? = nil) -> Account

    /// Get private key for signing
    func getPrivateKey(index: Int) -> Data

    /// Get public key (x, y coordinates)
    func getPublicKey(index: Int) -> (Data, Data)
}
```

### Account

```swift
struct Account {
    let index: Int              // HD derivation index
    let publicJwk: ECPublicJwk  // Public key in JWK format
    let privateJwk: ECJwk       // Private key in JWK format
    let thumbprint: String      // JWK Thumbprint (sub claim)
    var rp: String?             // Associated RP
}
```

## HDKeyRing

**File**: `tw2023_wallet/Services/OID/Provider/HDKeyRing.swift`

BIP-32/BIP-39に基づく階層的決定性鍵管理。

```swift
class HDKeyRing {
    /// Initialize with mnemonic phrase
    init(mnemonic: String)

    /// Derive key at specific index
    func deriveKey(index: Int) -> ECKeyPair

    /// Export mnemonic for backup
    func exportMnemonic() -> String
}
```

## Usage Example

```swift
// 1. Process SIOP Request
let provider = OpenIdProvider()
let result = await provider.processAuthRequest(siopUrl)

switch result {
case .success(let processedData):
    // 2. Get or create pairwise account
    let pairwiseAccount = PairwiseAccount()
    let account = pairwiseAccount.getAccount(rp: processedData.clientId)
        ?? pairwiseAccount.nextAccount()

    // 3. Send ID Token response
    let sendResult = await provider.respondToken(credentials: nil)

case .failure(let error):
    // Handle error
}
```

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift` | SIOP Provider |
| `tw2023_wallet/Services/OID/Provider/PairwiseAccount.swift` | Pairwise Account管理 |
| `tw2023_wallet/Services/OID/Provider/HDKeyRing.swift` | HD鍵派生 |
