# OWND Wallet iOS Documentation

OWND Wallet iOSの設計・開発・運用に関するドキュメントです。

## ドキュメント構成

### [Architecture](./architecture.md)
システム全体のアーキテクチャ設計

- システム概要と設計原則
- 3層アーキテクチャ（Presentation/Service/Data）
- セキュリティアーキテクチャ（鍵管理、暗号化、脅威モデル）
- システム図とフロー図

### [Development](./development.md)
開発者向けガイド

- セットアップ手順
- コーディング規約
- テスト戦略（Unit/Integration/UI）
- Git-Flow開発ワークフロー

### [Data Storage](./data-storage.md)
データモデルとストレージ設計

- データモデルスキーマ（Credential、履歴）
- CoreData/Protocol Buffers実装
- Keychainによる鍵管理
- データマイグレーション戦略

### Features（機能仕様）
各機能の詳細仕様書（実装前に更新）

- [Credential Issuance](./features/credential-issuance.md) - VC発行フロー（OID4VCI）
- [Credential Presentation](./features/credential-presentation.md) - VP提示フロー（OID4VP）
- [Authentication](./features/authentication.md) - SIOPv2認証
- [Credential Management](./features/credential-management.md) - クレデンシャル管理
- [Settings](./features/settings.md) - 設定機能

## ドキュメントファーストワークフロー

新機能や大きな変更を実装する際の推奨フロー：

### 1. 設計フェーズ（Draft）
- `docs/features/` に機能仕様を作成
- 関連する `docs/architecture.md` のセクションを更新
- ステータス: **Draft**

### 2. レビューフェーズ（Review）
- チームでドキュメントレビュー
- フィードバックを反映
- ステータス: **Review**

### 3. 承認フェーズ（Approved）
- ドキュメントを承認
- ステータス: **Approved**

### 4. 実装フェーズ（Implemented）
- コード実装
- 実装中に気づいた点をドキュメントに反映
- ステータス: **Implemented**

### 5. 検証フェーズ（Verified）
- テスト・検証完了
- ドキュメントを最終更新
- ステータス: **Verified**

## ドキュメントステータス

各機能ドキュメントには以下のステータスを記載：

- **Draft** - 設計中
- **Review** - レビュー中
- **Approved** - 承認済み
- **Implemented** - 実装済み
- **Verified** - 検証済み

## Quick Links

### 仕様・標準
- [W3C Verifiable Credentials](https://www.w3.org/TR/vc-data-model/)
- [OID4VCI 1.0 Final Specification](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html)
- [OID4VP Specification](https://openid.net/specs/openid-4-verifiable-presentations-1_0-18.html)
- [SIOPv2 Specification](https://openid.net/specs/openid-connect-self-issued-v2-1_0-13.html)
- [Presentation Exchange](https://identity.foundation/presentation-exchange/)

### 開発リソース
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [Apple Security Guide](https://support.apple.com/guide/security/)

### プロジェクト情報
- [OWND Project](https://github.com/OWND-Project)
- [Trusted Web](https://trustedweb.go.jp/)

## 貢献

ドキュメントの改善提案は常に歓迎します。プルリクエストを送る前に、[Development Guide](./development.md)のワークフローセクションを確認してください。
