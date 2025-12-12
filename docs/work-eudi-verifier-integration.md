# EUDI Verifier 連携対応

## 日付
2025-12-03

## 概要

EUDI Wallet Reference Implementation の Verifier との OID4VP 連携を実現するための対応。

## 対応内容

### 1. eudi-openid4vp カスタムスキーム対応

**コミット**: `fab9145`

EUDI Verifier が使用する `eudi-openid4vp://` カスタムスキームをサポート。

**変更ファイル**:
- `tw2023-wallet-Info.plist`: スキーム登録
- `tw2023_walletApp.swift`: Deep Link 処理追加
- `QRReaderViewModel.swift`: QRコード判定追加

### 2. vp_formats_supported 型修正

**コミット**: `b704e09`

OID4VP 1.0 仕様に準拠するよう `client_metadata.vp_formats_supported` の型を修正。

**問題**:
- `vp_formats_supported` が `Format` (String enum) として定義されていたが、仕様ではオブジェクト型

**修正**:
- `VpFormatAlgorithms` 構造体を追加
- `vpFormatsSupported` の型を `[String: VpFormatAlgorithms]?` に変更
- 非標準の `vpFormats` プロパティを削除

**変更ファイル**:
- `tw2023_wallet/Services/OID/VCI/AuthRequest.swift`

### 3. DCQLマッチング デバッグログ追加

**コミット**: `70366ef`

クレデンシャルがボトムシートに表示されない問題を調査するためのデバッグログを追加。

**調査結果**:
- クレデンシャルに `date_of_expiry` クレームが含まれていなかったため、DCQLクエリとマッチしなかった
- 有効期限を含むクレデンシャルを発行することで解決

**追加ログ**:
- `[loadFilteredCredentials]`: クレデンシャル読み込み時の情報
- `[DCQLMatcher]`: マッチング処理の詳細（VCT、利用可能クレーム、不足クレーム）

**変更ファイル**:
- `tw2023_wallet/Services/OID/DCQLMatcher.swift`
- `tw2023_wallet/Feature/ShareCredential/ViewModels/SharingRequestViewModel.swift`

### 4. VP Token 送信時のデバッグログ追加

VP Token 送信時に 400 エラーが発生する問題を調査するためのデバッグログを追加。

**追加ログ** (`[sendFormData]`):
- リクエスト URL、メソッド、ヘッダー、ボディ
- レスポンス ステータスコード、ヘッダー、ボディ

**変更ファイル**:
- `tw2023_wallet/Services/OID/Provider/ProviderUtils.swift`

### 5. direct_post.jwt の state 処理修正

**問題**:
```
{"error":"IncorrectState","description":"Wallet responded with a 'state' that does not match the expected one."}
```

**原因**:
- `direct_post.jwt` (暗号化レスポンス) では、`state` は JWE ペイロード内に含める必要がある
- 従来の実装では `state` をボディに別パラメータとして送信していた

**仕様** (OID4VP):
```
POST /post HTTP/1.1
Host: client.example.org
Content-Type: application/x-www-form-urlencoded

response=eyJra...9t2LQ
```
- ボディには `response=<JWE>` のみ
- `state` は JWE ペイロード内に含める

**修正**:
- `state` を `encryptPayload` に追加
- ボディから `state` パラメータを除外

**変更ファイル**:
- `tw2023_wallet/Services/OID/Provider/ProviderUtils.swift`

## 未コミットの変更

- VP Token 送信時のデバッグログ
- direct_post.jwt の state 処理修正

## EUDI 証明書

EUDI dev 環境の証明書を抽出し、以下に保存:
- `/Users/ryousuke/repositories/ownd/ipa2025/TrustAnchors/eudi-dev-issuer.cer`
- `/Users/ryousuke/repositories/ownd/ipa2025/TrustAnchors/eudi-dev-verifier.cer`
- `/Users/ryousuke/repositories/ownd/ipa2025/TrustAnchors/eudi-root-ca.cer`

## 参考

- [OID4VP 1.0 Specification](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html)
- EUDI Verifier: https://dev.verifier.eudiw.dev/home
