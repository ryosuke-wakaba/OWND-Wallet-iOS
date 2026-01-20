# コンポーネント

[← README](./README.md)

## TrustAnchorManager

証明書の読み込みと管理を行うシングルトンクラス。

**ファイル:** `tw2023_wallet/Signature/TrustAnchorManager.swift`

### 主な機能

| プロパティ/メソッド | 説明 |
|-------------------|------|
| `shared` | シングルトンインスタンス |
| `anchorCertificates` | ルートCA証明書の配列 |
| `intermediateCertificates` | 中間証明書の配列 |
| `hasCustomAnchors` | カスタムアンカーが設定されているか |
| `reload()` | バンドルから証明書を再読み込み |
| `clear()` | すべての証明書をクリア |

### 証明書の自動分類

証明書は内容に基づいて自動分類されます：

```swift
// 自己署名証明書（Issuer == Subject）→ ルートCA
// それ以外 → 中間証明書
private func isSelfSignedCertificate(_ certificate: SecCertificate) -> Bool {
    let issuer = SecCertificateCopyNormalizedIssuerSequence(certificate)
    let subject = SecCertificateCopyNormalizedSubjectSequence(certificate)
    return (issuer as Data) == (subject as Data)
}
```

---

## X509CertificateOperations

証明書チェーン検証のコアロジックを提供。

**ファイル:** `tw2023_wallet/Signature/X509CertificateOperations.swift`

### 証明書変換ヘルパー

証明書を`SecCertificate`に変換するためのヘルパーメソッド：

| メソッド | 入力型 | 説明 |
|---------|-------|------|
| `derDataToSecCertificates(_:)` | `[Data]` | DERデータ配列を変換 |
| `derDataToSecCertificates(_:)` | `[Data?]` | オプショナルDERデータ配列を変換（nilがあれば失敗） |
| `certificatesToSecCertificates(_:)` | `[Certificate]` | X509.Certificate配列を変換 |

```swift
// 使用例
let derCertificates: [Data] = ...
guard let secCerts = X509CertificateOperations.derDataToSecCertificates(derCertificates) else {
    // 変換失敗
    return
}
let isValid = try X509CertificateOperations.validateCertificateChainWithCustomAnchors(leafCertificates: secCerts)
```

### 検証メソッド

すべての証明書チェーン検証は `validateCertificateChainWithCustomAnchors` に統一されています。

#### validateCertificateChainWithCustomAnchors

```swift
// TrustAnchorManagerを使用した検証（標準）
static func validateCertificateChainWithCustomAnchors(
    leafCertificates: [SecCertificate],
    useCustomAnchorsOnly: Bool = false
) throws -> Bool
```

**特徴:**
- `TrustAnchorManager.shared`から中間証明書とルートCAを自動取得
- カスタムアンカーがない場合はシステムCAにフォールバック
- `useCustomAnchorsOnly: false`（デフォルト）でシステムCAも併用

#### validateTrust (内部メソッド)

```swift
private static func validateTrust(
    _ certificates: [SecCertificate],
    customAnchors: [SecCertificate]?,
    useCustomAnchorsOnly: Bool
) throws -> Bool
```

**特徴:**
- すべてのvalidate関数から呼び出される共通実装
- SecTrust APIを直接操作
- `customAnchors`がnilの場合はシステムCAのみで検証

### 使用パターン

```swift
// パターン1: DERデータから検証
let derCertificates: [Data?] = ...
if let secCerts = X509CertificateOperations.derDataToSecCertificates(derCertificates) {
    let isValid = try X509CertificateOperations.validateCertificateChainWithCustomAnchors(
        leafCertificates: secCerts
    )
}

// パターン2: X509.Certificateから検証
let certificates: [Certificate] = ...
if let secCerts = X509CertificateOperations.certificatesToSecCertificates(certificates) {
    let isValid = try X509CertificateOperations.validateCertificateChainWithCustomAnchors(
        leafCertificates: secCerts
    )
}
```

---

## TrustedListManager

ETSI TS 119 602 LoTE（List of Trusted Entities）形式のトラストリスト管理。証明書ベースの発行者検索を提供。

**ファイル:** `tw2023_wallet/Services/TrustedList/TrustedListManager.swift`

### 主なAPI

```swift
class TrustedListManager {
    static let shared = TrustedListManager()

    /// トラストリストをフェッチ (JSON/JWT両形式対応)
    func fetchTrustedList(from url: URL) async throws -> LoTEDocument

    /// リーフ証明書の発行者証明書をトラストリストから検索
    /// AKI/SKIマッチングを優先し、フォールバックとしてDNマッチングを使用
    func findIssuerCertificate(
        for leafCertificate: Certificate,
        searchInfos: [LoTEContextSearchInfo]
    ) async throws -> IssuerCertificateResult

    /// x5c証明書チェーンの発行者証明書を取得
    /// x5cの末尾証明書の発行者をトラストリストから検索
    func getIssuerCertificatesForChain(
        x5cCertificates: [Certificate],
        searchInfos: [LoTEContextSearchInfo]
    ) async throws -> [SecCertificate]
}
```

### 検索結果型

```swift
/// 発行者証明書検索結果
struct IssuerCertificateResult {
    let entity: TrustedEntity
    let service: TrustedEntityService
    let issuerCertificate: Certificate
    let matchMethod: MatchMethod
}

/// マッチング方法
enum MatchMethod {
    case akiSki           // AKI/SKIによるマッチング（優先）
    case distinguishedName // DNによるフォールバックマッチング
}
```

### TrustedListError

```swift
enum TrustedListError: Error {
    case noLoTEConfigured           // LoTE情報が指定されていない
    case invalidURL(String)
    case fetchFailed(URL, Error)
    case parseError(Error)
    case issuerCertificateNotFound  // 発行者証明書が見つからない
    case noCertificatesInService
    case certificateParseError
}
```

---

## X5CJWTVerifier

x5c/x5uヘッダーを使用したJWT検証のラッパー層。JWTOperationsとX509CertificateOperationsを統合して証明書チェーン検証を行う。

**ファイル:** `tw2023_wallet/Signature/X5CJWTVerifier.swift`

```swift
enum X5CJWTVerifier {
    typealias VerifiedX5CJwt = (decoded: JWT, certs: [Certificate])

    /// x5cヘッダーでJWTを検証 (署名検証 + 証明書チェーン検証)
    /// 証明書ベースの検索でトラストリストから発行者証明書を取得
    static func verifyJwtWithX5C(
        jwt: String,
        contextSearchInfos: [LoTEContextSearchInfo],
        verifyCertChain: Bool = true
    ) async -> Result<VerifiedX5CJwt, JWTVerificationError>

    /// x5uヘッダーでJWTを検証
    static func verifyJwtWithX5U(
        jwt: String
    ) -> Result<JWT, JWTVerificationError>
}
```
