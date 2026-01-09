# Credential Issuance - Security Considerations

## Threat Model

### 1. Man-in-the-Middle Attack

**Threat**: 通信経路上でのデータ傍受・改ざん

**Mitigation**:
- HTTPS通信の強制（iOS App Transport Security）

### 2. Rogue Issuer

**Threat**: 悪意のあるIssuerからの不正なCredential発行

**Mitigation**:
- Issuer署名検証（JWT署名をJWKで検証）
- Issuer Metadataの検証
- TrustedList による信頼性確認

### 3. Replay Attack

**Threat**: キャプチャしたリクエスト/トークンの再送

**Mitigation**:
- c_nonce使用（Credential Request時）
- DPoP-Nonce（RFC 9449）
- jti (JWT ID) によるProof再利用防止
- iat (発行時刻) によるタイムスタンプ検証

### 4. Access Token Theft

**Threat**: Access Tokenの盗難・不正使用

**Mitigation**:
- DPoP (Sender-Constrained Access Tokens)
- トークン単体では使用不可（DPoP秘密鍵が必要）

### 5. Key Compromise

**Threat**: 秘密鍵の漏洩

**Mitigation**:
- Secure Enclaveでの鍵生成・保管
- 秘密鍵はデバイス外に出ない

## Security Checklist

| Check | Status | Notes |
|-------|--------|-------|
| HTTPS通信 | ✅ | iOS ATS (App Transport Security) |
| Issuer署名検証 | ✅ | `JWTUtil.verifyJwt()` |
| Secure Enclave | ✅ | `KeyPairUtil.generateSignVerifyKeyPair()` |
| DPoP | ✅ | `DPoPService.swift` |
| DPoP-Nonce | ✅ | リプレイ攻撃防止 |
| c_nonce検証 | ✅ | Credential Request Proof |
| Certificate Pinning | ⬜ | 未実装 |

## Key Storage

| Key | Storage | Purpose |
|-----|---------|---------|
| DPoP Key Pair | Secure Enclave | Sender-Constrained Tokens |
| Credential Binding Key | Secure Enclave | KB-JWT署名 |
| DataStore Encryption Key | Keychain | CoreData暗号化 |

## DPoP Security

DPoPによるセキュリティ強化の詳細は [dpop.md](./dpop.md) を参照。

## Implementation References

| File | Security Feature |
|------|------------------|
| `tw2023_wallet/Utils/KeyPairUtil.swift` | Secure Enclave鍵管理 |
| `tw2023_wallet/Services/OID/VCI/DPoPService.swift` | DPoP Proof生成 |
| `tw2023_wallet/Signature/JWTUtil.swift` | JWT署名・検証 |

## External References

- [RFC 9449: OAuth 2.0 DPoP](https://www.rfc-editor.org/rfc/rfc9449.html)
- [Apple Secure Enclave](https://developer.apple.com/documentation/security/certificate_key_and_trust_services/keys/protecting_keys_with_the_secure_enclave)
