# SD-JWT VP Token Disclosure検証エラー調査

## Status
- [x] 調査中
- [x] 原因特定 ← **2025-12-05 完了**
- [x] 修正実装 ← **2025-12-05 完了** (DCQLMatcher修正)
- [x] 検証完了 ← **2025-12-05 完了** (DCQLMatcherTests 14件全てpass)

## 問題概要

VP Token送信時にサーバーから `TypeMetadataValidationFailure` エラーが返される。

### エラーメッセージ
```
{
  "error": "InvalidVpToken",
  "description": "[{\"error\":\"TypeMetadataValidationFailure\",\"description\":\"sd-jwt vc could not be validated according to its type metadata, contains a claim that has not been properly disclosed at claim path [\\\"issuing_authority\\\"], contains a claim that has not been properly disclosed at claim path [\\\"issuing_country\\\"], contains a claim that has not been properly disclosed at claim path [\\\"date_of_issuance\\\"], contains a claim that has not been properly disclosed at claim path [\\\"achievement_title\\\"], contains a claim that has not been properly disclosed at claim path [\\\"achievement_description\\\"], contains a claim that has not been properly disclosed at claim path [\\\"date_of_expiry\\\"]\"}]"
}
```

### 症状
- 8つのdisclosureを選択しているが、サーバーは6つが「properly disclosed」されていないと報告
- **失敗するクレーム**: `issuing_authority`, `issuing_country`, `date_of_issuance`, `achievement_title`, `achievement_description`, `date_of_expiry`
- **成功するクレーム**: `family_name`, `given_name`

### 対象クレデンシャル
- VCT: `urn:eu.europa.ec.eudi:learning:credential:1`
- Format: `dc+sd-jwt`

## 調査結果

### 1. アプリ側のログ確認

```
[createVpTokenForSdJwtVc] Total discloseClaims: 8
[createVpTokenForSdJwtVc] Selected disclosures (isSubmit=true): 8
[createVpTokenForSdJwtVc] Disclosure[0]: key=issuing_authority
[createVpTokenForSdJwtVc] Disclosure[1]: key=issuing_country
[createVpTokenForSdJwtVc] Disclosure[2]: key=date_of_issuance
[createVpTokenForSdJwtVc] Disclosure[3]: key=family_name
[createVpTokenForSdJwtVc] Disclosure[4]: key=given_name
[createVpTokenForSdJwtVc] Disclosure[5]: key=achievement_title
[createVpTokenForSdJwtVc] Disclosure[6]: key=achievement_description
[createVpTokenForSdJwtVc] Disclosure[7]: key=date_of_expiry
```

アプリ側では8つのdisclosureが正しく選択されている。

### 2. 発見した問題: DCQL CodingKeys競合

**ファイル**: `tw2023_wallet/Services/OID/DCQL.swift:34-39`

```swift
struct DcqlCredentialMeta: Codable {
    let vctValues: [String]?

    enum CodingKeys: String, CodingKey {
        case vctValues = "vct_values"  // ← 問題箇所
    }
}
```

**原因**: 親デコーダー（`AuthRequest.swift:148`）が `keyDecodingStrategy = .convertFromSnakeCase` を使用しているため、`vct_values` が自動的に `vctValues` に変換される。その後 `CodingKeys` が `"vct_values"` を探すが、既に変換済みのため見つからず `nil` になる。

**証拠**: ログに `vctValues: nil` と出力されている
```
DcqlCredentialQuery(id: "query_0", format: "dc+sd-jwt", meta: Optional(tw2023_wallet.DcqlCredentialMeta(vctValues: nil)), ...)
```

**影響**: VCTによるクレデンシャルフィルタリングがスキップされる（直接の原因ではないが修正が必要）

### 3. 主要な問題仮説

サーバーエラーの本質は、VP Token内のdisclosureがSD-JWTの `_sd` 配列のハッシュと一致しないこと。

#### 仮説A: クレデンシャルのネスト構造
- 失敗する6クレームがネストされたオブジェクト内にある可能性
- 例: `achievement.title` → disclosure形式が異なる
- `family_name`/`given_name` はトップレベルで成功

#### 仮説B: Disclosure文字列の変換問題
- 保存/取得時の暗号化・復号化で文字列が変わっている可能性
- `EncryptionHelper` の処理を確認必要

#### 仮説C: SD-JWT構造の不一致
- クレデンシャル発行時の構造と、アプリが期待する構造が異なる
- Type Metadataが特定のdisclosure形式を期待

## コードフロー分析

### VP Token生成フロー

