# Wallet Attestation セキュリティ

## セキュリティ効果

Wallet Attestation (OAuth 2.0 Attestation-Based Client Authentication) は以下のセキュリティ強化を提供します。

### 1. Wallet Trust

- Wallet Providerによる署名でWalletの信頼性を証明
- 不正なクライアントからのリクエストを拒否可能

### 2. Proof of Possession

- Client Attestation PoP JWTによる鍵所有証明
- Attestationの盗用・悪用を防止

### 3. Certificate Chain Validation

- x5cヘッダーによる証明書チェーン検証
- Wallet Providerの正当性を検証可能

### 4. HAIP Compliance

- OID4VCI High Assurance Interoperability Profile (4.4.1) 準拠
- 高セキュリティ環境での相互運用性

## Authorization Server側での検証手順

### 1. Client Attestation JWTの検証

- `typ`が`oauth-client-attestation+jwt`であること
- `x5c`ヘッダーから証明書チェーンを取得
- Trust Anchorに対して証明書チェーンを検証
- Leaf証明書から公開鍵を抽出
- JWTの署名を検証
- `exp`が未来であることを確認
- `nbf`が過去であることを確認（存在する場合）

### 2. Client Attestation PoP JWTの検証

- `typ`が`oauth-client-attestation-pop+jwt`であること
- `iss`がClient Attestationの`sub`と一致すること
- `aud`が認可サーバーのIssuer URLと一致すること
- `jti`がユニークであること（リプレイ検出）※本実装では割愛
- 署名がClient Attestationの`cnf.jwk`で検証できること
- `iat`が合理的な範囲内であることを確認
