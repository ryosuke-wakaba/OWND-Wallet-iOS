# OID4VP 1.0 移行作業ドキュメント - Wallet iOS

## 概要

OpenID for Verifiable Presentations 1.0 では、以下の主要な仕様変更があります。

### 主な変更点

1. **Presentation Definition の廃止 → DCQL への移行**
   - `presentationDefinition` / `presentationDefinitionUri` が不要に
   - `InputDescriptor` が不要に
   - Request Object に `dcql_query` プロパティを追加

2. **Presentation Submission の廃止**
   - レスポンスは `vp_token` のみ
   - `descriptor_map` を使った処理が不要に

3. **Client Identifier Prefix の導入**
   - `client_id_scheme` パラメータが廃止
   - `client_id` にプレフィックスを含める方式に変更
   - 対応プレフィックス:
     - `redirect_uri:` - Redirect URI/Response URIベース（署名不可）
     - `x509_san_dns:` - X.509証明書のSAN DNS名ベース（署名必須）
     - `x509_hash:` - X.509証明書のSHA-256ハッシュベース（署名必須）

4. **haip-vp:// スキームの追加**
   - HAIP (High Assurance Interoperability Profile) 対応
   - `openid4vp://` に加えて `haip-vp://` スキームをサポート

## 移行手順

### Phase 1: DCQL 型定義の追加

**対象ファイル**: 新規 `tw2023_wallet/Services/OID/DCQL.swift`

**作業内容**:
- [ ] `DcqlQuery` 構造体を追加
- [ ] `DcqlCredentialQuery` 構造体を追加
- [ ] `DcqlClaimQuery` 構造体を追加

**DCQL 型定義**:
```swift
struct DcqlClaimQuery: Codable {
    let path: [String]
    let values: [AnyCodable]?
}

struct DcqlCredentialQuery: Codable {
    let id: String
    let format: String
    let meta: DcqlCredentialMeta?
    let claims: [DcqlClaimQuery]?
}

struct DcqlCredentialMeta: Codable {
    let vctValues: [String]?
    // 他のメタデータフィールド
}

struct DcqlQuery: Codable {
    let credentials: [DcqlCredentialQuery]
}
```

---

### Phase 2: Request Object への DCQL Query 対応

**対象ファイル**:
- `tw2023_wallet/Services/OID/VCI/AuthRequest.swift`
- `tw2023_wallet/Services/OID/AuthorizationRequest.swift`

**作業内容**:
- [ ] `AuthorizationRequestCommonPayload` に `dcqlQuery` プロパティを追加
- [ ] `RequestObjectPayload` に `dcqlQuery` プロパティを追加
- [ ] `processDcqlQuery()` 関数を追加
- [ ] `presentationDefinition` / `presentationDefinitionUri` を削除

---

### Phase 3: Credential Matching の更新

**対象ファイル**: 新規または既存の `tw2023_wallet/Services/OID/DCQLMatcher.swift`

**作業内容**:
- [ ] `DcqlCredentialQuery` に基づくCredential照合ロジックを実装
- [ ] `vct_values` によるフィルタリング
- [ ] `claims` によるフィルタリング

**実装案**:
```swift
class DCQLMatcher {
    func matchCredentials(
        query: DcqlQuery,
        credentials: [Credential]
    ) -> [MatchedCredential]

    func matchCredential(
        credentialQuery: DcqlCredentialQuery,
        credential: Credential
    ) -> MatchResult?
}
```

---

### Phase 4: OpenIdProvider の更新

**対象ファイル**: `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift`

**作業内容**:
- [ ] `presentationDefinition` を `dcqlQuery` に置き換え
- [ ] `processAuthRequest()` で DCQL Query をパース
- [ ] Credential照合ロジックを更新（DCQL対応）

**変更箇所**:
```swift
class OpenIdProvider {
    // presentationDefinition を dcqlQuery に置き換え
    var dcqlQuery: DcqlQuery?
}
```

---

### Phase 5: VP Response の更新（Presentation Submission 廃止）

