# DPoPServiceTests.swift

**パス**: `tw2023_walletTests/DPoPServiceTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/VCI/DPoPService.swift`

**概要**: RFC 9449に基づくDPoP（Demonstrating Proof of Possession）のProof生成をテストします。

---

## ath（Access Token Hash）計算テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testCalculateAthConsistency` | ath計算一貫性 | 同じアクセストークンから同じathが生成されること |
| `testCalculateAthWithKnownValue` | ath計算検証 | 既知の値（SHA256("test")）でathが正しく計算されること |
| `testCalculateAthProducesBase64UrlEncoding` | Base64URL形式 | athがBase64URL形式（+/=なし）であること |

---

## DPoP Proof生成テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testCreateProofForTokenEndpoint` | Token Endpoint用Proof | typ, alg, jwk, jti, htm, htu, iatが正しく含まれ、athがないこと |
| `testCreateProofWithAccessToken` | Resource Server用Proof | athクレームが正しく含まれること |
| `testCreateProofWithNonce` | nonce付きProof | nonceクレームが正しく含まれること |
| `testUriNormalization` | URI正規化 | htuからquery/fragmentが除去されること |
| `testUniqueJtiGeneration` | jti一意性 | 各Proofに固有のjtiが生成されること |
| `testGetPublicKeyJwk` | 公開鍵JWK取得 | DPoP鍵の公開鍵JWKが取得できること |

---

## DPoP Proof JWT構造

**Header:**
```json
{
  "typ": "dpop+jwt",
  "alg": "ES256",
  "jwk": { "kty": "EC", "crv": "P-256", "x": "...", "y": "..." }
}
```

**Payload (Token Endpoint):**
```json
{
  "jti": "<unique-id>",
  "htm": "POST",
  "htu": "https://issuer.example.com/token",
  "iat": 1234567890
}
```

**Payload (Resource Server):**
```json
{
  "jti": "<unique-id>",
  "htm": "POST",
  "htu": "https://issuer.example.com/credential",
  "iat": 1234567890,
  "ath": "<base64url(sha256(access_token))>",
  "nonce": "<server-provided-nonce>"
}
```

---

## RFC 9449 準拠

| 要件 | 対応状況 |
|-----|:-------:|
| typ: "dpop+jwt" | ✅ |
| 非対称アルゴリズム (ES256) | ✅ |
| 公開鍵をjwkに含める | ✅ |
| jti (一意なID) | ✅ |
| htm (HTTPメソッド) | ✅ |
| htu (ターゲットURI、query/fragmentなし) | ✅ |
| iat (発行時刻) | ✅ |
| ath (アクセストークンハッシュ) | ✅ |
| nonce (サーバー提供nonce) | ✅ |
