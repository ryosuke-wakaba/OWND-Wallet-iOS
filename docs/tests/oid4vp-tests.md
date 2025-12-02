# OID4VP テストコード一覧

## 概要

OID4VP（OpenID for Verifiable Presentations）1.0プロトコルの実装に対するテストコードの一覧とテスト内容を記載します。

**関連ドキュメント**: [docs/features/credential-presentation.md](../features/credential-presentation.md)

## テストファイル一覧

| テストファイル | テスト対象 | パス |
|--------------|----------|------|
| DCQLMatcherTests.swift | DCQL資格情報マッチング | tw2023_walletTests/ |
| AuthorizationRquestTests.swift | 認可リクエスト解析 | tw2023_walletTests/ |
| OpenIdProviderTests.swift | VP Token送信/レスポンス処理 | tw2023_walletTests/ |
| ModelDataTests.swift | モデルデータ管理（共有履歴含む） | tw2023_walletTests/Models/ |
| WebViewTests.swift | リダイレクト処理 | tw2023_walletTests/Feature/ShareCredential/Views/ |
| TrustAnchorManagerTests.swift | X.509信頼アンカー管理 | tw2023_walletTests/Signature/ |
| X509ChainValidationTests.swift | X.509証明書チェーン検証 | tw2023_walletTests/Signature/ |
| X509HashValidationTests.swift | x509_hash Client ID検証 | tw2023_walletTests/Signature/ |
| SDJwtUtilTest.swift | SD-JWT処理・_sd_alg抽出 | tw2023_walletTests/Utils/ |
| JWTTest.swift | JWT処理・x5c検証 | tw2023_walletTests/Utils/ |
| KeyBindingTests.swift | KB-JWT生成・_sd_alg対応 | tw2023_walletTests/ |

---

## 1. DCQLMatcherTests.swift

**パス**: `tw2023_walletTests/DCQLMatcherTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/DCQLMatcher.swift`

**概要**: OID4VP 1.0 Section 6.4.1に基づくDCQL（Digital Credentials Query Language）の資格情報マッチングロジックをテストします。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testClaimsAbsent_AllDisclosuresShouldNotBeSubmitted` | claims欠落時の動作 | 全Disclosureが`isSubmit=false`になること |
| `testClaimsPresent_AllClaimsAvailable_MatchedClaimsShouldBeSubmitted` | claims指定時の動作 | 要求クレームのみ`isSubmit=true`になること |
| `testClaimsPresent_SomeClaimsMissing_ShouldReturnNil` | 要求クレーム不足時 | マッチ失敗（nil返却）すること |
| `testFormatMismatch_ShouldReturnNil` | フォーマット不一致時 | マッチ失敗すること |
| `testFormatDcSdJwt_ShouldMatch` | dc+sd-jwtフォーマット | dc+sd-jwtフォーマットが正しくマッチすること |
| `testSingleClaimRequest_ShouldMatchOnlyThatClaim` | 単一クレーム要求 | 指定した1クレームのみマッチすること |
| `testAllClaimsRequest_ShouldMatchAllClaims` | 全クレーム要求 | 全クレームがマッチすること |
| `testInvalidSdJwt_EmptyString_ShouldReturnNil` | 不正なSD-JWT | 空文字列でマッチ失敗すること |
| `testVctMatch_ShouldMatch` | VCTマッチング | VCT（Verifiable Credential Type）値がマッチすること |

### テストデータ

テストで使用するSD-JWTには以下のクレームが含まれます：
- `verified_at`
- `last_name`
- `first_name`
- `is_older_than_15`
- `is_older_than_18`
- `is_older_than_20`
- `is_older_than_65`

### OID4VP 1.0 Section 6.4.1 選択的開示ルール

| claims | 動作 |
|--------|------|
| absent（欠落） | 選択的開示クレームなし。必須クレーム（SD-JWT + KB-JWT）のみ返す |
| present（指定あり） | 指定されたクレームのみ開示 (`isSubmit: true`) |
| present（空配列） | 選択的開示クレームなし |

---

## 2. AuthorizationRquestTests.swift

**パス**: `tw2023_walletTests/AuthorizationRquestTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/AuthorizationRequest.swift`

**概要**: OID4VPの認可リクエスト処理をテストします。

> **Note**: PresentationDefinition（旧PEX仕様）からDCQLへの移行が実施されたため、PEX関連テストは削除済みです。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeUriAsJsonWithVariousTypes` | URIパラメータデコード | 各種データ型のURIパラメータを正しくデコードすること |
| `testUriDecodingAndStructConversion` | URI→構造体変換 | URIをデコードして構造体に正しく変換すること |
| `testProcessRequestObject` | Request Object処理 | JWTフォーマットのRequest Objectを正しく処理すること |
| `testProcessClientMetadata` | Client Metadata処理 | Client MetadataをフェッチしJWKSを正しく処理すること |
| `testProcessClientMetadataFromQueryParameter` | クエリパラメータからのMetadata | クエリパラメータからClient Metadataを正しく解析すること |
| `testProcessClientMetadataUriFromQueryParameter` | Client Metadata URI処理 | Client Metadata URIを正しく処理すること |
| `testFetchAndConvertJWK` | JWK取得・変換 | JWK（JSON Web Key）を正しく取得・変換すること |
| `testExtractKeyIdFromJwt` | Key ID抽出 | JWTから正しくKey IDを抽出すること |

