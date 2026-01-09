# 作業依頼
## リファクタリング
JWTUtilのSignatureUtilへの依存を無くしてください。

JWTの検証の際、現在はx5cの場合にはJWT検証の前にX509証明書の証明書チェーンの検証の呼び出しも行っていますが、責務としてはシンプルにJWTの検証だけに変更したいです。
そこでこの二つのラッパー層を設けて、依存関係を整理してください。

### 基本情報
- docs/architecture.md
- docs/development.md
- docs/features/credential-issuance
- docs/features/credential-presentation
- docs/x509-certificate-chain-validation.md

### ブランチ
- 現在のブランチで対応して下さい。

### 作業ドキュメント
対応内容がまとまったら、まずは進捗が把握できるように作業ドキュメントを作成して下さい。

