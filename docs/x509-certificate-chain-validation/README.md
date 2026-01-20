# X.509証明書チェーン検証機能

## 概要

X.509証明書チェーン検証とトラストリスト（ETSI TS 119 602 LoTE形式）管理機能を提供します。

### 主な機能

| 機能 | 説明 | 仕様 |
|------|------|------|
| Certificate Chain Validation | カスタム信頼アンカーを使用した証明書チェーン検証 | RFC 5280 |
| Trust List Management | LoTE形式のトラストリスト管理と証明書検索 | ETSI TS 119 602 |
| Certificate-Based Search | AKI/SKI・DNによる証明書マッチング | RFC 5280 |

### 使用される機能

- **OID4VCI**: 署名付きメタデータの検証 → [Metadata Verification](../features/credential-issuance/metadata-verification.md)
- **OID4VP**: Request Object JWTの検証

## アーキテクチャ

```
┌─────────────────────────────────────────────────────────────────┐
│                       呼び出し元                                  │
│         (VCIMetadataClient, OpenIdProvider, etc.)                │
│                           │                                      │
│                           ▼                                      │
│                    X5CJWTVerifier                                │
│          (JWT検証 + 証明書チェーン検証統合)                        │
│                           │                                      │
│              ┌────────────┼────────────┐                         │
│              ▼            ▼            ▼                         │
│      JWTOperations  TrustedListManager  X509CertificateOps       │
│      (署名検証)     (トラストリスト検索)  (チェーン検証)            │
│                           │            │                         │
│                           ▼            ▼                         │
│                    TrustAnchorManager   SecTrust API             │
│                    (証明書管理)         (iOS検証)                 │
└─────────────────────────────────────────────────────────────────┘
```

## ドキュメント構成

| ドキュメント | 内容 |
|-------------|------|
| [components.md](./components.md) | コンポーネントAPI（TrustAnchorManager, X509CertificateOperations, TrustedListManager, X5CJWTVerifier） |
| [trusted-list.md](./trusted-list.md) | トラストリスト（Certificate-Based Search, LoTE Data Models） |
| [chain-validation.md](./chain-validation.md) | 証明書チェーン検証（SecTrust API, useCustomAnchorsOnly, 検証フロー） |
| [setup.md](./setup.md) | セットアップ、テスト、トラブルシューティング |

## 関連ファイル

### 証明書検証

| ファイル | 説明 |
|---------|------|
| `tw2023_wallet/Signature/TrustAnchorManager.swift` | 信頼アンカー証明書管理 |
| `tw2023_wallet/Signature/X509CertificateOperations.swift` | 証明書チェーン検証 |
| `tw2023_wallet/Signature/X5CJWTVerifier.swift` | x5c/x5u JWT検証ラッパー |
| `tw2023_wallet/Signature/JWT.swift` | JWT操作 |
| `tw2023_wallet/Resources/Certificates/.gitkeep` | 証明書ディレクトリ |

### トラストリスト

| ファイル | 説明 |
|---------|------|
| `tw2023_wallet/Services/TrustedList/TrustedListManager.swift` | トラストリスト管理 |
| `tw2023_wallet/Services/TrustedList/TrustedListModels.swift` | LoTEデータモデル |
| `tw2023_wallet/Services/TrustedList/TrustedListConfig.swift` | LoTE設定モデル・ローダー |
| `TrustedListConfig.json` | LoTE設定ファイル |

### 呼び出し元

| ファイル | 説明 |
|---------|------|
| `tw2023_wallet/Services/OID/VCI/VCIMetadataClient.swift` | メタデータ取得クライアント |
| `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift` | OID4VP処理 |

## References

### Specifications

- [RFC 5280 - X.509 PKI Certificate](https://www.rfc-editor.org/rfc/rfc5280.html)
- [ETSI TS 119 602 - Trusted Lists](https://www.etsi.org/deliver/etsi_ts/119600_119699/119602/01.01.01_60/ts_119602v010101p.pdf)
- [Apple Developer: Certificate, Key, and Trust Services](https://developer.apple.com/documentation/security/certificate_key_and_trust_services)
- [SecTrust Reference](https://developer.apple.com/documentation/security/sectrust)

### Related Documentation

- [Metadata Verification](../features/credential-issuance/metadata-verification.md) - 発行時のメタデータ検証
