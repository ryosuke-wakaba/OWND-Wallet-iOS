# OID4VCI テストコード一覧

## 概要

OID4VCI（OpenID for Verifiable Credential Issuance）1.0プロトコルの実装に対するテストコードの一覧とテスト内容を記載します。

**関連ドキュメント**: [docs/features/credential-issuance.md](../../features/credential-issuance.md)

## テストファイル一覧

| テストファイル | テスト対象 | パス | ドキュメント |
|--------------|----------|------|------------|
| VCIClientTests.swift | トークン・クレデンシャル発行 | tw2023_walletTests/ | [詳細](./vci-client-tests.md) |
| VCIMetadataTests.swift | メタデータデコード | tw2023_walletTests/ | [詳細](./vci-metadata-tests.md) |
| VCIMetadataClientTests.swift | メタデータ取得 | tw2023_walletTests/ | [詳細](./vci-metadata-client-tests.md) |
| VCIMetadataUtilTests.swift | メタデータユーティリティ | tw2023_walletTests/ | [詳細](./vci-metadata-util-tests.md) |
| SignedMetadataValidatorTests.swift | Signed Metadata検証 | tw2023_walletTests/ | [詳細](./signed-metadata-validator-tests.md) |
| DPoPServiceTests.swift | DPoP Proof生成 | tw2023_walletTests/ | [詳細](./dpop-service-tests.md) |
| KeyPairUtilTest.swift | 鍵ペア・Proof JWT生成 | tw2023_walletTests/Utils/ | [詳細](./keypair-util-tests.md) |
| SDJwtUtilTest.swift | SD-JWT処理 | tw2023_walletTests/Utils/ | [詳細](./sdjwt-util-tests.md) |

---

## テストリソースファイル

テストで使用するJSONリソースファイル一覧：

```
tw2023_walletTests/Resources/
├── credential_offer_filled.json
├── credential_offer_minimum.json
├── credential_offer_tx_code_required.json
├── token_response.json
├── credential_response_jwt_vc_json.json
├── credential_response_vc_sd_jwt.json
├── credential_response_deferred.json
├── credential_response_notification.json
├── credential_response_mock.json
├── credential_display_filled.json
├── credential_display_minimum.json
├── credential_supported_jwt_vc.json
├── credential_supported_vc_sd_jwt.json
├── credential_supported_ldp_vc.json
├── claim_map_empty.json
├── claim_map_filled.json
├── claim_map_mixed.json
├── authorization_server.json
└── credential_issuer_metadata.json
```

---

## テスト機能マッピング

OID4VCI機能とテストの対応関係：

| OID4VCI機能 | テストファイル | カバレッジ |
|-----------|--------------|----------|
| Credential Offer解析 | VCIClientTests.swift | ✅ |
| Issuerメタデータ取得 | VCIMetadataClientTests.swift | ✅ |
| AuthServerメタデータ取得 | VCIMetadataClientTests.swift | ✅ |
| Signed Metadata検証 (Section 12.2.3) | SignedMetadataValidatorTests.swift | ✅ |
| Credential Configuration解析 | VCIMetadataTests.swift | ✅ |
| Token Endpoint通信 | VCIClientTests.swift | ✅ |
| Nonce Endpoint通信 (OID4VCI 1.0) | VCIClientTests.swift | ✅ |
| Credential Endpoint通信 | VCIClientTests.swift | ✅ |
| DPoP Proof生成 (RFC 9449) | DPoPServiceTests.swift | ✅ |
| DPoP-Nonce処理 | VCIClientTests.swift | ✅ |
| Key Binding Proof生成 | KeyPairUtilTest.swift | ✅ |
| SD-JWT解析 | SDJwtUtilTest.swift | ✅ |
| Credential Response処理 | VCIClientTests.swift | ✅ |
| 多言語Display処理 | VCIMetadataTests.swift | ✅ |

---

## 実装状況サマリー

| 機能 | 実装 | テスト | OID4VCI 1.0 | 備考 |
|------|:----:|:------:|:----------:|------|
| Pre-Authorized Code Grant | ✅ | ✅ | 必須 | VCIClientTests.swift |
| Authorization Code Grant | ❌ | - | オプション | 未実装 |
| Nonce Endpoint | ✅ | ✅ | 必須 | OID4VCI 1.0で追加 |
| Signed Metadata (Section 12.2.3) | ✅ | ✅ | オプション | SignedMetadataValidatorTests.swift (x5cのみ) |
| DPoP (RFC 9449) | ✅ | ✅ | HAIP必須 | DPoPServiceTests.swift |
| Key Binding Proof (JWT) | ✅ | ✅ | 必須 | KeyPairUtilTest.swift |
| jwt_vc_json形式 | ✅ | ✅ | オプション | VCIMetadataTests.swift |
| vc+sd-jwt形式 | ✅ | ✅ | オプション | VCIMetadataTests.swift |
| ldp_vc形式 | ✅ | ✅ | オプション | VCIMetadataTests.swift（デコードのみ） |
| Deferred Issuance | ❌ | ✅ | オプション | レスポンス解析のみ |
| Batch Issuance | ❌ | - | オプション | 未実装 |
| Credential Encryption | ❌ | - | オプション | 未実装 |

---

## 今後のテスト拡充候補

### テスト追加が望ましい実装済み機能

以下の機能は実装済みですが、専用のユニットテストがありません：

- [ ] CredentialIssuanceService統合テスト
- [ ] TokenIssuanceService単体テスト
- [ ] CredentialRequestService単体テスト
- [ ] ProofGenerationService単体テスト
- [ ] CredentialStorageService単体テスト
- [ ] DPoP統合テスト（VCIClient経由）

### 未実装機能（オプション）

以下はOID4VCI 1.0のオプション機能であり、現在未実装です：

- [ ] Authorization Code Grant
- [ ] Deferred Issuance完全対応
- [ ] Batch Issuance
- [ ] Credential Encryption