**対象ファイル**: `tw2023_wallet/Services/OID/Provider/OpenIdProvider.swift`

**作業内容**:
- [x] `respondToken()` から `presentation_submission` 生成を削除
- [x] `vp_token` のみを送信するように変更
- [x] レスポンスボディの構造を更新
- [x] vp_token の形式を DCQL credential ID ベースに変更

**変更前**:
```swift
// Response body に presentation_submission を含む
let body = [
    "vp_token": vpToken,
    "presentation_submission": presentationSubmission
]
```

**変更後**:
```swift
// vp_token は DCQL credential ID をキーとするオブジェクト形式
// 例: {"learning_credential": ["eyJhbGci...QMA"]}
let body = [
    "vp_token": "{\"credential_id\": [\"token\"]}"
]
```

**vp_token の形式**:
- キー: DCQL クエリで指定された `credentials[].id`
- 値: VP トークンの配列（通常は1つ）

```json
{
  "learning_credential": ["eyJhbGciOiJFUzI1NiIs..."]
}
```

---

### Phase 6: ProcessedRequestData の更新

**対象ファイル**: `tw2023_wallet/Services/OID/AuthorizationRequest.swift`

**作業内容**:
- [ ] `ProcessedRequestData` の `presentationDefinition` を `dcqlQuery` に置き換え
- [ ] `parseAndResolve()` で DCQL Query を処理

```swift
struct ProcessedRequestData {
    // presentationDefinition を dcqlQuery に置き換え
    var dcqlQuery: DcqlQuery?
}
```

---

### Phase 7: UI/ViewModel の更新

**対象ファイル**:
- `tw2023_wallet/Feature/ShareCredential/` 配下

**作業内容**:
- [ ] Credential選択画面で DCQL Query を使用
- [ ] マッチングロジックの更新
- [ ] 表示項目の更新（必要に応じて）

---

### Phase 8: テストの修正

**対象ファイル**: `tw2023_walletTests/` 配下

**作業内容**:
- [ ] DCQL Query パースのテスト追加
- [ ] Credential照合テストの更新
- [ ] VP生成テストの更新（Presentation Submission なし）

---

### Phase 9: 旧コードの削除

**対象ファイル**: `tw2023_wallet/Services/OID/PresentationExchange.swift`

**作業内容**:
- [ ] `PresentationDefinition` 関連コードを削除
- [ ] `InputDescriptor` 関連コードを削除
- [ ] `PresentationSubmission` 関連コードを削除
- [ ] 不要になったファイル全体の削除（必要に応じて）

---

### Phase 10: Client Identifier Prefix 対応

**対象ファイル**:
- `tw2023_wallet/Services/OID/VCI/AuthRequest.swift`
- `tw2023_wallet/Services/OID/AuthorizationRequest.swift`

**作業内容**:
- [ ] `client_id_scheme` プロパティを非推奨化（後方互換性不要の場合は削除）
- [ ] Client ID からプレフィックスを抽出するユーティリティ関数を追加
- [ ] `x509_*` プレフィックスの場合、`client_metadata` をオプショナルに
- [ ] Request Object の署名検証時に `x5c` ヘッダーを使用

**Client Identifier Prefix 種別**:

| Prefix | 説明 | 署名要否 | client_metadata |
|--------|------|----------|-----------------|
| `redirect_uri:` | Redirect URI/Response URIベース | 不可 | 必須 |
| `x509_san_dns:` | X.509証明書のSAN DNS名ベース | 必須 | オプション |
| `x509_hash:` | X.509証明書のSHA-256ハッシュベース | 必須 | オプション |

**実装例**:
```swift
/// Client IDからプレフィックスを抽出
func parseClientIdPrefix(_ clientId: String) -> (prefix: String, value: String)? {
    let prefixes = ["redirect_uri:", "x509_san_dns:", "x509_hash:"]
    for prefix in prefixes {
        if clientId.hasPrefix(prefix) {
            let value = String(clientId.dropFirst(prefix.count))
            return (String(prefix.dropLast()), value)
        }
    }
    return nil
}

/// x509スキームかどうかを判定
func isX509Scheme(_ clientId: String) -> Bool {
    return clientId.hasPrefix("x509")
}
```