```
1. SharingRequest.selectCredential()
   ↓
2. SharingRequestViewModel.classifyClaims()
   - DCQLMatcher.matchCredential() でdisclosureを取得
   ↓
3. SharingRequestViewModel.createSubmissionCredential()
   - SubmissionCredential作成
   ↓
4. OpenIdProvider.respondToken()
   ↓
5. SubmissionCredential.createVpTokenForSdJwtVc()
   - selectedDisclosures.filter { $0.isSubmit }
   - vpToken = issuerSignedJwt + "~" + disclosures.joined("~") + "~" + kbJwt
   ↓
6. sendFormData() → JWE暗号化 → POST
```

### 関連ファイル

| ファイル | 役割 |
|---------|------|
| `Services/OID/Provider/ProviderTypes.swift` | `SubmissionCredential.createVpTokenForSdJwtVc()` |
| `Services/OID/DCQLMatcher.swift` | クレデンシャルマッチング、disclosure抽出 |
| `Services/OID/DCQL.swift` | DCQL型定義 |
| `Utils/SDJwtUtil.swift` | SD-JWT解析、disclosure抽出 |
| `Services/OID/KeyBindingImpl.swift` | KB-JWT生成、sd_hash計算 |
| `datastore/CredentialDataManager.swift` | クレデンシャル保存・取得 |

## 次のステップ

### TODO
- [x] 1. デバッグログ追加（2025-12-05完了）
- [ ] 2. DCQL CodingKeys競合の修正
- [ ] 3. ログ出力を確認して原因特定
- [ ] 4. 成功するクレーム(family_name)と失敗するクレームの違いを特定
- [ ] 5. 修正実装

## 追加したデバッグログ

### 変更ファイル
1. `tw2023_wallet/Services/OID/Provider/ProviderTypes.swift`
2. `tw2023_wallet/Utils/SDJwtUtil.swift`

### 出力内容
次回実行時に以下の情報がログ出力されます：

```
[SDJwtUtil] ===== SD-JWT Structure Analysis =====
[SDJwtUtil] _sd array contains N hashes:
[SDJwtUtil] _sd[0]: <hash1>
[SDJwtUtil] _sd[1]: <hash2>
...
[SDJwtUtil] _sd_alg: sha-256
[SDJwtUtil] ========================================

[createVpTokenForSdJwtVc] ===== DEBUG: Original Credential Analysis =====
[createVpTokenForSdJwtVc] Credential parts count: N
[createVpTokenForSdJwtVc] Original disclosures in credential: N
[createVpTokenForSdJwtVc] OriginalDisclosure[0]: key=xxx, hash=<calculated_hash>
...

[createVpTokenForSdJwtVc] ===== DEBUG: Selected Disclosures =====
[createVpTokenForSdJwtVc] Total discloseClaims: N
[createVpTokenForSdJwtVc] Selected disclosures (isSubmit=true): N
[createVpTokenForSdJwtVc] Disclosure[0]: key=xxx, base64url=...
[createVpTokenForSdJwtVc] Disclosure[0]: sha256_hash=<calculated_hash>
...
```

### 確認ポイント
1. `_sd`配列のハッシュ値と、各disclosureの計算されたハッシュ値が一致するか
2. 成功するクレーム（family_name, given_name）と失敗するクレームのハッシュに違いがあるか
3. `OriginalDisclosure`と`Selected Disclosure`のハッシュが同一か

## 原因特定（2025-12-05）

### サーバー側の設定を発見

**ファイル**: `eudi-web-verifier/src/app/core/constants/attestation-definitions.ts`

```typescript
export const LEARNING_CREDENTIAL_ATTESTATION: AttestationDefinition = {
  name: "Learning Credential",
  type: AttestationType.LEARNING_CREDENTIAL,
  dataSet: [
    {identifier: "issuing_authority", selectivelyDisclosable: "never"},     // ❌ 失敗
    {identifier: "issuing_country", selectivelyDisclosable: "never"},       // ❌ 失敗
    {identifier: "date_of_issuance", selectivelyDisclosable: "never"},      // ❌ 失敗
    {identifier: 'date_of_expiry', selectivelyDisclosable: "never"},        // ❌ 失敗
    {identifier: "family_name"},                                             // ✅ 成功
    {identifier: "given_name"},                                              // ✅ 成功
    {identifier: "achievement_title", selectivelyDisclosable: "never"},     // ❌ 失敗
    {identifier: "achievement_description", selectivelyDisclosable: "never"},// ❌ 失敗
  ]
}
```

