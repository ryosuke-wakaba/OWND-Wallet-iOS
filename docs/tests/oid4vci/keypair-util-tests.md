# KeyPairUtilTest.swift

**パス**: `tw2023_walletTests/Utils/KeyPairUtilTest.swift`

**対応実装**: `tw2023_wallet/Utils/KeyPairUtil.swift`

**概要**: 鍵ペア生成とProof JWT作成をテストします。クレデンシャル発行時のKey Binding Proofに使用されます。

---

## テストケース

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testGeneration` | 鍵ペア生成 | ES256鍵ペアが正常に生成されること |
| `testCheckKeyExistence` | 鍵存在確認 | 生成した鍵の存在を確認できること |
| `testGetPrivateKey` | 秘密鍵取得 | 秘密鍵を取得できること |
| `testGetPublicKey` | 公開鍵取得 | 公開鍵を取得できること |
| `testGetKeyPair` | 鍵ペア取得 | 秘密鍵・公開鍵のペアを取得できること |
| `testPublicKeyToJwk` | JWK変換 | 公開鍵をJWK形式に変換できること |
| `testCreateProofJwtAndVerify` | Proof JWT生成・検証 | Proof JWTを生成し、公開鍵で検証できること |
| `testCreatePublicKey` | JWKから公開鍵復元 | JWKからSecKeyを復元できること |

---

## Proof JWT構造（OID4VCI Key Binding）

```json
{
  "header": {
    "typ": "openid4vci-proof+jwt",
    "alg": "ES256",
    "jwk": { ... }
  },
  "payload": {
    "aud": "<credential_issuer>",
    "iat": 1234567890,
    "nonce": "<c_nonce>"
  }
}
```
