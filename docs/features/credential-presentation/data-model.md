# Credential Presentation - Data Model

## Credential Sharing History

共有履歴は、ユーザーがどのVerifierにどのクレデンシャルを提示したかを記録します。

### Protocol Buffers

**File**: `tw2023_wallet/proto/credential_sharing_history.proto`

```proto
message CredentialSharingHistory {
  string rp = 1;                           // Relying Party (Verifier) identifier
  int32 accountIndex = 2;                  // Account index
  google.protobuf.Timestamp createdAt = 3; // Sharing timestamp
  string credentialID = 4;                 // Shared credential ID
  repeated ClaimInfo claims = 5;           // Shared claims
  string logoURL = 6;                      // Verifier logo URL
  string rpName = 7;                       // Verifier display name
  string privacyPolicyURL = 8;             // Verifier privacy policy URL
}

message ClaimInfo {
    string claimKey = 1;    // Claim name
    string claimValue = 2;  // Claim value
    string purpose = 3;     // Purpose of sharing
}
```

### Fields Description

| Field | Description |
|-------|-------------|
| `rp` | Verifierの識別子（client_id） |
| `accountIndex` | ウォレット内のアカウントインデックス |
| `createdAt` | 共有日時 |
| `credentialID` | 共有したクレデンシャルのID |
| `claims` | 共有したクレームのリスト |
| `logoURL` | Verifierのロゴ画像URL |
| `rpName` | Verifierの表示名 |
| `privacyPolicyURL` | Verifierのプライバシーポリシー |

## Related Models

### SubmissionCredential

VP Token生成に使用するクレデンシャル情報。

```swift
struct SubmissionCredential {
    let credential: Credential
    let disclosures: [DisclosureWithOptionality]
    let credentialQueryId: String
}
```

### SharedCredential

共有されたクレデンシャルの記録。

```swift
struct SharedCredential {
    let credentialId: String
    let claims: [ClaimInfo]
    let sharedAt: Date
}
```

## Data Flow

```
VP Token送信成功
        ↓
SharedCredential作成
        ↓
CredentialSharingHistory生成
        ↓
Protocol Buffers シリアライズ
        ↓
CoreData保存
```

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/proto/credential_sharing_history.proto` | Protocol Buffers定義 |
| `tw2023_wallet/datastore/CredentialSharingHistoryManager.swift` | 履歴管理 |
