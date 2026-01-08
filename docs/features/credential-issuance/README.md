# Credential Issuance (OID4VCI)

## Status
- [x] Draft
- [ ] Review
- [ ] Approved
- [x] Implemented
- [ ] Verified

## Overview

OID4VCI (OpenID for Verifiable Credential Issuance) プロトコルを使用して、Issuerからデジタルクレデンシャルを受け取る機能です。

**現在の実装状況**:
- ✅ Pre-Authorized Code Flow (実装済み)
- ✅ DPoP (RFC 9449) - Sender-Constrained Access Tokens (実装済み)
- ✅ Nonce Endpoint (OID4VCI 1.0) (実装済み)
- ✅ Signed Metadata (OID4VCI 1.0 Section 12.2.3) (実装済み)
- ✅ Trust List (ETSI TS 119 602 LoTE) (実装済み)
- ⏳ Authorization Code Flow (将来対応予定)

## User Stories

- As a user, I want to scan a QR code to receive a credential from an issuer
- As a user, I want to see the issuer's information before accepting a credential
- As a user, I want to securely store the issued credential in my wallet
- As a user, I want to see my issued credentials in the wallet

## Requirements

### Functional Requirements

1. **QR Code Scanning**
   - ユーザーがQRコードをスキャンできる
   - Credential Offerを解析できる
   - Deep Linkからの起動に対応

2. **Issuer Metadata Retrieval**
   - Issuerのメタデータを`.well-known`エンドポイントから取得
   - Issuerの情報を表示（名前、ロゴ、信頼性情報）

3. **Authorization Flow**
   - Pre-Authorized Code Flow対応（実装済み）
   - Authorization Code Flow対応（将来予定）

4. **Credential Request**
   - Access Tokenの取得
   - Key Binding JWT (KB-JWT)の生成
   - Credentialリクエストの送信

5. **Credential Storage**
   - 受信したCredentialの検証
   - CoreDataへの保存
   - Protocol Buffersでのシリアライゼーション

### Non-Functional Requirements

1. **Security**
   - すべての通信はHTTPS
   - 秘密鍵はKeychain/Secure Enclaveに保存
   - Credentialの署名検証

2. **Performance**
   - QRコードスキャン: 1秒以内
   - Credential発行: 10秒以内

3. **Usability**
   - わかりやすいエラーメッセージ
   - 発行プロセスの進捗表示
   - キャンセル可能

4. **Reliability**
   - ネットワークエラー時の適切なハンドリング
   - リトライメカニズム

## Implementation Plan

- [x] QR Code Scanner実装
- [x] Credential Offer解析
- [x] Issuer Metadata取得
- [x] Pre-Authorized Code Flow実装
- [ ] Authorization Code Flow実装（将来）
- [x] KB-JWT生成
- [x] Credential Request実装
- [x] Credential検証
- [x] CoreData保存
- [x] DPoP (RFC 9449) Sender-Constrained Access Tokens
- [x] Nonce Endpoint (OID4VCI 1.0)
- [ ] UI/UX改善
- [ ] エラーハンドリング強化

## Known Issues

1. Authorization Code Flowが未実装
2. バッチ発行（複数Credential同時発行）未対応
3. Deferred Credential未対応

## Future Enhancements

1. Authorization Code Flow実装
2. バッチCredential発行対応
3. Deferred Credential対応
4. オフライン発行（将来の標準化後）
5. Credential更新機能

## Related Documents

- [Design](./design.md) - UI/UX、クラス図、データフロー
- [DPoP](./dpop.md) - RFC 9449 DPoP実装詳細
- [Metadata Verification](./metadata-verification.md) - Signed Metadata、Trust List対応
- [API Reference](./api.md) - VCIClient、DPoPService、データモデル
- [Data Model](./data-model.md) - Protocol Buffers、CoreData
- [Security](./security.md) - セキュリティ考慮事項
- [Testing](./testing.md) - テスト戦略、エラーハンドリング

## References

### Specifications

- [OID4VCI 1.0 Final Specification](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
- [OID4VCI 1.0 Section 12.2.3 - Signed Metadata](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#section-12.2.3)
- [ETSI TS 119 602 - Trusted Lists](https://www.etsi.org/deliver/etsi_ts/119600_119699/119602/01.01.01_60/ts_119602v010101p.pdf)
- [RFC 9449: OAuth 2.0 DPoP](https://www.rfc-editor.org/rfc/rfc9449.html)
- [HAIP (High Assurance Interoperability Profile)](https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-1_0-05.html)

### Documentation

- [ADR: OID4VCI 1.0 Upgrade](../../adr/0001-upgrade-oid4vci-to-version-1.0.md)
- [DPoP Implementation Work Document](../../work/dpop-implementation.md)
- [OID4VCI Test Documentation](../../tests/oid4vci-tests.md)

### Implementation

- VCI Client: `tw2023_wallet/Services/OID/VCI/VCIClient.swift`
- VCI Metadata Client: `tw2023_wallet/Services/OID/VCI/VCIMetadataClient.swift`
- Signed Metadata Validator: `tw2023_wallet/Services/OID/VCI/SignedMetadataValidator.swift`
- DPoP Service: `tw2023_wallet/Services/OID/VCI/DPoPService.swift`
- Trust List Manager: `tw2023_wallet/Services/TrustedList/TrustedListManager.swift`
- Trust Anchor Manager: `tw2023_wallet/Signature/TrustAnchorManager.swift`
- Credential Issuance: `tw2023_wallet/Services/CredentialIssuance/`
- Data Manager: `tw2023_wallet/datastore/CredentialDataManager.swift`
- Protocol Buffers: `tw2023_wallet/proto/credential_data.proto`
