# OID4VP テストコード一覧

## 概要

OID4VP（OpenID for Verifiable Presentations）1.0プロトコルの実装に対するテストコードの一覧とテスト内容を記載します。

**関連ドキュメント**: [docs/features/credential-presentation/](../../features/credential-presentation/)

## テストファイル一覧

| テストファイル | テスト対象 | ドキュメント |
|--------------|----------|------------|
| DCQLMatcherTests.swift | DCQL資格情報マッチング | [詳細](./dcql-matcher-tests.md) |
| AuthorizationRquestTests.swift | 認可リクエスト解析 | [詳細](./authorization-request-tests.md) |
| OpenIdProviderTests.swift | VP Token送信/レスポンス処理 | [詳細](./openid-provider-tests.md) |
| KeyBindingTests.swift | KB-JWT生成・_sd_alg対応 | [詳細](./key-binding-tests.md) |
| X509HashValidationTests.swift | x509_hash Client ID検証 | [詳細](./x509-hash-validation-tests.md) |

### 共有テスト（サーバー認証）

以下のテストはOID4VCI/OID4VP両方で使用されるため、サーバー認証テストに配置しています。

| テストファイル | テスト対象 | ドキュメント |
|--------------|----------|------------|
| TrustAnchorManagerTests.swift | X.509信頼アンカー管理 | [詳細](../server-authentication/trust-anchor-manager-tests.md) |
| X509ChainValidationTests.swift | X.509証明書チェーン検証 | [詳細](../server-authentication/x509-chain-validation-tests.md) |

### 共有テスト（OID4VCI）

以下のテストはSD-JWT処理としてOID4VCIテストに配置していますが、OID4VPでも使用されます。

| テストファイル | テスト対象 | ドキュメント |
|--------------|----------|------------|
| SDJwtUtilTest.swift | SD-JWT処理・_sd_alg抽出 | [詳細](../oid4vci/sdjwt-util-tests.md) |

---

## Client Identifier Scheme

OID4VP 1.0では、Verifierの識別に以下のClient Identifier Schemeをサポートしています：

| Scheme | 説明 | テスト対象 |
|--------|------|----------|
| `x509_san_dns:` | 証明書SANのDNS名で検証 | ✅ X509HashValidationTests |
| `x509_hash:` | 証明書ハッシュで検証 | ✅ X509HashValidationTests |
| `redirect_uri:` | リダイレクトURIで識別 | - |
| `did:` | DIDで識別 | - |

---

## テスト機能マッピング

| OID4VP機能 | テストファイル | カバレッジ |
|-----------|--------------|----------|
| Authorization Request解析 | AuthorizationRquestTests.swift | ✅ |
| Request URI取得 | AuthorizationRquestTests.swift | ✅ |
| Request Object JWT処理 | AuthorizationRquestTests.swift | ✅ |
| Client Metadata処理 | AuthorizationRquestTests.swift | ✅ |
| DCQL Query解析 | DCQLMatcherTests.swift | ✅ |
| DCQL Credential Matching | DCQLMatcherTests.swift | ✅ |
| 選択的開示（claims absent/present） | DCQLMatcherTests.swift | ✅ |
| ハイブリッドSD-JWT（直接+Disclosure混在） | DCQLMatcherTests.swift | ✅ |
| VP Token送信レスポンス処理 | OpenIdProviderTests.swift | ✅ |
| X.509信頼アンカー管理 | TrustAnchorManagerTests.swift | ✅ |
| X.509証明書チェーン検証 | X509ChainValidationTests.swift | ✅ |
| x5c中間証明書対応 | X509ChainValidationTests.swift | ✅ |
| x5c形式検証（RFC 7515） | X509ChainValidationTests.swift | ✅ |
| x509_hash Client ID検証 | X509HashValidationTests.swift | ✅ |
| x509_san_dns Client ID検証 | X509HashValidationTests.swift | ✅ |
| SD-JWT解析 | SDJwtUtilTest.swift | ✅ |
| SD-JWT _sd_alg抽出 | SDJwtUtilTest.swift | ✅ |
| KB-JWT生成（_sd_alg対応） | KeyBindingTests.swift | ✅ |

---

## 実装状況サマリー

| 機能 | 実装 | テスト | OID4VP 1.0 | 備考 |
|------|:----:|:------:|:----------:|------|
| VP Token生成（SD-JWT VC） | ✅ | ✅ | 必須 | KeyBindingTests.swift |
| VP Token生成（JWT-VC-JSON） | ✅ | - | 必須 | JwtVpJsonGeneratorImpl.swift |
| Key Binding JWT生成 | ✅ | ✅ | 必須 | KeyBindingTests.swift |
| ハイブリッドSD-JWT対応 | ✅ | ✅ | 必須 | DCQLMatcherTests.swift |
| VP Token暗号化（JWE: ECDH-ES + A128GCM） | ✅ | - | オプション | JWE.swift（HAIP準拠） |
| Direct Post | ✅ | - | 必須 | ProviderUtils.swift |
| Direct Post JWT | ✅ | - | オプション | ProviderUtils.swift（HAIP準拠） |
| Client ID Scheme検証（x509_hash） | ✅ | ✅ | 必須 | X509HashValidationTests.swift |
| Client ID Scheme検証（x509_san_dns） | ✅ | ✅ | 必須 | X509HashValidationTests.swift |
| Client ID Scheme検証（redirect_uri） | ✅ | - | 必須 | OpenIdProvider.swift |
| x5c中間証明書対応 | ✅ | ✅ | 必須 | X509ChainValidationTests.swift |
| x5c形式検証（RFC 7515準拠） | ✅ | ✅ | 必須 | X509ChainValidationTests.swift |
| VCT値マッチング | ✅ | ✅ | オプション | DCQLMatcherTests.swift |
| claim_sets対応 | ❌ | - | オプション | 未実装（優先度低） |
| values制限対応 | ❌ | - | オプション | 未実装（優先度低） |

---

## 今後のテスト拡充候補

### テスト追加が望ましい実装済み機能

- [ ] VP Token生成（JWT-VC-JSON） - `JwtVpJsonGeneratorImpl.swift`
- [ ] VP Token暗号化（JWE） - `JWE.swift`
- [ ] Direct Post / Direct Post JWT - `ProviderUtils.swift`
- [ ] Client ID Scheme検証（redirect_uri） - `OpenIdProvider.swift`

### 未実装機能（オプション）

- [ ] claim_sets対応 - 複数クレーム組み合わせオプション
- [ ] values制限対応 - クレーム値の制限検証
