# SignedMetadataValidatorTests.swift

**パス**: `tw2023_walletTests/SignedMetadataValidatorTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/SignedMetadataValidator.swift`

**概要**: OID4VCI 1.0 Section 12.2.3に基づくSigned Metadata（署名付きメタデータ）の検証をテストします。

---

## テストクラス: SignedMetadataValidatorTests

署名付きメタデータのJWT検証をテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testValidSignedMetadata` | 正常なSigned Metadata | 有効なJWTが正しく検証されること |
| `testInvalidTypHeader` | 不正なtypヘッダー | `typ`が`openidvci-issuer-metadata+jwt`以外の場合にエラーとなること |
| `testMissingTypHeader` | typヘッダー欠落 | `typ`ヘッダーがない場合にエラーとなること |
| `testUnsupportedSignatureMethod_Kid` | kid署名方式 | x5c以外（kid）の署名方式が未サポートエラーとなること |
| `testSubjectMismatch` | sub不一致 | `sub`がIssuer識別子と一致しない場合にエラーとなること |
| `testMissingSub` | sub欠落 | `sub`クレームがない場合にエラーとなること |
| `testMissingIat` | iat欠落 | `iat`クレームがない場合にエラーとなること |
| `testExpiredMetadata` | 期限切れメタデータ | `exp`が過去の場合にエラーとなること |
| `testValidMetadataWithoutExp` | exp省略 | `exp`はオプションなので省略しても検証が成功すること |
| `testExtractMetadataJson` | メタデータJSON抽出 | 検証済みペイロードからメタデータJSONを抽出できること |

---

## Signed Metadata JWT構造

**JOSE Header:**
```json
{
  "alg": "ES256",
  "typ": "openidvci-issuer-metadata+jwt",
  "x5c": ["<leaf-cert-base64>", "<intermediate-cert-base64>", ...]
}
```

**Payload:**
```json
{
  "iss": "<party attesting to claims>",
  "sub": "<credential-issuer-identifier>",
  "iat": 1234567890,
  "exp": 1234567890,
  "credential_issuer": "...",
  "credential_endpoint": "...",
  "credential_configurations_supported": { ... }
}
```

---

## 検証フロー

```
1. JWTデコード
2. typヘッダー検証 (== "openidvci-issuer-metadata+jwt")
3. 署名方式チェック (x5cのみサポート)
4. JWTOperations.verifyJwtByX5C()による署名検証
5. ペイロード検証 (sub == issuer, iat必須, exp検証)
6. メタデータ抽出
```

---

## サポート状況

| 署名方式 | サポート | 備考 |
|---------|:-------:|------|
| x5c | ✅ | X.509証明書チェーン |
| kid | ❌ | 未サポート（エラー） |
| trust_chain | ❌ | 未サポート（エラー） |