**processClientMetadata の変更**:
```swift
func processClientMetadata(...) async throws -> RPRegistrationMetadataPayload {
    let clientIdScheme = requestObject?.clientIdScheme ?? authorizationRequest.clientIdScheme
    let clientId = requestObject?.clientId ?? authorizationRequest.clientId

    // x509スキームの場合はclient_metadataはオプション
    let isX509Scheme = clientIdScheme?.hasPrefix("x509") == true
                    || clientId?.hasPrefix("x509") == true

    // ... 既存ロジック

    if isX509Scheme {
        // client_metadataがなくても空のメタデータを返す
        return RPRegistrationMetadataPayload()
    }
    throw AuthorizationError.invalidClientMetadata
}
```

---

### Phase 11: haip-vp:// スキーム対応

**対象ファイル**:
- `tw2023-wallet-Info.plist`
- `tw2023_wallet/tw2023_walletApp.swift`
- `tw2023_wallet/Feature/QRReaders/ViewModels/QRReaderViewModel.swift`

**作業内容**:
- [ ] Info.plist に `haip-vp` URL スキームを登録
- [ ] `handleIncomingURL()` で `haip-vp` スキームを処理
- [ ] QRコードスキャン時に `haip-vp://` を認識

**Info.plist の変更**:
```xml
<dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLName</key>
    <string>com.ownd-project</string>
    <key>CFBundleURLSchemes</key>
    <array>
        <string>haip-vp</string>
    </array>
</dict>
```

**tw2023_walletApp.swift の変更**:
```swift
private func handleIncomingURL(_ url: URL) {
    if url.scheme == "openid4vp" || url.scheme == "haip-vp" {
        handleVp(url)
    }
    // ...
}
```

**QRReaderViewModel.swift の変更**:
```swift
func onFoundQrCode(_ code: String) {
    if code.starts(with: "openid4vp://") || code.starts(with: "haip-vp://") {
        // VP フロー開始
    }
}
```

---

## 進捗管理

| Phase | タスク | ステータス | 完了日 |
|-------|--------|-----------|--------|
| 1 | DCQL 型定義の追加 | ✅ 完了 | 2025-11-21 |
| 2 | Request Object への DCQL 対応 | ✅ 完了 | 2025-11-21 |
| 3 | Credential Matching の更新 | ✅ 完了 | 2025-11-21 |
| 4 | OpenIdProvider の更新 | ✅ 完了 | 2025-11-21 |
| 5 | VP Response の更新 | ✅ 完了 | 2025-11-21 |
| 6 | ProcessedRequestData の更新 | ✅ 完了 | 2025-11-21 |
| 7 | UI/ViewModel の更新 | ✅ 完了 | 2025-11-21 |
| 8 | テストの修正 | ✅ 完了 | 2025-11-21 |
| 9 | 旧コードの削除 | ✅ 完了 | 2025-11-21 |
| 10 | Client Identifier Prefix 対応 | ✅ 完了 | 2025-11-21 |
| 11 | haip-vp:// スキーム対応 | ✅ 完了 | 2025-11-21 |

## 注意事項

- 各 Phase は依存関係があるため、順番に実施すること
- Phase 1-6 は基盤部分、Phase 7 はUI層
- 旧コード（PEX関連）は完全に削除する
- テストは各 Phase 完了後にこまめに実行すること

## 参考資料

- [OpenID for Verifiable Presentations 1.0](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html)
- [DCQL Specification](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#name-digital-credentials-query-l)
- [Client Identifier Prefix Specification](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html#section-5.9)
- Verifier側移行ドキュメント:
  - PEX→DCQL: `/Users/ryousuke/repositories/ownd/ipa2025/OWND-Project-VP/docs/archive/migration-pex-to-dcql.md`
  - Client ID Prefix: `/Users/ryousuke/repositories/ownd/ipa2025/OWND-Project-VP/docs/archive/oid4vp-client-id-prefix-migration.md`
