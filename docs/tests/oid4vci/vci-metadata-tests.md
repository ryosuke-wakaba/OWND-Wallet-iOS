# VCIMetadataTests.swift

**パス**: `tw2023_walletTests/VCIMetadataTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/VCIMetadata.swift`

**概要**: Credential IssuerメタデータとCredential Configurationのデコード処理をテストします。

---

## テストクラス: DecodingCredentialDisplayTests

クレデンシャル表示情報のデコードをテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeFilledCredentialDisplay` | 完全なDisplay | name, locale, logo, description, colors等が正しくデコードされること |
| `testDecodeMinimumCredentialDisplay` | 最小限のDisplay | nameのみでデコードできること |

---

## テストクラス: DecodingCredentialSupportedTests

Credential Configurationのデコードをテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeCredentialSupportedJwtVcJson` | jwt_vc_json形式 | jwt_vc_json形式のCredential Configurationがデコードできること |
| `testDecodeCredentialSupportedVcSdJwt` | vc+sd-jwt形式 | vc+sd-jwt形式のCredential Configurationがデコードできること |
| `testDecodeCredentialSupportedLdpVc` | ldp_vc形式 | ldp_vc形式のCredential Configurationがデコードできること |

---

## テストクラス: DecodingClaimMapTests

クレームマップのデコードをテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeEmptyClaimMap` | 空のClaimMap | 空のClaimMapがデコードできること |
| `testDecodeFilledClaimMap` | 完全なClaimMap | mandatory, valueType, display等が正しくデコードされること |
| `testDecodeMixMandatoryAndNonMandatoryClaimMap` | 混合ClaimMap | mandatory/非mandatoryが混在するClaimMapがデコードできること |

---

## テストクラス: localizedClaimNamesTests

クレーム名のローカライズ処理をテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testGetLocalizedClaimNames` | ローカライズ取得 | 指定localeのクレーム名を取得できること |
| `testFirstLocaleSelected` | フォールバック | 未対応localeでは最初のlocaleにフォールバックすること |

---

## テストクラス: DecodingVCIMetadataTests

Credential Issuerメタデータ全体のデコードをテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDecodeVcSdJwtMetadata` | SD-JWTメタデータ | vc+sd-jwt形式のメタデータが完全にデコードされること |
| `testDecodeJwtVcMetadata` | JWT VCメタデータ | jwt_vc_json形式のメタデータが完全にデコードされること |
| `testDecodeLdpVcMetadata` | LDP VCメタデータ | ldp_vc形式のメタデータが完全にデコードされること |

---

## サポートするCredential Format

| フォーマット | 説明 | テスト対象 |
|------------|------|----------|
| `jwt_vc_json` | JWT形式VC | ✅ |
| `vc+sd-jwt` | SD-JWT形式VC | ✅ |
| `ldp_vc` | Linked Data Proof VC | ✅ |
