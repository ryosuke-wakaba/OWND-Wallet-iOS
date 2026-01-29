# DPoP 実装詳細

## DPoP Service API

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

## 使用方法

DPoPはクレデンシャル発行サービスで使用されます:

```swift
// CredentialIssuanceServiceでDPoP使用
try await issuanceService.issueCredential(
    credentialOffer: offer,
    metadata: metadata,
    credentialConfigurationId: configId,
    txCode: txCode,
    useDPoP: true  // DPoP有効化
)
```

## 実装ファイル一覧

| ファイル | 役割 |
|---------|------|
| `tw2023_wallet/Services/OID/VCI/DPoPService.swift` | DPoP Proof生成サービス |
| `tw2023_wallet/Services/OID/VCI/VCIClient.swift` | VCI クライアント（DPoP統合） |
| `tw2023_wallet/Feature/Constants.swift` | DPoP鍵定数定義 |
| `tw2023_wallet/Services/CredentialIssuance/TokenIssuanceService.swift` | Token発行サービス |
| `tw2023_wallet/Services/CredentialIssuance/CredentialRequestService.swift` | Credential要求サービス |
| `tw2023_walletTests/DPoPServiceTests.swift` | ユニットテスト |
