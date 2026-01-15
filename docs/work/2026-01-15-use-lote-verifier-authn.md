# OID4VP Verifier認証におけるLoTE証明書の使用

## ブランチ

`feature/use-lote-verifier-authn`

## ステータス

- [x] 調査完了
- [x] 実装完了
- [x] ビルド確認
- [ ] テスト実行
- [ ] レビュー

## 概要

OID4VPの署名付きリクエストオブジェクトを検証する際、証明書チェーンの検証に使用する中間証明書とルート証明書をTrustedListManagerを使って取得するように変更する。

### 背景

現在の実装では、OID4VPのVerifier認証時に`X5CJWTVerifier.verifyJwtWithX5C`を呼び出す際、`issuerURL: nil`と`loteSearchInfos: []`を渡しているため、シングルトンの`TrustAnchorManager`（ビルトインのCertificatesフォルダからの証明書）のみを使用している。

TrustedListConfig.jsonには既に`oid4vp`サービスが設定されているため、これを活用することでLoTE（List of Trusted Entities）から証明書を取得できるようにする。

## 変更内容

### 変更ファイル

- `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift`

### 変更箇所

```swift
// Before:
if isX509SanDns || isX509Hash {
    // Verify certificate chain using custom trust anchors (built-in intermediate + root)
    // Use async version with nil issuerURL and empty loteSearchInfos to use singleton TrustAnchorManager
    // (TrustedList is for issuers, not verifiers)
    let result = await X5CJWTVerifier.verifyJwtWithX5C(jwt: jwt, issuerURL: nil, loteSearchInfos: [], verifyCertChain: true)

// After:
if isX509SanDns || isX509Hash {
    // Verify certificate chain using TrustedList (LoTE) for verifier authentication
    let loteSearchInfos = TrustedListConfigLoader.createSearchInfos([("jp-lote", "oid4vp")])
    let verifierURL = requestObj?.responseUri ?? requestObj?.redirectUri
    let result = await X5CJWTVerifier.verifyJwtWithX5C(jwt: jwt, issuerURL: verifierURL, loteSearchInfos: loteSearchInfos, verifyCertChain: true)
```

### 動作の変更

1. `TrustedListConfigLoader.createSearchInfos`で`oid4vp`サービス用のLoTE検索情報を取得
2. VerifierのURL（`response_uri`または`redirect_uri`）を`issuerURL`として使用
3. `X5CJWTVerifier.verifyJwtWithX5C`がTrustedListManagerを使用して証明書を取得

### フォールバック動作

LoTEからの証明書取得に失敗した場合、既存の動作と同様にシングルトンの`TrustAnchorManager`にフォールバックする（`X5CJWTVerifier.validateCertificateChain`内の既存ロジック）。

## 設定ファイル

### TrustedListConfig.json

```json
{
  "lotes": {
    "jp-lote": {
      "url": "https://tl.eujp.ownd-project.com/api/trusted-list.jwt",
      "services": {
        "oid4vci": {
          "identifier": "http://example.com/SvcType/OID4VCI/CredentialIssuance"
        },
        "oid4vp": {
          "identifier": "http://tl.eujp.ownd-project.com/SvcType/OID4VP/Verification"
        },
        "diw": {
          "identifier": "http://tl.eujp.ownd-project.com/SvcType/WalletSolution/WalletProvider"
        }
      }
    }
  }
}
```

## 関連ドキュメント

- [docs/features/credential-issuance/metadata-verification.md](../features/credential-issuance/metadata-verification.md)
- [docs/x509-certificate-chain-validation.md](../x509-certificate-chain-validation.md)
- [2026-01-09-lote-service-type-support.md](./2026-01-09-lote-service-type-support.md)
