# Authentication - Security Considerations

## Threat Model

### 1. Account Spoofing

**Threat**: 攻撃者が他人のAccountになりすます

**Mitigation**:
- ID Token署名の検証
- JWK Thumbprintによる識別子の一意性保証

### 2. ID Token Replay Attack

**Threat**: 傍受したID Tokenの再送

**Mitigation**:
- Nonce使用（リクエストごとに一意）
- 有効期限（exp claim）
- ワンタイムトークン

### 3. Key Compromise

**Threat**: 秘密鍵の漏洩

**Mitigation**:
- HDKeyRingによる鍵派生（マスターキーからの派生）
- Keychain保存
- Mnemonicの安全なバックアップ

### 4. RP Tracking

**Threat**: 複数のRPがユーザーを追跡

**Mitigation**:
- Pairwise識別子（RP毎に異なるsub claim）
- RP間での識別子の相関不可

## Security Checklist

| Check | Status | Notes |
|-------|--------|-------|
| ID Token署名 | ✅ | ES256 |
| Nonce検証 | ✅ | リプレイ攻撃防止 |
| 秘密鍵のKeychain保存 | ✅ | iOS Keychain |
| HTTPS通信 | ✅ | iOS ATS |
| Pairwise識別子 | ✅ | トラッキング防止 |
| Key Rotation機能 | ⬜ | 未実装 |

## Key Management

| Key | Storage | Purpose |
|-----|---------|---------|
| HD Master Seed | Keychain | 全Accountの派生元 |
| Derived Private Keys | Memory (on-demand) | ID Token署名 |
| Mnemonic Backup | User-managed | アカウント復元 |

## Privacy Features

1. **Pairwise Identifiers**: 各RPに異なるsub claimを提供
2. **最小限の開示**: 要求されたclaimsのみを含む
3. **ユーザーコントロール**: 認証前に開示内容を確認

## Implementation References

| File | Security Feature |
|------|------------------|
| `tw2023_wallet/Services/OID/Provider/HDKeyRing.swift` | HD鍵派生 |
| `tw2023_wallet/Services/OID/Provider/PairwiseAccount.swift` | Pairwise識別子管理 |
| `tw2023_wallet/Signature/JWT.swift` | ID Token署名 |

## References

- [SIOPv2 Security Considerations](https://openid.net/specs/openid-connect-self-issued-v2-1_0-13.html#name-security-considerations)
- [BIP-32: Hierarchical Deterministic Wallets](https://github.com/bitcoin/bips/blob/master/bip-0032.mediawiki)
