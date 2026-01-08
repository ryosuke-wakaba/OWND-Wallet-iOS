# Credential Presentation - API Reference

## OpenIdProvider

**File**: `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift`

```swift
class OpenIdProvider {
    var authRequestProcessedData: ProcessedRequestData?
    var clientId: String?
    var responseType: String?
    var responseMode: ResponseMode?
    var nonce: String?
    var state: String?
    var redirectUri: String?
    var responseUri: String?
    var dcqlQuery: DcqlQuery?

    /// Process authorization request from URL
    func processAuthRequest(_ url: String, using session: URLSession = URLSession.shared) async
        -> Result<ProcessedRequestData, AuthorizationRequestError>

    /// Send VP Token response to Verifier
    func respondToken(
        credentials: [SubmissionCredential]?,
        using session: URLSession = URLSession.shared
    ) async -> Result<TokenSendResult, Error>

    /// Create VP Token from credentials
    func createVpToken(
        credentials: [SubmissionCredential],
        using session: URLSession = URLSession.shared
    ) -> Result<([String: String], [SharedCredential]), Error>
}
```

### ProcessedRequestData

```swift
struct ProcessedRequestData {
    var authorizationRequest: AuthorizationRequestPayload
    var requestObjectJwt: String
    var requestObject: RequestObjectPayload?
    var clientMetadata: RPRegistrationMetadataPayload
    var dcqlQuery: DcqlQuery?
    var requestIsSigned: Bool
}
```

## SharingRequestViewModel

**File**: `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestViewModel.swift`

```swift
@Observable
class SharingRequestViewModel {
    // Filtered credentials for VP credential picker
    var filteredCredentials: [Credential] = []

    // Credential claims classification for VP sharing
    var requiredClaims: [DisclosureWithOptionality] = []
    var undisclosedClaims: [DisclosureWithOptionality] = []

    /// Load credentials filtered by DCQL query for VP credential picker
    func loadFilteredCredentials()

    /// Classify credential claims based on DCQL query
    /// - Parameter credential: The credential to classify claims for
    func classifyClaims(credential: Credential)

    /// Create submission credential for VP token
    /// - Parameters:
    ///   - credential: Source credential
    ///   - discloseClaims: Claims to disclose
    /// - Returns: SubmissionCredential for VP token generation
    func createSubmissionCredential(
        credential: Credential,
        discloseClaims: [DisclosureWithOptionality]
    ) -> SubmissionCredential?
}
```

## VP Token Encryption (JWE)

**File**: `tw2023_wallet/Signature/JWEUtil.swift`

```swift
struct JWEUtil {
    /// Encrypt VP Token using ECDH-ES + A128GCM
    /// - Parameters:
    ///   - plaintext: VP Token to encrypt
    ///   - recipientPublicKey: Verifier's public key (from client metadata)
    ///   - apuData: Agreement PartyU Info (typically client_id)
    ///   - apvData: Agreement PartyV Info (typically nonce)
    /// - Returns: JWE compact serialization
    static func encrypt(
        plaintext: Data,
        recipientPublicKey: SecKey,
        apuData: Data?,
        apvData: Data?
    ) throws -> String
}
```

### Encryption Parameters

| Parameter | Value |
|-----------|-------|
| Algorithm | ECDH-ES (Ephemeral Static) |
| Encryption | A128GCM |
| Key Derivation | Concat KDF (NIST SP 800-56A) |
| AAD | Protected Header (Base64URL encoded) |

## Response Modes

| Mode | Description |
|------|-------------|
| `direct_post` | VP TokenをVerifierのresponse_uriにPOST |
| `direct_post.jwt` | VP TokenをJWE暗号化してPOST（HAIP） |

## Usage Example

```swift
// 1. Process Authorization Request
let provider = OpenIdProvider()
let result = await provider.processAuthRequest(qrCodeUrl)

switch result {
case .success(let processedData):
    // 2. Match credentials with DCQL query
    let viewModel = SharingRequestViewModel()
    viewModel.loadFilteredCredentials()

    // 3. User selects credential and confirms
    viewModel.classifyClaims(credential: selectedCredential)
    let submission = viewModel.createSubmissionCredential(
        credential: selectedCredential,
        discloseClaims: viewModel.requiredClaims
    )

    // 4. Send VP Token
    let sendResult = await provider.respondToken(credentials: [submission])

case .failure(let error):
    // Handle error
}
```

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift` | OID4VPプロバイダー |
| `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestViewModel.swift` | VP提示ViewModel |
| `tw2023_wallet/Signature/JWEUtil.swift` | JWE暗号化 |
| `tw2023_wallet/Services/OID/AuthorizationRequest.swift` | 認可リクエスト処理 |
