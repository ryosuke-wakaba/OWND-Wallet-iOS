# Credential Issuance - Security Considerations

## Threats

### 1. Man-in-the-Middle Attack

**Description**: 通信経路上でのデータ傍受・改ざん

**Mitigation**:
- HTTPS強制
- Certificate Pinning（将来）

### 2. Credential Injection

**Description**: 不正なCredentialの注入

**Mitigation**:
- Issuer署名検証
- Metadata検証

### 3. Replay Attack

**Description**: キャプチャしたリクエストの再送

**Mitigation**:
- Nonce使用
- タイムスタンプ検証
- DPoP-Nonce

### 4. Key Compromise

**Description**: 秘密鍵の漏洩

**Mitigation**:
- Secure Enclave使用
- Key Rotation

### 5. Access Token Theft

**Description**: Access Tokenの盗難・不正使用

**Mitigation**:
- DPoP (Sender-Constrained Access Tokens)
- 盗まれたトークン単体では使用不可（秘密鍵が必要）

## DPoP Security Benefits

DPoP (RFC 9449) は以下のセキュリティ強化を提供:

### 1. Sender-Constrained Access Tokens

- Access Tokenは発行時のクライアントにバインド
- 盗まれたトークンは攻撃者が使用不可

### 2. Proof of Possession

- 各リクエストでクライアントの秘密鍵による署名が必要
- トークン漏洩リスクの大幅な軽減

### 3. Replay Protection

- DPoP-Nonce によるリプレイ攻撃防止
- jti (JWT ID) によるProof再利用防止

### 4. HAIP Compliance

- OID4VCI High Assurance Interoperability Profile準拠
- 高セキュリティ環境での相互運用性

## Security Checklist

| Check | Status | Description |
|-------|--------|-------------|
| HTTPS通信 | ✅ | すべてのHTTP通信がHTTPS |
| Issuer署名検証 | ✅ | Credentialの署名を検証 |
| Keychain保存 | ✅ | 秘密鍵のKeychain保存 |
| Certificate Pinning | ⬜ | 将来実装予定 |
| KB-JWT Nonce検証 | ✅ | Key Binding JWTのNonce検証 |
| Credential有効期限 | ✅ | 有効期限チェック |
| DPoP | ✅ | Sender-Constrained Access Tokens |
| DPoP-Nonce | ✅ | リプレイ攻撃防止 |
| Secure Enclave | ✅ | DPoP鍵のSecure Enclave保存 |

## Key Storage

| Key Type | Storage Location |
|----------|------------------|
| DPoP Key Pair | Secure Enclave |
| Credential Binding Key | Keychain |
| Access Token | Memory (temporary) |

## Best Practices

1. **最小権限の原則**: 必要最小限のスコープでトークンを要求
2. **トークン有効期限**: 短い有効期限を設定し、必要に応じて更新
3. **エラーハンドリング**: セキュリティ関連のエラーを適切に処理（詳細をユーザーに漏らさない）
4. **ログ記録**: セキュリティイベントを適切にログ記録（センシティブ情報は除く）

## References

- [RFC 9449: OAuth 2.0 DPoP](https://www.rfc-editor.org/rfc/rfc9449.html)
- [OWASP Mobile Security](https://owasp.org/www-project-mobile-security/)
- [Apple Security Guidelines](https://developer.apple.com/documentation/security)