---

## 3. OpenIdProviderTests.swift

**パス**: `tw2023_walletTests/OpenIdProviderTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift`

**概要**: OpenID Provider（VP提示側）の動作をテストします。

> **Note**: PEXテストは削除済み（DCQLへ移行）

### テストクラス: ConvertVpTokenResponseResponseTests

VP Token送信後のレスポンス処理をテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testConvertVpTokenResponseResponse_withValid200JSONResponse` | 200 OK + redirect_uri (JSON) | JSONボディのredirect_uriからリダイレクト先を取得すること |
| `testConvertVpTokenResponseResponse_withInvalid200JSONResponse` | 200 OK（redirect_uri欠落） | redirect_uriがない場合locationがnilになること |

#### OID4VP仕様との整合性

OID4VP 1.0 Section 7.2では、Verifierからのレスポンスは以下の形式が規定されています：

```http
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-store

{
  "redirect_uri": "https://client.example.org/cb#response_code=091535f699ea575c7937fa5f0f454aee"
}
```

実装およびテストはこの仕様に準拠しています。

---

## 4. ModelDataTests.swift

**パス**: `tw2023_walletTests/Models/ModelDataTests.swift`

**対応実装**: 各DataManagerクラス

**概要**: モデルデータの読み込みをテストします。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testLoadCredentials` | クレデンシャル読み込み | クレデンシャルデータを正しく読み込めること |
| `testLoadCredentialSharingHistories` | 共有履歴読み込み | クレデンシャル共有履歴を正しく読み込めること |
| `testLoadSharingHistories` | 共有情報読み込み | 共有情報を正しく読み込めること |
| `testLoadAuthorizationMetaDataList` | 認可メタデータ読み込み | 認可メタデータを正しく読み込めること |
| `testLoadIssuerMetaDataList` | Issuerメタデータ読み込み | Issuerメタデータを正しく読み込めること |
| `testLoadClientInfoList` | クライアント情報読み込み | クライアント情報を正しく読み込めること |

> **Note**: `testLoadPresentationDefinitions`は削除済み（DCQL移行のため）

---

## 5. WebViewTests.swift

**パス**: `tw2023_walletTests/Feature/ShareCredential/Views/WebViewTests.swift`

**対応実装**: `tw2023_wallet/Feature/ShareCredential/Views/RedirectView.swift`

**概要**: VP Token送信後のVerifierサイトへのリダイレクト処理をテストします。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testWebViewLoadsCorrectURL` | URL読み込み確認 | WebViewが正しいURLをロードすること |

---

## テストリソースファイル

テストで使用するJSONリソースファイル一覧：

```
tw2023_walletTests/Resources/
├── presentation_definition.json
├── presentation_definition/
│   ├── presentation_definition_multi_descriptors_1.json
│   └── presentation_definition_multi_descriptors_2.json
└── metadata/
    └── client_metadata.json
