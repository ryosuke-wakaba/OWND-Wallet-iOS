# OID4VP テストコード一覧

## 概要

OID4VP（OpenID for Verifiable Presentations）1.0プロトコルの実装に対するテストコードの一覧とテスト内容を記載します。

**関連ドキュメント**: [docs/features/credential-presentation/](../../features/credential-presentation/)

## テストファイル一覧

| テストファイル | テスト対象 | ドキュメント |
|--------------|----------|------------|
| X509HashValidationTests.swift | x509_hash Client ID検証 | [詳細](./x509-hash-validation-tests.md) |

---

## Client Identifier Scheme

OID4VP 1.0では、Verifierの識別に以下のClient Identifier Schemeをサポートしています：

| Scheme | 説明 | テスト対象 |
|--------|------|----------|
| `x509_san_dns:` | 証明書SANのDNS名で検証 | - |
| `x509_hash:` | 証明書ハッシュで検証 | ✅ |
| `redirect_uri:` | リダイレクトURIで識別 | - |
| `did:` | DIDで識別 | - |
