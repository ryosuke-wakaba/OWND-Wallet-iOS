# Credential Presentation - Security Considerations

## Client ID Schemes (OID4VP 1.0)

Verifierの検証に使用されるClient ID Schemeです。

| Scheme | 検証方法 |
|--------|----------|
| `x509_san_dns` | X.509証明書のSAN DNS名がclient_idと一致することを確認 |
| `x509_hash` | X.509証明書のハッシュがclient_idと一致することを確認 |
| `redirect_uri` | client_idがresponse_uriと一致することを確認 |

## Threat Model

### 1. Phishing Attack

**Threat**: 悪意のあるVerifierがユーザーを騙してクレデンシャルを取得

**Mitigation**:
- X.509証明書によるVerifier検証
- Verifier情報の明確な表示（名前、ロゴ、プライバシーポリシー）

### 2. Over-Disclosure

**Threat**: 必要以上のクレームを開示してしまう

**Mitigation**:
- OID4VP 1.0準拠の選択的開示
- `claims` absent時は選択的開示クレームを含めない
- 開示するクレームをユーザーに明示

### 3. VP Replay Attack

**Threat**: キャプチャしたVP Tokenの再送

**Mitigation**:
- Nonce使用（リクエストごとに一意）
- タイムスタンプ検証
- ワンタイムVP（一度使用したら無効）

### 4. Man-in-the-Middle Attack

**Threat**: 通信経路上でのVP Token傍受

**Mitigation**:
- VP Token JWE暗号化（HAIP）
- HTTPS通信

## Security Checklist

| Check | Status | Notes |
|-------|--------|-------|
| ユーザー同意の取得 | ✅ | 共有前に確認画面を表示 |
| VP署名の実施 | ✅ | Key Binding JWT |
| Nonce検証 | ✅ | リプレイ攻撃防止 |
| HTTPS通信 | ✅ | iOS ATS |
| X.509証明書によるVerifier検証 | ✅ | Client ID Scheme |
| VP Token暗号化（JWE） | ✅ | ECDH-ES + A128GCM |
| OID4VP 1.0準拠の選択的開示 | ✅ | Section 6.4.1 |

## Privacy Considerations

1. **最小限の情報開示**: Verifierが要求したクレームのみを開示
2. **ユーザーコントロール**: 共有前にどの情報が開示されるか確認可能
3. **履歴管理**: いつ、どのVerifierに、何を共有したか確認可能

## Implementation References

| File | Security Feature |
|------|------------------|
| `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift` | Client ID Scheme検証 |
| `tw2023_wallet/Signature/JWEUtil.swift` | VP Token暗号化 |
| `tw2023_wallet/Services/OID/DCQLMatcher.swift` | 選択的開示 |

## References

- [OID4VP 1.0 Security Considerations](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#name-security-considerations)
- [HAIP (High Assurance Interoperability Profile)](https://openid.net/specs/openid4vc-high-assurance-interoperability-profile-sd-jwt-vc-1_0.html)
