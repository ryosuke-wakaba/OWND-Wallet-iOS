# 作業依頼
## 設計変更
### サービス特定方法の設計変更
- docs/features/credential-issuance/metadata-verification.md

こちらの機能に登場する`TrustedListManager`のサービス検索機能の仕様を変更します。


#### 実現したい振る舞い
- VCIのメタデータ取得時、ビューモデルからLoTEの情報を指定する
    - 具体的には`JPのトラストリストに含まれるOID4VCの発行サービス`という内容
- TrustedListManagerの検索条件にする使用するサービスタイプを外部から渡せる様にする
    - サービスタイプはオプショナル
    - 指定が無い場合はマッチ条件に含めない

#### 要件
- TrustedListURLs.txtを以下の様な構造を持てる様に変更

    設定ファイルのイメージ
    ```
    lotes:
      jp-lote:
          url: https://tl.eujp.ownd-project.com/api/trusted-list.jwt
          services:
              oid4vci:
                  identifier: http://tl.eujp.ownd-project.com/SvcType/OID4VCI/Issuance
              oid4vp:
                  identifier: http://tl.eujp.ownd-project.com/SvcType/OID4VP/Verification
              diw:
                  identifier: http://tl.eujp.ownd-project.com/SvcType/WalletSolution/WalletProvider
      eu-lote:
          url: https://tl.example.com/api/trusted-list.jwt
          services:
              oid4vci:
                  identifier: http://tl.example.com/SvcType/OID4VCI/Issuance
    ```
- `VCIMetadataClient`は複数のLoTEを受け付ける
    - 上記の設定ファイルの構造はウォレットに独自のものなので、そのドメイン知識はビューモデルまでが知っていることとし、`VCIMetadataClient`以降はURLとサービスリストのペアで情報を受け取る

#### その他
Service type identifierの仕様

```
6.6.1 Service type identifier
Description:
The ServiceTypeIdentifier component specifies the identifier of the service type.

Format:
The ServiceTypeIdentifier component shall be an indicator expressed as a URI.

Semantics:
The quoted URI shall be a URI value registered and described by the scheme operator or another entity.

LoTE profiles should define and register the URIs that may be used in accordance with that profile.

NOTE: Any organization can request an object identifier under the etsi-identified organization node or a URI root
as detailed on https://portal.etsi.org/PNNS.aspx. 
```

### 基本情報
- docs/architecture.md
- docs/development.md
- docs/features/credential-issuance

### ブランチ
- 現在のブランチで対応して下さい。

### 作業ドキュメント
対応内容がまとまったら、まずは進捗が把握できるように作業ドキュメントを作成して下さい。

作業ドキュメントのパスとファイル名の形式

- docs/work/yyyy-mm-dd-xxx.md
