# Credential Presentation (OID4VP)

## Status
- [x] Draft
- [ ] Review
- [ ] Approved
- [x] Implemented
- [ ] Verified

## Overview

OID4VP (OpenID for Verifiable Presentations) 1.0 プロトコルを使用して、VerifierにVerifiable Presentationを提示する機能です。

**仕様バージョン**: OID4VP 1.0 (openid-4-verifiable-presentations-1_0)

## User Stories

- As a user, I want to scan a QR code to present my credentials to a verifier
- As a user, I want to select which credentials to share from my wallet
- As a user, I want to see what information will be shared before confirming
- As a user, I want to control which claims are disclosed (selective disclosure)
- As a user, I want to review my sharing history

## Requirements

### Functional Requirements

1. **Authorization Request Parsing**
   - QRコードまたはDeep Linkからリクエスト受信
   - Request URIからのJWT取得
   - DCQL (Digital Credentials Query Language) の解析
   - Client ID Scheme の検証 (x509_san_dns, x509_hash, redirect_uri)

2. **Credential Matching (DCQL)**
   - DCQL Credential Queryとの照合
   - フォーマットマッチング (dc+sd-jwt, vc+sd-jwt, jwt_vc_json)
   - VCT (Verifiable Credential Type) マッチング
   - クレームパスマッチング

3. **Selective Disclosure**
   - OID4VP 1.0 Section 6.4.1 に準拠したクレーム選択
   - `claims` absent: 選択的開示クレームなし（必須クレームのみ）
   - `claims` present: 指定されたクレームのみ開示
   - DCQLクエリに基づく自動クレーム選択

4. **VP Token Generation**
   - SD-JWT VC の選択的開示処理
   - Key Binding JWT の生成
   - JWT-VP フォーマット対応

5. **VP Token Encryption (HAIP対応)**
   - JWE暗号化 (ECDH-ES + A128GCM)
   - Concat KDF (NIST SP 800-56A)
   - response_mode: direct_post.jwt

6. **VP Submission**
   - Direct Post対応 (response_mode: direct_post)
   - Direct Post JWT対応 (response_mode: direct_post.jwt)
   - レスポンスハンドリング

7. **History Management**
   - 共有履歴の記録
   - 共有内容の保存

### Non-Functional Requirements

1. **Security**
   - ユーザー同意なしの共有防止
   - VP署名の適切な実施
   - X.509証明書によるVerifier検証
   - VP Token暗号化（HAIP）

2. **Privacy**
   - 最小限の情報開示
   - OID4VP 1.0準拠の選択的開示
   - claims absent時は選択的開示クレームを含めない

3. **Performance**
   - Credential照合: 1秒以内
   - VP生成: 2秒以内
   - 全体フロー: 10秒以内

4. **Usability**
   - 明確な情報開示表示
   - わかりやすい選択UI
   - 確認プロセス

## Implementation Status

- [x] Authorization Request解析
- [x] Request URI取得
- [x] Request Object JWT検証
- [x] Client ID Scheme検証 (x509_san_dns, x509_hash, redirect_uri)
- [x] DCQL Query解析
- [x] DCQL Credential Matching
- [x] 選択的開示 (OID4VP 1.0 Section 6.4.1)
- [x] VP Token生成 (SD-JWT VC)
- [x] VP Token生成 (JWT-VC-JSON)
- [x] Key Binding JWT生成
- [x] VP Token暗号化 (JWE: ECDH-ES + A128GCM)
- [x] Direct Post実装
- [x] Direct Post JWT実装
- [x] 共有履歴保存
- [ ] claim_sets対応（将来）
- [ ] values制限対応（将来）

## Related Documents

- [Design](./design.md) - UI/UX、データフロー
- [DCQL](./dcql.md) - Digital Credentials Query Language、選択的開示
- [API Reference](./api.md) - OpenIdProvider、SharingRequestViewModel、JWE暗号化
- [Data Model](./data-model.md) - 共有履歴
- [Security](./security.md) - Client ID Schemes、セキュリティ考慮事項
- [Testing](./testing.md) - テスト戦略、エラーハンドリング

## References

- [OID4VP 1.0 Specification](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html)
- [DCQL Section 6](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#name-digital-credentials-query-l)
- [Claim Selection Rules Section 6.4.1](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#section-6.4.1)
- [HAIP (High Assurance Interoperability Profile)](https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-sd-jwt-vc-1_0.html)

### Implementation

- OpenIdProvider: `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift`
- DCQL: `tw2023_wallet/Services/OID/DCQL.swift`
- DCQLMatcher: `tw2023_wallet/Services/OID/DCQLMatcher.swift`
- SharingRequestViewModel: `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestViewModel.swift`
