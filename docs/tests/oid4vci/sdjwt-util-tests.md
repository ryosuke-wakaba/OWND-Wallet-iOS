# SDJwtUtilTest.swift

**パス**: `tw2023_walletTests/Utils/SDJwtUtilTest.swift`

**対応実装**: `tw2023_wallet/Utils/SDJwtUtil.swift`

**概要**: SD-JWT（Selective Disclosure JWT）の解析処理をテストします。

---

## テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testDevideSDJwtSignedJwtExtraction` | SD-JWT分割 | Issuer Signed JWT、Disclosure、KB-JWTを正しく分割すること |
| `testDecodeDisclosure` | Disclosure解読 | Disclosureを正しくデコードし、クレーム名を抽出すること |
| `testgetDecodedJwtHeader` | JWTヘッダーデコード | SD-JWTのヘッダーを正しくデコードすること |
| `testGetSdAlg_Default` | `_sd_alg`デフォルト値 | `_sd_alg`省略時に`sha-256`が返されること |
| `testGetSdAlg_WithExplicitSha256` | `_sd_alg`明示指定 | `_sd_alg: "sha-256"`が正しく読み取られること |
| `testGetSdAlg_WithSha384` | `_sd_alg`値抽出 | `_sd_alg: "sha-384"`が正しく読み取られること |
| `testGetSdAlg_InvalidJwt` | 不正JWT時のデフォルト | 不正なJWT形式でもデフォルト`sha-256`が返されること |
| `testGetSdAlg_EmptyString` | 空文字列入力 | 空文字列入力でもデフォルト`sha-256`が返されること |
