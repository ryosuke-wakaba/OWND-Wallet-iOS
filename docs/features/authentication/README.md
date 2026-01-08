# Authentication (SIOPv2)

## Status
- [x] Draft
- [ ] Review
- [ ] Approved
- [x] Implemented
- [ ] Verified

## Overview

SIOPv2 (Self-Issued OpenID Provider v2) プロトコルを使用した、分散型アイデンティティ認証機能です。

## User Stories

- As a user, I want to authenticate to relying parties using my self-issued identity
- As a user, I want to manage multiple pairwise accounts for different services
- As a user, I want to export/import my accounts between devices
- As a user, I want to see my authentication history

## Requirements

### Functional Requirements

1. **SIOP Request Handling**
   - `openid://` スキームのサポート
   - Request URIからのJWT取得
   - リクエストの検証

2. **Pairwise Account Management**
   - Pairwise Accountの生成
   - 既存Accountの選択
   - RP別識別子対応

3. **ID Token Generation**
   - Self-issued ID Tokenの生成
   - 署名の実施
   - Claimsの構築

4. **Response Submission**
   - Direct Post対応
   - Redirectフロー対応

5. **Account Backup & Restore**
   - Mnemonicベースのアカウントエクスポート
   - アカウントインポート（Backup/Restore機能）
   - アカウント情報の管理

### Non-Functional Requirements

1. **Security**
   - 秘密鍵のセキュア管理
   - ID Tokenの適切な署名
   - リプレイ攻撃対策

2. **Privacy**
   - Pairwise識別子によるトラッキング防止
   - 最小限の情報開示

3. **Usability**
   - シンプルな認証フロー
   - わかりやすいRP情報表示

## Implementation Status

- [x] SIOP Request解析
- [x] Request URI取得
- [x] Pairwise Account生成（HDKeyRing）
- [x] ID Token生成
- [x] Direct Post実装
- [x] ID Token署名
- [x] 認証履歴保存
- [ ] 複数Account管理UI
- [x] アカウントエクスポート/インポート（Backup/Restore機能として実装済み）
- [ ] DIDメソッド対応（did:key, did:web等）（将来）

## Related Documents

- [Design](./design.md) - UI/UX、データフロー
- [API Reference](./api.md) - OpenIdProvider、PairwiseAccount
- [Data Model](./data-model.md) - ID Token共有履歴
- [Security](./security.md) - セキュリティ考慮事項
- [Testing](./testing.md) - テスト戦略

## References

- [SIOPv2 Specification](https://openid.net/specs/openid-connect-self-issued-v2-1_0-13.html)

### Implementation

- OpenIdProvider: `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift`
- PairwiseAccount: `tw2023_wallet/Services/OID/Provider/PairwiseAccount.swift`
- HDKeyRing: `tw2023_wallet/Services/OID/Provider/HDKeyRing.swift`