### 検証結果の完全一致

| クレーム | `selectivelyDisclosable` | 検証結果 |
|---------|-------------------------|---------|
| issuing_authority | `"never"` | ❌ 失敗 |
| issuing_country | `"never"` | ❌ 失敗 |
| date_of_issuance | `"never"` | ❌ 失敗 |
| date_of_expiry | `"never"` | ❌ 失敗 |
| **family_name** | **なし** | ✅ **成功** |
| **given_name** | **なし** | ✅ **成功** |
| achievement_title | `"never"` | ❌ 失敗 |
| achievement_description | `"never"` | ❌ 失敗 |

**`selectivelyDisclosable: "never"` のクレームのみが失敗している！**

### 根本原因の仮説

**SD-JWT VC Type Metadata仕様**によると、`selectivelyDisclosable: "never"` のクレームは：
- JWTペイロードに**直接**含まれるべき（`_sd`配列経由ではなく）
- disclosureとして送信すべきではない

**現状の問題**:
1. クレデンシャル発行時に、すべてのクレームが`_sd`配列（selective disclosure）として発行された
2. ウォレットはこれらをdisclosureとして送信
3. サーバーのType Metadata検証が「これらはdisclosureではなく直接含まれるべき」と判断して失敗

### 解決策の選択肢

#### オプション1: クレデンシャル発行者側の修正（推奨）
クレデンシャル発行時に、`selectivelyDisclosable: "never"` のクレームをJWTペイロードに直接含める（`_sd`配列に入れない）

#### オプション2: サーバー側の設定変更
`attestation-definitions.ts` で `selectivelyDisclosable: "never"` を削除し、通常のselectively disclosableとして扱う

#### オプション3: サーバー側のType Metadata検証を緩和
バックエンドの検証ロジックで、Type Metadata検証をスキップまたは緩和する

## 追加対応: DCQLMatcher修正（2025-12-05）

### 新しい問題

発行サービスを修正後、`selectivelyDisclosable: "never"`のクレームがJWTペイロードに直接含まれるようになった。
しかし、`DCQLMatcher`はdisclosure（`_sd`経由）のみを検索しているため、ペイロード直接のクレームを見つけられない。

```
[DCQLMatcher] Required claims: ["achievement_description", "achievement_title", ...]
[DCQLMatcher] Claims matching failed - missing claims: ["achievement_description", ...]
```

### 修正内容

**ファイル**: `tw2023_wallet/Services/OID/DCQLMatcher.swift`

`matchCredential`関数を修正して：
1. JWTペイロードから直接クレームを抽出
2. disclosureベースのクレームとマージ
3. 両方を検索対象にする

```swift
// 修正前: disclosureのみを検索
let allDisclosures = SDJwtUtil.decodeDisclosure(sdJwtParts.disclosures)
let sourcePayload = Dictionary(uniqueKeysWithValues: allDisclosures.compactMap { ... })

// 修正後: disclosures + JWTペイロード直接のクレームを検索
let allDisclosures = SDJwtUtil.decodeDisclosure(sdJwtParts.disclosures)
var sourcePayload = Dictionary(uniqueKeysWithValues: allDisclosures.compactMap { ... })

// JWTペイロードから直接クレームを抽出
if let jwtPayload = try? getJwtPayload(sdJwtParts.issuerSignedJwt) {
    for (key, value) in jwtPayload {
        // 予約済みクレーム（iss, exp, vct, _sd等）をスキップ
        guard !reservedJwtClaims.contains(key) else { continue }
        // disclosureに存在しないクレームのみ追加
        if sourcePayload[key] == nil {
            sourcePayload[key] = stringValue
        }
    }
}
```

### 予約済みJWTクレーム（検索対象外）

```swift
private static let reservedJwtClaims: Set<String> = [
    "iss", "sub", "aud", "exp", "nbf", "iat", "jti",  // 標準JWTクレーム
    "vct", "cnf", "_sd", "_sd_alg", "status"           // SD-JWT固有クレーム
]
```

### VP Token生成時の考慮事項

JWTペイロードに直接含まれるクレームは：
- VP Tokenに含める必要はない（既にIssuer JWTに含まれている）
- disclosureとして送信しない
- `isSubmit: false`として扱う

## 参考資料

- [SD-JWT Specification](https://datatracker.ietf.org/doc/draft-ietf-oauth-selective-disclosure-jwt/)
- [OID4VP 1.0 Specification](https://openid.net/specs/openid-4-verifiable-presentations-1_0.html)
- `docs/features/credential-presentation.md`
