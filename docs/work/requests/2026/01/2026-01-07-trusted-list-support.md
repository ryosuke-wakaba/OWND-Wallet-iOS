# 作業依頼
## 機能追加
### カスタムトラストアンカー機能の拡張

TrustAnchorManagerに、起動時でなく使い捨てのインスタンスを生成して証明書を読み込ませるパターンを追加します。(もっと良い設計案があれば提案して下さい)

証明書はETSI TS 119 602で策定されているLoTE(ここではt`rusted-list.json`ファイル)に含まれます。

#### 実現したい振る舞い
1. **サービスのURLを取得:**
OID4VCIでは、発行者の識別子（Issuer Identifier）として `https://issuer.example.com` のようなURLが使われます
2. **リスト内を検索:**
取得した `trusted-list.json` をパースし、以下の条件に合致するサービスエントリ（Trusted Entity Service）を探します。
    * **Service Type:** 「発行サービス」であることを確認（例: `http://example.com/SvcType/CredentialIssuance`）。
    * ServiceSupplyPoints: このフィールドに、発行者のURL（`https://issuer.example.com`）が含まれているか確認します。

3. **公開鍵の取得:**
マッチしたエントリの `Service Digital Identity` フィールドから証明書（または公開鍵）を取り出します。
4. **検証:**
取り出した鍵を使って、発行者から送られてきた署名（Signed Metadata や JWS）を検証します。

#### 要件
- ビルド時に`rusted-list.json`ファイルを取得するためのURLのリストを読み込み、トラストリストの場所をウォレットに記憶する
    - URLの指定方法は特に指定しないが、コミット対象外のテキストファイルなどにリストしておくような方式が望ましい
- TrustAnchorManagerがそのURLを元に証明書チェーンを組み立てる

#### その他
- サンプルデータは`./trustedlist.json`を参照
- LoTEの規格は[こちら](https://www.etsi.org/deliver/etsi_ts/119600_119699/119602/01.01.01_60/ts_119602v010101p.pdf)

## 参考
- docs/x509-certificate-chain-validation.md
- docs/work/2025-11-26-work-x509-custom-trust.md
- docs/architecture.md
- docs/development.md