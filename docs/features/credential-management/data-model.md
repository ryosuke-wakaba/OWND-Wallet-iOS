# Credential Management - Data Model

## Credential Model

**File**: `tw2023_wallet/Models/Credential.swift`

```swift
struct Credential: Codable, Identifiable, Hashable {
    var id: String
    var format: String
    var payload: String
    var issuer: String
    let issuerDisplayName: String
    var issuedAt: String
    var logoUrl: String?
    var backgroundColor: String?
    var backgroundImageUrl: String?
    var textColor: String?
    var credentialType: String
    var disclosure: [String: String]?
    var certificates: [Certificate?]?
    var qrDisplay: String
    var metaData: CredentialIssuerMetadata

    var backgroundImage: AnyView?
    var logoImage: AnyView?
}
```

**Note**: 有効期限チェック機能（`isExpired`, `isExpiringSoon`）は現在未実装です。将来的な拡張として検討中。

## Credential Sharing History

### Protocol Buffers

**File**: `tw2023_wallet/proto/credential_sharing_history.proto`

```proto
message CredentialSharingHistory {
  string rp = 1;
  int32 accountIndex = 2;
  google.protobuf.Timestamp createdAt = 3;
  string credentialID = 4;
  repeated ClaimInfo claims = 5;
  string logoURL = 6;
  string rpName = 7;
  string privacyPolicyURL = 8;
}

message ClaimInfo {
    string claimKey = 1;
    string claimValue = 2;
    string purpose = 3;
}
```

### Swift Model

**File**: `tw2023_wallet/Models/CredentialSharingHistory.swift`

```swift
struct CredentialSharingHistory: Codable, Hashable, History {
    let rp: String
    let accountIndex: Int
    let createdAt: String
    let credentialID: String
    var claims: [ClaimInfo]
    var rpName: String
    var privacyPolicyUrl: String
    var logoUrl: String
}

struct ClaimInfo: Codable {
    var claimKey: String
    var claimValue: String
    var purpose: String?
}
```

### CoreData Entity

**Entity**: `CredentialSharingHistoryEntity`

| Attribute | Type | Description |
|-----------|------|-------------|
| `rp` | String | Relying Party identifier |
| `accountIndex` | Int32 | Account index |
| `createdAt` | Date | Sharing timestamp |
| `credentialID` | String | Credential ID |
| `claims` | Binary | Serialized claims |
| `logoURL` | String | Verifier logo URL |
| `rpName` | String | Verifier name |
| `privacyPolicyURL` | String | Privacy policy URL |

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/Models/Credential.swift` | Credential Model |
| `tw2023_wallet/Models/CredentialSharingHistory.swift` | Sharing History Model |
| `tw2023_wallet/proto/credential_sharing_history.proto` | Protocol Buffers定義 |
