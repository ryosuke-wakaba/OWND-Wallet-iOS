# 作業依頼
## 設定画面の変更

「サーバー認証を要求する」設定はプレデンテーション時も使用しているので、発行設定のセクションに属していることは適切ではありません。

また、トラストリストセクションの「トラストリストを使用する」設定ですが、「サーバー認証を要求する」設定と役割が重複しているので削除してください。代わりに「サーバー認証を要求する」設定をこちらに配置してください。


### 基本情報
- docs/architecture.md
- docs/development.md
- docs/features/credential-issuance
- docs/features/credential-presentation
- docs/features/settings
- docs/data-storage.md

### ブランチ
- 新しいブランチで対応して下さい。
    - 派生元ブランチ: 現在のブランチ

### 作業ドキュメント
対応内容がまとまったら、まずは進捗が把握できるように作業ドキュメントを作成して下さい。

作業ドキュメントのパスとファイル名の形式

- docs/work/yyyy-mm-dd-xxx.md