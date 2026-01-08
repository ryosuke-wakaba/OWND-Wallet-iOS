# Credential Issuance - Data Model

## Protocol Buffers

**File**: `tw2023_wallet/proto/credential_data.proto`

```proto
message CredentialData {
  string id = 1;
  string format = 2;
  string credential = 3;
  string cNonce = 4;
  int32 cNonceExpiresIn = 5;
  string iss = 6;
  int64 iat = 7;
  int64 exp = 8;
  string type = 9;
  string accessToken = 10;
  string credentialIssuerMetadata = 11;
}
```

## CoreData Entity

**Entity**: `CredentialDataEntity`

| Attribute | Type | Description |
|-----------|------|-------------|
| `id` | String | 一意識別子 |
| `format` | String | "jwt_vc_json", "vc+sd-jwt", etc. |
| `credential` | String | JWT文字列またはSD-JWT |
| `cNonce` | String | OID4VCI c_nonce |
| `cNonceExpiresIn` | String | c_nonceの有効期限 |
| `iss` | String | Issuer identifier |
| `iat` | String | 発行日時（Unix timestamp） |
| `exp` | String | 有効期限（Unix timestamp） |
| `type` | String | Credential type |
| `accessToken` | String | OID4VCI access token |
| `credentialIssuerMetadata` | String | JSON形式のメタデータ |

## Data Manager

```swift
// tw2023_wallet/datastore/CredentialDataManager.swift
class CredentialDataManager {
    /// Save a credential to CoreData
    func saveCredential(credentialData: Datastore_CredentialData)

    /// Get a credential by ID
    func getCredential(id: String) -> Datastore_CredentialData?

    /// Get all stored credentials
    func getAllCredentials() -> [Datastore_CredentialData]

    /// Delete a credential by ID
    func deleteCredential(id: String)
}
```

## Credential Formats

| Format | Description |
|--------|-------------|
| `jwt_vc_json` | JWT形式のVerifiable Credential |
| `vc+sd-jwt` | SD-JWT形式のVerifiable Credential |
| `dc+sd-jwt` | Digital Credentials形式のSD-JWT |

## Data Flow

```
Credential Response
        ↓
   Parse & Validate
        ↓
Create Datastore_CredentialData
        ↓
Protocol Buffers Serialization
        ↓
   CoreData Entity
        ↓
     Persist
```

## Storage Considerations

1. **Credential JWT**: 元のJWT/SD-JWT文字列をそのまま保存
2. **Metadata**: Issuerメタデータは表示用にJSON形式で保存
3. **Access Token**: 更新操作に必要な場合に保存（セキュリティ考慮が必要）

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/proto/credential_data.proto` | Protocol Buffers定義 |
| `tw2023_wallet/datastore/CredentialDataManager.swift` | Data Manager実装 |
| `tw2023_wallet/datastore/CredentialDataEntity+CoreDataClass.swift` | CoreData Entity |
