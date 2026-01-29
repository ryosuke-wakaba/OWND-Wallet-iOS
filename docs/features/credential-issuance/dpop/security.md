# DPoP セキュリティ

## セキュリティ効果

DPoP (RFC 9449) は以下のセキュリティ強化を提供します。

### 1. Sender-Constrained Access Tokens

- アクセストークンは発行時のクライアント公開鍵にバインド
- 盗まれたトークン単体では使用不可
- 秘密鍵を持つクライアントのみがトークンを使用可能

### 2. Proof of Possession

- 各リクエストでクライアントの秘密鍵による署名が必要
- Man-in-the-Middle攻撃への耐性
- トークン漏洩リスクの大幅な軽減

### 3. Replay Protection

- `jti` (JWT ID): 各Proofに一意のID
- `DPoP-Nonce`: サーバー発行のnonce
- `ath`: アクセストークンへのバインディング

### 4. URI Binding

- `htu`: リクエスト先URIへのバインディング
- `htm`: HTTPメソッドへのバインディング
- 異なるエンドポイントでのProof再利用を防止

### 5. HAIP Compliance

- OID4VCI High Assurance Interoperability Profile準拠
- 高セキュリティ環境での相互運用性

## 鍵管理

### DPoP鍵ペア

| 項目 | 値 |
|------|-----|
| キーエイリアス | `dpopKey` (Constants.Cryptography.KEY_DPOP) |
| アルゴリズム | ECDSA P-256 (secp256r1) |
| 保存場所 | Keychain / Secure Enclave |
| 生成タイミング | DPoP Proof初回生成時（自動） |

### 鍵生成フロー

```swift
// DPoPService.ensureKeyPairExists()
if !KeyPairUtil.isKeyPairExist(alias: keyAlias) {
    try KeyPairUtil.generateSignVerifyKeyPair(alias: keyAlias)
}
```

### 実装上の注意

- DPoP鍵はSecure Enclaveに保存
- 各リクエストで新しいDPoP Proofを生成
- サーバーからの`DPoP-Nonce`ヘッダーを適切に処理

## Authorization Server側での検証手順

### 1. DPoP Proof JWTの基本検証

- `typ`が`dpop+jwt`であること
- `alg`がサポートされた非対称アルゴリズムであること（ES256）
- `jwk`ヘッダーに有効な公開鍵が含まれること
- 署名が`jwk`の公開鍵で検証できること

### 2. Payloadクレームの検証

- `jti`がユニークであること（リプレイ検出）
- `htm`がリクエストのHTTPメソッドと一致すること
- `htu`がリクエストのターゲットURIと一致すること
- `iat`が合理的な範囲内であること

### 3. Access Token使用時の追加検証

- `ath`がアクセストークンのハッシュと一致すること
- アクセストークン発行時の`jwk`と一致すること
- `nonce`がサーバー発行値と一致すること（提供した場合）
