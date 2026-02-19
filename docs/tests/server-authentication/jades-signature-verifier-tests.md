# JAdESSignatureVerifierTests.swift

**パス**: `tw2023_walletTests/Signature/JAdESSignatureVerifierTests.swift`

**対応実装**: `tw2023_wallet/Signature/JAdESSignatureVerifier.swift`

**概要**: JAdES（JSON Advanced Electronic Signatures）Baseline-B署名検証のテストです。LoTEドキュメントの署名検証に使用されます。

---

## sigT（署名時刻）検証テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testSigT_WhenMissing_ReturnsError` | sigT欠落 | sigTヘッダーがない場合にエラーとなること |
| `testSigT_WhenInvalidFormat_ReturnsError` | sigT不正形式 | ISO8601形式でない場合にエラーとなること |
| `testSigT_WhenInFuture_ReturnsError` | sigT未来日時 | 署名時刻が未来の場合にエラーとなること |
| `testSigT_WhenWithinTolerance_Succeeds` | sigT許容範囲内 | 許容範囲内（5分）の未来日時が成功すること |
| `testSigT_WhenOutsideCertValidity_ReturnsError` | sigT証明書有効期間外 | 署名時刻が証明書有効期間外の場合にエラーとなること |

---

## x5t#S256（証明書サムプリント）検証テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testX5tS256_WhenMissing_ReturnsError` | x5t#S256欠落 | x5t#S256ヘッダーがない場合にエラーとなること |
| `testX5tS256_WhenMismatch_ReturnsError` | x5t#S256不一致 | サムプリントが証明書と一致しない場合にエラーとなること |
| `testX5tS256_WhenValid_Succeeds` | x5t#S256正常 | 正しいサムプリントで検証が成功すること |

---

## 署名検証テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testSignature_WhenValid_Succeeds` | 正常な署名 | 有効な署名が検証成功すること |
| `testSignature_WhenTampered_ReturnsError` | 改ざんされた署名 | 改ざんされた署名が検出されること |

---

## critヘッダーテスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testCrit_WhenUnprocessedHeader_ReturnsError` | 未処理critヘッダー | 未サポートのcritヘッダーがエラーとなること |

---

## 統合テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testFullJAdESVerification_WithValidJwt_Succeeds` | 完全なJAdES検証 | LoTEペイロード付きの完全なJAdES JWTが検証成功すること |

---

## オプションテスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testOptions_LenientMode_AcceptsLargerSkew` | Lenientモード時間許容 | Lenientモードで大きな時間ずれ（8分）が許容されること |
| `testOptions_DisableCertValidityCheck` | 証明書有効期間チェック無効 | Lenientモードで期限切れ証明書が許容されること |

---

## JAdES Baseline-B JWT構造

**JOSE Header:**
```json
{
  "alg": "ES256",
  "typ": "JWT",
  "x5c": ["<signing-cert-base64>"],
  "sigT": "2026-01-01T12:00:00.000Z",
  "x5t#S256": "<cert-thumbprint-base64url>",
  "crit": ["sigT", "x5t#S256"]
}
```

**Payload:**
```json
{
  "LoTE": {
    "ListAndSchemeInformation": { ... },
    "TrustedEntitiesList": [ ... ]
  }
}
```

---

## 検証項目

| 検証項目 | 説明 |
|---------|------|
| sigT | 署名時刻（ISO8601形式、証明書有効期間内、未来でないこと） |
| x5t#S256 | 証明書サムプリント（SHA-256、Base64URL） |
| crit | 重要ヘッダー（未サポートヘッダーはエラー） |
| 署名 | ES256署名の検証 |