```

### リソース内容

| ファイル | 内容 |
|---------|------|
| `presentation_definition.json` | 基本的なPresentation Definition（vc+sd-jwt形式） |
| `presentation_definition_multi_descriptors_1.json` | postal_addressクレーム要求 |
| `presentation_definition_multi_descriptors_2.json` | postal_address + is_older_than_13クレーム複合要求 |
| `client_metadata.json` | Client Metadataサンプル |

---

## 6. TrustAnchorManagerTests.swift

**パス**: `tw2023_walletTests/Signature/TrustAnchorManagerTests.swift`

**対応実装**: `tw2023_wallet/Signature/TrustAnchorManager.swift`

**概要**: X.509証明書の信頼アンカー管理をテストします。OID4VPではClient ID Scheme（x509_san_dns, x509_hash）でVerifierの検証に使用されます。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testSharedInstance` | シングルトン確認 | 同一インスタンスが返されること |
| `testInitialState` | 初期状態確認 | clear後にカスタムアンカーがないこと |
| `testClearCertificates` | 証明書クリア | クリア後に証明書が空になること |
| `testAddAnchorCertificate` | アンカー証明書追加 | アンカー証明書が正しく追加されること |
| `testAddIntermediateCertificate` | 中間証明書追加 | 中間証明書が正しく追加されること |
| `testAddAnchorCertificateFromDerData` | DERデータからアンカー追加 | DERデータからアンカー証明書を追加できること |
| `testAddIntermediateCertificateFromDerData` | DERデータから中間証明書追加 | DERデータから中間証明書を追加できること |
| `testAddInvalidDerData` | 不正DERデータ | 不正なDERデータの追加が失敗すること |
| `testAllCertificates` | 全証明書取得 | アンカー+中間の合計が正しいこと |
| `testReload` | リロード | リロード後にisLoadedがtrueになること |
| `testSelfSignedCertificateDetection` | 自己署名検出 | 自己署名証明書を正しく検出すること |
| `testNonSelfSignedCertificateDetection` | 非自己署名検出 | 非自己署名証明書を正しく検出すること |

---

## 7. X509ChainValidationTests.swift

**パス**: `tw2023_walletTests/Signature/X509ChainValidationTests.swift`

**対応実装**: `tw2023_wallet/Signature/SignatureUtil.swift`

**概要**: X.509証明書チェーンの検証をテストします。カスタム信頼アンカーを使用したJWTのx5cヘッダー検証に対応しています。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testTrustAnchorManagerSetup` | TrustAnchorManager設定 | カスタムアンカーが正しく設定されていること |
| `testValidCertificateChainWithCustomAnchors` | 有効なチェーン検証 | カスタムアンカーでチェーン検証が成功すること |
| `testValidCertificateChainWithTwoTrustChains` | 複数トラストチェーン | 2つの独立したトラストチェーンを検証できること |
| `testInvalidChainWithMissingIntermediate` | 中間証明書欠落 | 中間証明書がない場合に検証が失敗すること |
| `testInvalidChainWithUnknownRoot` | 未知のルート証明書 | 信頼されていないルートで検証が失敗すること |
| `testJwtWithX5CHeaderValidation` | JWT x5c検証 | x5cヘッダー付きJWTが検証できること |
| `testJwtWithX5CHeaderInvalidChain` | JWT x5c無効チェーン | 無効なチェーンでJWT検証が失敗すること |

### テスト証明書チェーン構成

```
Root CA (self-signed)
    └── Intermediate CA
            └── Leaf Certificate (test.example.com)
```

---

## 8. X509HashValidationTests.swift

**パス**: `tw2023_walletTests/Signature/X509HashValidationTests.swift`

**対応実装**:
- `tw2023_wallet/Utils/CertificateUtil.swift` - `validateX509HashClientId()`, `calculateX509CertificateHash()`, `isDomainInSAN()`
- `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift` - 上記関数を使用したclient_id検証

**概要**: OID4VP 1.0の`x509_hash` Client Identifier Prefix検証をテストします。プロダクトコードの`validateX509HashClientId()`関数を直接テストし、X.509証明書のSHA-256ハッシュ計算とclient_idとの照合を検証します。

### テストケース

#### calculateX509CertificateHash関数テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testCalculateX509CertificateHash_ReturnsValidBase64UrlString` | Base64URL形式検証 | ハッシュがBase64URL形式（`[A-Za-z0-9_-]+`）であること |
| `testCalculateX509CertificateHash_ReturnsCorrectLength` | ハッシュ長検証 | SHA-256のBase64URL長が43文字であること |
| `testCalculateX509CertificateHash_IsDeterministic` | 決定性検証 | 同じ証明書から同じハッシュが生成されること |
| `testCalculateX509CertificateHash_DifferentCertificatesProduceDifferentHashes` | 一意性検証 | 異なる証明書から異なるハッシュが生成されること |
| `testCalculateX509CertificateHash_NoBase64Padding` | パディング除去検証 | Base64URLにパディング（`=`）が含まれないこと |
| `testCalculateX509CertificateHash_NoStandardBase64Characters` | URL安全文字検証 | 標準Base64文字（`+`, `/`）が含まれないこと |

