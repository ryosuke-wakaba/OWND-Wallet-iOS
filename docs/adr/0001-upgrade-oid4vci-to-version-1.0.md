# ADR 0001: Upgrade OID4VCI Protocol to Version 1.0

## Status
Proposed

## Context

現在の実装は、OID4VCI (OpenID for Verifiable Credential Issuance) の古いドラフト版に基づいています。2025年9月16日に **OpenID for Verifiable Credential Issuance 1.0** が Final Specification として公開されました。

本ADRでは、プロトコルバージョンを最新の1.0に完全移行するための変更内容を記録します。

### 現在の実装の問題点

1. Token Responseから`c_nonce`を取得する古い方式を使用
2. Credential RequestにFormat情報（`format`, `vct`, `credentialDefinition`）を含む
3. Proof構造が古い形式（`{ proof_type: "jwt", jwt: "..." }`）
4. Issuer Metadataに`nonce_endpoint`が存在しない

### プロトコル1.0の主要な変更点

1. **Nonce取得の分離**: 専用の`nonce_endpoint`から取得
2. **Credential Request簡素化**: `credential_configuration_id`と`proofs`のみ指定
3. **Proof構造変更**: オブジェクト形式に変更
4. **Issuer Metadata拡張**: `nonce_endpoint`フィールド追加

## Decision

**OpenID for Verifiable Credential Issuance 1.0 (Final)** に完全移行します。

### 実装する変更内容

#### 1. Issuer Metadataに`nonce_endpoint`追加

**変更前**:
```swift
struct CredentialIssuerMetadata: Codable {
    let credentialIssuer: String
    let credentialEndpoint: String
    // ... その他のフィールド
}
```

**変更後**:
```swift
struct CredentialIssuerMetadata: Codable {
    let credentialIssuer: String
    let credentialEndpoint: String
    let nonceEndpoint: String?  // 追加
    // ... その他のフィールド
}
```

#### 2. Nonce取得フロー変更

**変更前**: Token Response (`OAuthTokenResponse`)から`c_nonce`を取得

**変更後**: 専用エンドポイントから取得

**リクエスト**:
```
POST /nonce HTTP/1.1
Host: credential-issuer.example.com
Content-Length: 0
```

**レスポンス**:
```json
{
  "c_nonce": "wKI4LT17ac15ES9bw8ac4"
}
```

**呼び出しタイミング**: Token取得後、Credential Request前に**毎回**呼び出す

#### 3. Proof構造変更

**変更前**:
```json
{
  "proof_type": "jwt",
  "jwt": "eyJ..."
}
```

**変更後**:
```json
{
  "jwt": [
    "eyJ..."
  ]
}
```

**Note**: `proofs`パラメータ全体の構造:
```json
{
  "proofs": {
    "jwt": [
      "eyJ..."
    ]
  }
}
```

#### 4. Credential Requestペイロード変更

**変更前**:
```swift
struct CredentialRequestVcSdJwt: CredentialRequest {
    let format: String
    let proof: JwtProof?
    let credentialIdentifier: String?
    let credentialResponseEncryption: CredentialRequestCredentialResponseEncryption?
    let vct: String?
    let claims: [String: Claim]?
}

struct CredentialRequestJwtVcJson: CredentialRequest {
    let format: String
    let proof: JwtProof?
    let credentialIdentifier: String?
    let credentialResponseEncryption: CredentialRequestCredentialResponseEncryption?
    let credentialDefinition: CredentialDefinitionJwtVcJson?
}
```

**変更後**:
```swift
struct CredentialRequest: Codable {
    let credentialConfigurationId: String
    let proofs: Proofs?
    let credentialIdentifier: String?
    let credentialResponseEncryption: CredentialRequestCredentialResponseEncryption?
}

struct Proofs: Codable {
    let jwt: [String]?  // JWT proof type
    // 将来: cwt, ldp_vp など他のproof typeも追加可能
}
```

