# OpenIdProviderTests.swift

**パス**: `tw2023_walletTests/OpenIdProviderTests.swift`

**対応実装**: `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift`

**概要**: OpenID Provider（VP提示側）の動作をテストします。

> **Note**: PEXテストは削除済み（DCQLへ移行）

---

## テストクラス: ConvertVpTokenResponseResponseTests

VP Token送信後のレスポンス処理をテストします。

| テストメソッド | 説明 | 検証内容 |
|--------------|------|---------|
| `testConvertVpTokenResponseResponse_withValid200JSONResponse` | 200 OK + redirect_uri (JSON) | JSONボディのredirect_uriからリダイレクト先を取得すること |
| `testConvertVpTokenResponseResponse_withInvalid200JSONResponse` | 200 OK（redirect_uri欠落） | redirect_uriがない場合locationがnilになること |

---

## OID4VP仕様との整合性

OID4VP 1.0 Section 7.2では、Verifierからのレスポンスは以下の形式が規定されています：

```http
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: no-store

{
  "redirect_uri": "https://client.example.org/cb#response_code=091535f699ea575c7937fa5f0f454aee"
}
```

実装およびテストはこの仕様に準拠しています。