#### x509_hash Client ID検証テスト

プロダクトコード`CertificateUtil.swift`の`validateX509HashClientId()`関数を直接テストします。この関数は`OpenIdProvider.swift`から呼び出されます。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testValidateX509Hash_ValidClientId` | 正常系：有効なclient_id | 正しい証明書ハッシュを持つclient_idで検証が成功すること |
| `testValidateX509Hash_WrongHash` | 異常系：別証明書のハッシュ | 異なる証明書（中間CA）のハッシュで検証が失敗すること |
| `testValidateX509Hash_TamperedHash` | 異常系：改ざんされたハッシュ | 1文字改ざんしたハッシュで検証が失敗すること |
| `testValidateX509Hash_WrongPrefix` | 異常系：不正なプレフィックス | `x509_san_dns:`やプレフィックスなしで検証が失敗すること |
| `testValidateX509Hash_EmptyCertificates` | 異常系：証明書なし | 証明書リストが空の場合に検証が失敗すること |

#### JWT x5cヘッダー統合テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testJwtX5cIntegration_ValidClientId` | 正常系：JWT証明書とclient_id一致 | JWTのx5c証明書ハッシュとclient_idが一致する場合に検証成功 |
| `testJwtX5cIntegration_AttackerCertificate` | 攻撃検出：証明書すり替え | 攻撃者が自身の証明書でJWTを署名し、正規のclient_idを使用した場合に検出できること |

#### isDomainInSAN関数テスト（x509_san_dns検証用）

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testIsDomainInSAN_MatchingDomain` | 正常系：SAN一致 | 証明書のSANにドメインが含まれることを検証 |
| `testIsDomainInSAN_NonMatchingDomain` | 異常系：SAN不一致 | SANに含まれないドメインを正しく拒否すること |
| `testIsDomainInSAN_SubdomainMismatch` | 異常系：サブドメイン | SANエントリのサブドメインがマッチしないこと |
| `testIsDomainInSAN_ParentDomainMismatch` | 異常系：親ドメイン | SANエントリの親ドメインがマッチしないこと |

### X509HashValidationResult（検証結果型）

`validateX509HashClientId()`関数は`X509HashValidationResult`列挙型を返します：

| ケース | 説明 |
|-------|------|
| `.success` | 検証成功 |
| `.invalidPrefix` | `x509_hash:`プレフィックスがない |
| `.noCertificates` | 証明書が提供されていない |
| `.hashCalculationFailed` | ハッシュ計算に失敗 |
| `.hashMismatch(expected, actual)` | ハッシュ不一致（期待値と実際の値を含む） |

### OID4VP 1.0 x509_hash仕様

**ハッシュ計算方法**:
```
base64url(SHA-256(DER-encoded-X.509-certificate))
```

**検証フロー**:
1. Request ObjectのJWTからx5cヘッダーを取得
2. リーフ証明書のDERエンコードデータを取得
3. SHA-256ハッシュを計算
4. Base64URLエンコード（パディングなし）
5. `validateX509HashClientId()`でclient_idのハッシュ部分と比較

**参考仕様**: [OpenID for Verifiable Presentations 1.0 - Section 5.9](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#section-5.9)

---

## 9. SDJwtUtilTest.swift

**パス**: `tw2023_walletTests/Utils/SDJwtUtilTest.swift`

**対応実装**: `tw2023_wallet/Utils/SDJwtUtil.swift`

**概要**: SD-JWT（Selective Disclosure JWT）の解析処理をテストします。OID4VPでのVP Token生成に必要な機能です。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDevideSDJwtSignedJwtExtraction` | SD-JWT分割 | Issuer Signed JWT、Disclosure、KB-JWTを正しく分割すること |
| `testDecodeDisclosure` | Disclosure解読 | Disclosureを正しくデコードし、クレーム名を抽出すること |
| `testgetDecodedJwtHeader` | JWTヘッダーデコード | SD-JWTのヘッダーを正しくデコードすること（alg, x5c確認） |
| `testGetSdAlg_Default` | `_sd_alg`デフォルト値 | `_sd_alg`省略時に`sha-256`が返されること |
| `testGetSdAlg_WithExplicitSha256` | `_sd_alg`明示指定 | `_sd_alg: "sha-256"`が正しく読み取られること |
| `testGetSdAlg_WithSha384` | `_sd_alg`値抽出 | `_sd_alg: "sha-384"`が正しく読み取られること（値の抽出確認） |
| `testGetSdAlg_InvalidJwt` | 不正JWT時のデフォルト | 不正なJWT形式でもデフォルト`sha-256`が返されること |
| `testGetSdAlg_EmptyString` | 空文字列入力 | 空文字列入力でもデフォルト`sha-256`が返されること |

