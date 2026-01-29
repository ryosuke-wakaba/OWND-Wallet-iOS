# Wallet Attestation 実装詳細

## 擬似ウォレットプロバイダー実装

本来、Wallet ProviderはWalletとは独立した外部サービスとして存在し、モバイルOSのDeviceCheck（iOS）やPlay Integrity（Android）を使用してWalletの信頼性を検証した上でAttestationを発行します。

本実装では、テスト・開発目的で擬似的にWallet Provider機能をウォレット内部に組み込んでいます。

## Wallet Attestation生成の操作

1. **設定画面でトグルをON**: ユーザーが設定画面で「クライアント認証」トグルを有効化
2. **自動生成処理**: Attestation用キーペア（ES256）を生成し、Client Attestation JWTを生成・保存
3. **クレデンシャル発行時の使用**: Token Request時に自動的にヘッダーを追加（期限切れの場合は自動再生成）

## プロバイダーのキーペア情報

### Provider秘密鍵

| 項目 | 値 |
|------|-----|
| ファイルパス | `WalletProviderCert/wallet-provider-private.key` |
| ビルド後パス | `<app-bundle>/wallet-provider-private.key` |
| フォーマット | PEM (SEC1 EC PRIVATE KEY) |
| アルゴリズム | ECDSA P-256 (secp256r1) |

### Provider証明書

| 項目 | 値 |
|------|-----|
| ファイルパス | `WalletProviderCert/wallet-provider.cer` |
| ビルド後パス | `<app-bundle>/wallet-provider.cer` |
| フォーマット | PEM (X.509 Certificate) |
| アルゴリズム | ECDSA P-256 with SHA-256 |
| 発行者 | CN=Test Root CA, O=Cyber Security Cloud, L=Sinagawa, ST=Tokyo, C=JP |
| サブジェクト | CN=OWND Project, O=Cyber Security Cloud, L=Sinagawa, ST=Tokyo, C=JP |
| 有効期間 | 2026-01-23 〜 2028-04-27 |

### Attestation定数

| 定数 | 値 | 説明 |
|------|-----|------|
| `PROVIDER_ISSUER` | `https://wallet-provider.ownd-project.com` | Client Attestationの`iss`クレーム |
| `CLIENT_ID` | `https://wallet.ownd-project.com` | Client Attestationの`sub`クレーム、PoP JWTの`iss`クレーム |
| `WALLET_NAME` | `OWND Wallet` | Wallet名称（オプショナル） |
| `WALLET_LINK` | `https://www.ownd-project.com/wallet/` | Wallet情報URL（オプショナル） |
| `ATTESTATION_VALIDITY_SECONDS` | `86400` (24時間) | Client Attestationの有効期間 |
| `KEY_WALLET_ATTESTATION` | `walletAttestationKey` | Attestation用キーペアのエイリアス |

## Wallet Attestation Service API

```swift
// tw2023_wallet/Services/WalletAttestation/WalletAttestationService.swift
class WalletAttestationService {
    static let shared: WalletAttestationService

    /// Client Attestationが有効かチェック
    func isAttestationEnabled() -> Bool

    /// Client Attestation JWTを生成・保存（設定有効化時に呼び出し）
    func generateAndStoreClientAttestation() async throws

    /// 保存済みClient Attestation JWTを取得（期限切れの場合は再生成）
    func getClientAttestation() throws -> String

    /// Client Attestation PoP JWTを生成
    /// - Parameter audience: Authorization ServerのIssuer URL
    func generateClientAttestationPoP(audience: String) throws -> String
}
```

## 設定

| 設定 | 説明 | デフォルト |
|------|------|-----------|
| `use_client_attestation` | Client Attestationを使用 | OFF |

## 実装上の注意

- Wallet Provider秘密鍵・証明書はビルド時にバンドル（テスト用）
- Attestation鍵ペアはKeychain/Secure Enclaveに保存
- Client Attestationは有効期限管理あり（デフォルト24時間）
- 期限切れ時は自動再生成
