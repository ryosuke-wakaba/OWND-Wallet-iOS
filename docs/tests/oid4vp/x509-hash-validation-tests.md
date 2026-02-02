# X509HashValidationTests.swift

**パス**: `tw2023_walletTests/X509HashValidationTests.swift`

**対応実装**: `tw2023_wallet/Signature/X509CertificateOperations.swift`

**概要**: OID4VP 1.0のx509_hash Client ID検証のテストです。

---

## ハッシュ計算テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testCalculateX509CertificateHash_ReturnsValidBase64UrlString` | Base64URL形式の確認 | ハッシュがBase64URL形式であること |
| `testCalculateX509CertificateHash_ReturnsCorrectLength` | SHA-256ハッシュ長の確認（43文字） | ハッシュが43文字であること |
| `testCalculateX509CertificateHash_IsDeterministic` | 決定性の確認 | 同じ証明書から同じハッシュが生成されること |
| `testCalculateX509CertificateHash_DifferentCertificatesProduceDifferentHashes` | 異なる証明書で異なるハッシュ | 異なる証明書では異なるハッシュが生成されること |
| `testCalculateX509CertificateHash_NoBase64Padding` | パディングなし確認 | Base64パディング（=）がないこと |
| `testCalculateX509CertificateHash_NoStandardBase64Characters` | `+`/`/`なし確認 | 標準Base64文字（+/）が使われていないこと |

---

## x509_hash検証テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testValidateX509Hash_ValidClientId` | 正しいclient_idの検証成功 | 正しいx509_hash形式のclient_idが検証できること |
| `testValidateX509Hash_WrongHash` | 不正なハッシュの検証失敗 | 不正なハッシュで検証が失敗すること |
| `testValidateX509Hash_TamperedHash` | 改ざんされたハッシュの検出 | 改ざんされたハッシュが検出されること |
| `testValidateX509Hash_WrongPrefix` | 不正なプレフィックスのエラー | `x509_san_dns:`など不正なプレフィックスがエラーとなること |
| `testValidateX509Hash_EmptyCertificates` | 空の証明書リストのエラー | 空の証明書リストでエラーとなること |

---

## 統合テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testJwtX5cIntegration_ValidClientId` | JWT x5cとclient_idの統合検証 | JWT x5cヘッダーからのclient_id検証が成功すること |
| `testJwtX5cIntegration_AttackerCertificate` | 攻撃者証明書の検出 | 攻撃者の証明書でclient_id検証が失敗すること |

---

## SAN検証テスト

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testIsDomainInSAN_MatchingDomain` | SANドメイン一致 | SANに含まれるドメインが一致すること |
| `testIsDomainInSAN_NonMatchingDomain` | SANドメイン不一致 | SANに含まれないドメインが不一致となること |
| `testIsDomainInSAN_SubdomainMismatch` | サブドメイン不一致 | サブドメインが一致しないこと |
| `testIsDomainInSAN_ParentDomainMismatch` | 親ドメイン不一致 | 親ドメインが一致しないこと |