**JSON例**:
```json
{
  "credential_configuration_id": "UniversityDegree_JWT",
  "proofs": {
    "jwt": [
      "eyJraWQiOiJkaWQ6ZXhhbXBsZTplYmZlYjFmNzEyZWJjNmYxYzI3NmUxMmVjMjEva2V5cy8xIiwiYWxnIjoiRVMyNTYiLCJ0eXAiOiJKV1QifQ..."
    ]
  }
}
```

**重要**: `format`, `vct`, `credentialDefinition`は削除。サーバー側が`credential_configuration_id`から特定します。

#### 5. JWT Proof Payload

**変更なし**: 既存の実装（`iat`, `aud`, `nonce`など）をそのまま使用

## Consequences

### Breaking Changes

1. **古いIssuerとの互換性喪失**
   - OID4VCI 1.0以前のIssuerは利用不可
   - 完全移行のため、バージョン切り替えなし

2. **データ構造の変更**
   - `CredentialRequest`の構造が大幅に変更
   - Proof構造の変更

### Benefits

1. **仕様準拠**: 最新のFinal Specificationに準拠
2. **簡素化**: Credential Requestペイロードが簡潔に
3. **セキュリティ向上**: Nonce取得の独立により、より柔軟なフロー制御が可能
4. **将来性**: 複数Proof type（JWT, CWT, DI VPなど）への対応が容易

### Migration Path

既存のCredentialデータは影響を受けません（保存済みCredentialは変更不要）。

新規発行時のみ新しいプロトコルを使用します。

## Implementation Plan

### Phase 1: データモデル更新
- [ ] `CredentialIssuerMetadata`に`nonceEndpoint`追加
- [ ] `Proofs`構造体作成
- [ ] `CredentialRequest`構造体を新形式に変更
- [ ] 古い`CredentialRequestVcSdJwt`/`CredentialRequestJwtVcJson`を削除

### Phase 2: Nonce Endpoint実装
- [ ] `NonceResponse`構造体作成
- [ ] `fetchNonce()`メソッド実装
- [ ] VCIClientにNonce取得ロジック追加

### Phase 3: Credential Request更新
- [ ] `createCredentialRequest()`をリファクタリング
- [ ] Proof生成ロジックを新構造に対応
- [ ] `postCredentialRequest()`を新ペイロード形式に対応

### Phase 4: テストと検証
- [ ] ユニットテスト更新
- [ ] 実際のIssuerとの統合テスト
- [ ] エラーハンドリング確認

### Phase 5: ドキュメント更新
- [ ] `docs/features/credential-issuance.md`更新
- [ ] `docs/README.md`にプロトコルバージョン明記
- [ ] API Overviewセクション更新

## Implementation Details

### 影響を受けるファイル

1. **tw2023_wallet/Services/OID/VCI/VCIMetadata.swift**
   - `CredentialIssuerMetadata`に`nonceEndpoint`追加

2. **tw2023_wallet/Services/OID/VCI/VCIClient.swift**
   - `CredentialRequest`構造体を完全にリファクタリング
   - `Proofs`構造体追加
   - `NonceResponse`構造体追加
   - `fetchNonce()`メソッド追加
   - `createCredentialRequest()`リファクタリング
   - `issueCredential()`メソッド更新

3. **tw2023_wallet/Feature/IssueCredential/**
   - ViewModelでのCredential Request呼び出し箇所を更新

4. **tw2023_walletTests/**
   - VCIClient関連のテストを更新

### 実装の優先順位

**高**: Phase 1-3（コア機能）
**中**: Phase 4（テスト）
**低**: Phase 5（ドキュメント）

## References

- [OpenID for Verifiable Credential Issuance 1.0](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
- Section 7: Nonce Endpoint
- Section 8: Credential Request
- Appendix F: Proof Types
- Implementation: `tw2023_wallet/Services/OID/VCI/`

## Timeline

- **調査・設計**: 完了
- **実装開始**: TBD
- **完了予定**: TBD