### _sd_alg クレーム（SD-JWT draft-22）

`_sd_alg`はSD-JWTペイロードに含まれるハッシュアルゴリズム指定クレームです。

| 値 | 説明 |
|----|------|
| `sha-256` | デフォルト値（省略時も同等） |
| `sha-384` | オプション |
| `sha-512` | オプション |

**参考**: [SD-JWT Section 5.1.2 - Hash Function Claim](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-selective-disclosure-jwt#section-5.1.2)

### SD-JWTフォーマット

| フォーマット | 構成 |
|------------|------|
| `ISSUER_SIGNED_JWT~` | Disclosure/KB-JWTなし |
| `ISSUER_SIGNED_JWT~KBJ` | Disclosureなし、KB-JWTあり |
| `ISSUER_SIGNED_JWT~DISCLOSURE1~DISCLOSURE2~` | KB-JWTなし |
| `ISSUER_SIGNED_JWT~DISCLOSURE1~DISCLOSURE2~KBJ` | 完全形式 |

---

## 10. JWTTest.swift

**パス**: `tw2023_walletTests/Utils/JWTTest.swift`

**対応実装**: `tw2023_wallet/Utils/JWTUtil.swift`

**概要**: JWT（JSON Web Token）の署名・検証処理をテストします。x5cヘッダーによる証明書チェーン検証を含みます。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testSigning` | JWT署名 | ES256アルゴリズムでJWTを署名・検証できること |
| `testDecodeJwt` | JWTデコード | JWTをheader/payload/signatureに正しく分割すること |
| `testVerifyJwtByX5C` | x5c検証 | x5cヘッダーの証明書でJWT署名を検証できること、SANエントリを確認できること |

### x5c検証フロー

1. JWTヘッダーからx5c（証明書チェーン）を抽出
2. リーフ証明書の公開鍵で署名を検証
3. 証明書チェーンの妥当性を検証（オプション）
4. SANエントリでclient_idを確認

---

## 11. KeyBindingTests.swift

**パス**: `tw2023_walletTests/KeyBindingTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/Provider/KeyBindingImpl.swift`

**概要**: Key Binding JWT（KB-JWT）の生成をテストします。SD-JWTのVP Token提示時に必要なKey Bindingの署名生成と`_sd_alg`対応を検証します。

### テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testGenerateJwtSignature` | JWT署名生成・検証 | KB-JWTが正しく署名され、公開鍵で検証できること（`sdAlg: "sha-256"`） |
| `testGenerateJwtWithSha256UpperCase` | 大文字SHA-256拒否 | `sdAlg: "SHA-256"`（大文字）で`UnsupportedHashAlgorithm`エラーが発生すること（case-sensitive） |
| `testGenerateJwtWithUnsupportedAlgorithm` | サポート外アルゴリズム | `sha-512`等のサポート外アルゴリズムで`UnsupportedHashAlgorithm`エラーが発生すること |

### _sd_alg対応（SD-JWT draft-22）

KB-JWT生成時の`_sd_hash`計算は、SD-JWTペイロードの`_sd_alg`クレームで指定されたハッシュアルゴリズムを使用する必要があります。

| アルゴリズム | サポート状況 | 備考 |
|------------|:----------:|------|
| `sha-256` | ✅ | 必須、デフォルト（IANA登録値） |
| `SHA-256` | ❌ | エラー（case-sensitive、IANAレジストリに存在しない） |
| `sha-384` | ❌ | エラー（将来対応予定） |
| `sha-512` | ❌ | エラー（将来対応予定） |

**参考**: [SD-JWT Section 7.1 - Creating a Key Binding JWT](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-selective-disclosure-jwt#section-7.1)

---

## テスト機能マッピング

OID4VP機能とテストの対応関係：

| OID4VP機能 | テストファイル | カバレッジ |
|-----------|--------------|----------|
| Authorization Request解析 | AuthorizationRquestTests.swift | ✅ |
| Request URI取得 | AuthorizationRquestTests.swift | ✅ |
| Request Object JWT処理 | AuthorizationRquestTests.swift | ✅ |
| Client Metadata処理 | AuthorizationRquestTests.swift | ✅ |
| DCQL Query解析 | DCQLMatcherTests.swift | ✅ |
| DCQL Credential Matching | DCQLMatcherTests.swift | ✅ |
| 選択的開示（claims absent/present） | DCQLMatcherTests.swift | ✅ |
| VP Token送信レスポンス処理 | OpenIdProviderTests.swift | ✅ |
| リダイレクト処理 | WebViewTests.swift | ✅ |
| 共有履歴保存 | ModelDataTests.swift | ✅ |
| X.509信頼アンカー管理 | TrustAnchorManagerTests.swift | ✅ |
| X.509証明書チェーン検証 | X509ChainValidationTests.swift | ✅ |
| x509_hash Client ID検証 | X509HashValidationTests.swift | ✅ |
| x509_san_dns Client ID検証 | X509HashValidationTests.swift | ✅ |
| SD-JWT解析 | SDJwtUtilTest.swift | ✅ |
| SD-JWT _sd_alg抽出 | SDJwtUtilTest.swift | ✅ |
| KB-JWT生成（_sd_alg対応） | KeyBindingTests.swift | ✅ |
| JWT署名・検証（x5c含む） | JWTTest.swift | ✅ |

---

## 実装状況サマリー

| 機能 | 実装 | テスト | OID4VP 1.0 | 備考 |
|------|:----:|:------:|:----------:|------|
| VP Token生成（SD-JWT VC） | ✅ | ✅ | 必須 | KeyBindingTests.swift |
| VP Token生成（JWT-VC-JSON） | ✅ | - | 必須 | JwtVpJsonGeneratorImpl.swift |
| Key Binding JWT生成 | ✅ | ✅ | 必須 | KeyBindingTests.swift |
| VP Token暗号化（JWE: ECDH-ES + A128GCM） | ✅ | - | オプション | JWEUtil.swift（HAIP準拠） |
| Direct Post | ✅ | - | 必須 | ProviderUtils.swift |
| Direct Post JWT | ✅ | - | オプション | ProviderUtils.swift（HAIP準拠） |
| Client ID Scheme検証（x509_hash） | ✅ | ✅ | 必須 | X509HashValidationTests.swift |
| Client ID Scheme検証（x509_san_dns） | ✅ | ✅ | 必須 | X509HashValidationTests.swift |
| Client ID Scheme検証（redirect_uri） | ✅ | - | 必須 | OpenIdProvider.swift |
| VCT値マッチング | ✅ | ✅ | オプション | DCQLMatcherTests.swift |
| claim_sets対応 | ❌ | - | オプション | 未実装（優先度低） |
| values制限対応 | ❌ | - | オプション | 未実装（優先度低） |

---

## 今後のテスト拡充候補

### テスト追加が望ましい実装済み機能

以下の機能は実装済みですが、専用のユニットテストがありません：

- [ ] VP Token生成（JWT-VC-JSON） - `JwtVpJsonGeneratorImpl.swift`
- [ ] VP Token暗号化（JWE） - `JWEUtil.swift`
- [ ] Direct Post / Direct Post JWT - `ProviderUtils.swift`
- [ ] Client ID Scheme検証（redirect_uri） - `OpenIdProvider.swift`
- [x] Client ID Scheme検証（x509_hash） - `X509HashValidationTests.swift`で対応済み
- [x] Client ID Scheme検証（x509_san_dns） - `X509HashValidationTests.swift`で対応済み

### 未実装機能（オプション）

以下はOID4VP 1.0のオプション機能であり、現在未実装です：

- [ ] claim_sets対応 - 複数クレーム組み合わせオプション
- [ ] values制限対応 - クレーム値の制限検証

詳細は [docs/dcql-claim-selection-gap-analysis.md](../dcql-claim-selection-gap-analysis.md) を参照。
