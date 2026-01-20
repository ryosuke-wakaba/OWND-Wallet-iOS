# Credential Issuance - Metadata Verification

## Overview

OID4VCI 1.0 Section 12.2.2/12.2.3に準拠したメタデータの取得と検証機能を提供します。Issuerメタデータの信頼性を検証するため、署名付きメタデータ(Signed Metadata)とトラストリスト(ETSI TS 119 602 LoTE形式)に対応しています。

### 主な機能

| 機能 | 説明 | 仕様 |
|------|------|------|
| Signed Metadata | 署名付きメタデータの検証 | OID4VCI 1.0 Section 12.2.3 |
| Accept Header制御 | 署名付き/JSONメタデータの選択 | OID4VCI 1.0 Section 12.2.2 |
| Trust List | トラストリストからの証明書取得 | ETSI TS 119 602 |

### 対応状況

- ✅ 署名方式: x5c (証明書チェーン)
- ⏳ 署名方式: kid (未サポート)
- ⏳ 署名方式: trust_chain (未サポート)

## Class Diagram

```mermaid
classDiagram
    %% Configuration Layer
    class TrustedListConfigLoader {
        <<enum>>
        +loadConfig() TrustedListConfig?
        +createContextSearchInfos(contextName) [LoTEContextSearchInfo]
    }

    class TrustedListConfig {
        +lotes: [String: LoTEConfig]
    }

    class LoTEContextSearchInfo {
        +url: URL
        +contextName: String
        +condition: SearchCondition
    }

    class SearchCondition {
        +loteType: String?
        +serviceTypeIdentifier: String?
        +status: String?
    }

    %% Metadata Layer
    class VCIMetadataClient {
        <<Module>>
        +fetchCredentialIssuerMetadata(url, issuerIdentifier, preferSignedMetadata, contextSearchInfos) CredentialIssuerMetadata
        +retrieveAllMetadata(issuer, preferSignedMetadata, contextSearchInfos) Metadata
    }

    class SignedMetadataValidator {
        <<enum>>
        +validate(jwt, expectedIssuerIdentifier, contextSearchInfos) async Result~SignedMetadataValidationResult~
        +extractMetadataJson(payload) Data
    }

    class SignedMetadataValidationResult {
        +payload: [String: Any]
        +issuer: String?
        +subject: String
        +issuedAt: Date
        +expiresAt: Date?
    }

    %% Trust List Layer
    class TrustedListManager {
        <<Singleton>>
        +shared: TrustedListManager
        +fetchTrustedList(url) async LoTEDocument
        +findIssuerCertificate(for leafCertificate, searchInfos) async IssuerCertificateResult
        +getIssuerCertificatesForChain(x5cCertificates, searchInfos) async [SecCertificate]
    }

    class TrustedListModels {
        <<Module>>
    }

    class LoTEDocument {
        +LoTE: LoTE
    }

    class IssuerCertificateResult {
        +entity: TrustedEntity
        +service: TrustedEntityService
        +issuerCertificate: Certificate
        +matchMethod: MatchMethod
    }

    %% Certificate Validation Layer
    class TrustAnchorManager {
        <<Singleton>>
        +shared: TrustAnchorManager
        +anchorCertificates: [SecCertificate]
        +intermediateCertificates: [SecCertificate]
        +createInstance(withAdditionalCertificates) TrustAnchorManager
    }

    class X5CJWTVerifier {
        <<enum>>
        +verifyJwtWithX5C(jwt, contextSearchInfos, verifyCertChain) async Result~VerifiedX5CJwt~
        +verifyJwtWithX5U(jwt) Result~JWT~
    }

    class JWTOperations {
        <<enum>>
        +sign(keyAlias, header, payload) Result~String~
        +verifyJwt(jwt, publicKey) Result~JWT~
        +decodeJwt(jwt) tuple
        +decodeJwtWithX5C(jwt) Result~tuple~
        +decodeJwtWithX5U(jwt) Result~tuple~
    }

    class X509CertificateOperations {
        <<enum>>
        +validateCertificateChainWithCustomAnchors(certificates) Result~Void~
        +validateCertificateChainWithCustomAnchors(certificates, trustAnchorManager) Result~Void~
        +convertPemToX509Certificates(pemChain) [Certificate]
    }

    %% Relationships
    TrustedListConfigLoader ..> TrustedListConfig : loads
    TrustedListConfigLoader ..> LoTEContextSearchInfo : creates
    LoTEContextSearchInfo --> SearchCondition : contains

    VCIMetadataClient --> SignedMetadataValidator : uses
    SignedMetadataValidator --> X5CJWTVerifier : uses
    SignedMetadataValidator ..> SignedMetadataValidationResult : creates

    X5CJWTVerifier --> JWTOperations : uses (decode, verify)
    X5CJWTVerifier --> X509CertificateOperations : uses (chain validation)
    X5CJWTVerifier --> TrustAnchorManager : uses
    X5CJWTVerifier --> TrustedListManager : uses (get issuer certificates)

    X509CertificateOperations --> TrustAnchorManager : uses

    TrustedListManager --> TrustedListModels : uses
    TrustedListManager ..> LoTEDocument : fetches
    TrustedListManager ..> IssuerCertificateResult : returns
```

## Sequence Diagram

### メタデータ取得フロー (Signed Metadata)

```mermaid
sequenceDiagram
    participant App as Application
    participant CFG as TrustedListConfigLoader
    participant VMC as VCIMetadataClient
    participant SMV as SignedMetadataValidator
    participant X5C as X5CJWTVerifier
    participant JWT as JWTOperations
    participant SIG as X509CertificateOperations
    participant TAM as TrustAnchorManager
    participant TLM as TrustedListManager
    participant Issuer as Credential Issuer
    participant TL as Trust List Server

    App->>CFG: createContextSearchInfos("AccessCertificateVerification")
    CFG-->>App: [LoTEContextSearchInfo]

    App->>VMC: retrieveAllMetadata(issuer, contextSearchInfos, preferSignedMetadata: true)
    VMC->>Issuer: GET /.well-known/openid-credential-issuer<br/>Accept: application/jwt

    alt Signed Metadata Response
        Issuer-->>VMC: JWT (Content-Type: application/jwt)
        VMC->>SMV: validate(jwt, issuerIdentifier, contextSearchInfos)

        Note over SMV: 1. typ検証 (openidvci-issuer-metadata+jwt)
        Note over SMV: 2. 署名方式確認 (x5cのみサポート)

        SMV->>X5C: verifyJwtWithX5C(jwt, contextSearchInfos, verifyCertChain: true)

        X5C->>JWT: decodeJwtWithX5C(jwt)
        JWT-->>X5C: (decoded, x5c)

        X5C->>SIG: convertPemToX509Certificates(x5c)
        SIG-->>X5C: [Certificate]

        X5C->>JWT: verifyJwt(jwt, publicKey)
        JWT-->>X5C: Result<JWT>

        X5C->>TLM: getIssuerCertificatesForChain(x5cCertificates, contextSearchInfos)

        alt LoTEが指定されている場合
            TLM->>TL: GET trusted-list.jwt
            TL-->>TLM: LoTEDocument
            Note over TLM: 証明書ベースの検索 (AKI/SKI or DN)
            TLM-->>X5C: [SecCertificate]
            X5C->>TAM: createInstance(withAdditionalCertificates)
        else LoTE未指定
            TLM-->>X5C: Error (noLoTEConfigured)
            Note over X5C: Use singleton TrustAnchorManager
        end

        X5C->>SIG: validateCertificateChainWithCustomAnchors(certificates, trustAnchorManager)
        SIG-->>X5C: Result<Void>

        X5C-->>SMV: Result<VerifiedX5CJwt>

        Note over SMV: 3. ペイロード検証 (sub, iat, exp)

        SMV-->>VMC: Result<SignedMetadataValidationResult>

        VMC->>SMV: extractMetadataJson(payload)
        SMV-->>VMC: Data
        VMC-->>App: CredentialIssuerMetadata

    else JSON Response (fallback)
        Issuer-->>VMC: JSON (Content-Type: application/json)
        VMC-->>App: CredentialIssuerMetadata
    end
```

### TrustedListManager内部処理フロー (証明書ベース検索)

```mermaid
sequenceDiagram
    participant Caller as X5CJWTVerifier
    participant TLM as TrustedListManager
    participant TL as Trust List Server
    participant SIG as X509CertificateOperations

    Caller->>TLM: getIssuerCertificatesForChain(x5cCertificates, searchInfos)

    alt searchInfosが空の場合
        TLM-->>Caller: TrustedListError.noLoTEConfigured
    end

    Note over TLM: x5cの末尾証明書(リーフ以外の最後)を取得

    TLM->>TLM: findIssuerCertificate(for leafCertificate, searchInfos)

    Note over TLM: searchInfosをループ

    loop 各LoTEContextSearchInfo
        TLM->>TLM: fetchTrustedList(searchInfo.url)
        TLM->>TL: GET trusted-list (JSON/JWT)
        TL-->>TLM: Response (JSON or JWT)

        alt JWT形式 (eyJで始まる)
            TLM->>TLM: extractPayloadFromJWT(jwt)
            Note over TLM: Base64URLデコード
        else JSON形式
            Note over TLM: そのまま使用
        end

        TLM->>TLM: JSONDecoder.decode(LoTEDocument)

        Note over TLM: 条件フィルタリング適用
        Note over TLM: - loteType
        Note over TLM: - serviceTypeIdentifier
        Note over TLM: - status (default: granted)

        loop 各Entity/Service/Certificate
            Note over TLM: 証明書ベースのマッチング

            alt AKI/SKIマッチング (優先)
                Note over TLM: リーフ証明書のAKI == トラストリスト証明書のSKI
            else DNマッチング (フォールバック)
                Note over TLM: リーフ証明書のIssuer DN == トラストリスト証明書のSubject DN
            end

            alt マッチした場合
                TLM->>TLM: extractCertificate(ServiceDigitalIdentity)
                TLM-->>Caller: IssuerCertificateResult
            end
        end
    end

    alt 発行者証明書が見つからない場合
        TLM-->>Caller: TrustedListError.issuerCertificateNotFound
    end
```

### 証明書チェーン検証フロー

```mermaid
sequenceDiagram
    participant JWT as JWTOperations
    participant SIG as X509CertificateOperations
    participant TAM as TrustAnchorManager
    participant SEC as SecTrust API

    JWT->>SIG: validateCertificateChainWithCustomAnchors(x5cCerts, trustAnchorManager)

    Note over SIG: x5c証明書数を確認

    alt x5c = [Leaf] (1証明書)
        SIG->>TAM: intermediateCertificates
        TAM-->>SIG: [Intermediate1, Intermediate2, ...]
        Note over SIG: fullChain = [Leaf] + [Intermediates]
    else x5c = [Leaf, Intermediate, ...] (複数証明書)
        Note over SIG: fullChain = x5c (そのまま使用)
    end

    SIG->>TAM: anchorCertificates
    TAM-->>SIG: [Root CA]

    SIG->>SEC: SecTrustCreateWithCertificates(fullChain)
    SIG->>SEC: SecTrustSetAnchorCertificates(anchors)
    SIG->>SEC: SecTrustEvaluateWithError()
    SEC-->>SIG: Result

    SIG-->>JWT: Result<Void>
```

## API Reference

### VCIMetadataClient

メタデータ取得のエントリポイント。

```swift
// tw2023_wallet/Services/OID/VCI/VCIMetadataClient.swift

/// Credential Issuerメタデータを取得
/// - Parameters:
///   - url: メタデータエンドポイントURL
///   - issuerIdentifier: Credential Issuer識別子 (sub検証用)
///   - preferSignedMetadata: true=署名付き(application/jwt), false=JSON(application/json)
///   - contextSearchInfos: 検索対象のLoTEコンテキスト情報配列
/// - Returns: CredentialIssuerMetadata
func fetchCredentialIssuerMetadata(
    from url: URL,
    issuerIdentifier: String,
    preferSignedMetadata: Bool = false,
    contextSearchInfos: [LoTEContextSearchInfo] = [],
    using session: URLSession = URLSession.shared
) async throws -> CredentialIssuerMetadata

/// すべてのメタデータ (Issuer + Authorization Server) を取得
func retrieveAllMetadata(
    issuer: String,
    preferSignedMetadata: Bool = false,
    contextSearchInfos: [LoTEContextSearchInfo] = [],
    using session: URLSession = URLSession.shared
) async throws -> Metadata
```

### SignedMetadataValidator

署名付きメタデータの検証。

```swift
// tw2023_wallet/Services/OID/VCI/SignedMetadataValidator.swift

enum SignedMetadataValidator {
    /// 署名付きメタデータを検証 (TrustedList対応)
    /// - Parameters:
    ///   - jwt: 署名付きメタデータJWT
    ///   - expectedIssuerIdentifier: 期待するCredential Issuer識別子
    ///   - contextSearchInfos: 検索対象のLoTEコンテキスト情報配列
    static func validate(
        jwt: String,
        expectedIssuerIdentifier: String,
        contextSearchInfos: [LoTEContextSearchInfo] = []
    ) async -> Result<SignedMetadataValidationResult, SignedMetadataError>

    /// ペイロードからメタデータJSONを抽出
    static func extractMetadataJson(from payload: [String: Any]) throws -> Data
}

/// 検証結果
struct SignedMetadataValidationResult {
    let payload: [String: Any]
    let issuer: String?      // iss (OPTIONAL)
    let subject: String      // sub (REQUIRED) = Credential Issuer識別子
    let issuedAt: Date       // iat (REQUIRED)
    let expiresAt: Date?     // exp (OPTIONAL)
}
```

### TrustedListManager

ETSI TS 119 602 LoTE形式のトラストリスト管理。証明書ベースの発行者検索を提供。

```swift
// tw2023_wallet/Services/TrustedList/TrustedListManager.swift

class TrustedListManager {
    static let shared = TrustedListManager()

    /// トラストリストをフェッチ (JSON/JWT両形式対応)
    func fetchTrustedList(from url: URL) async throws -> LoTEDocument

    /// リーフ証明書の発行者証明書をトラストリストから検索
    /// AKI/SKIマッチングを優先し、フォールバックとしてDNマッチングを使用
    /// - Parameters:
    ///   - leafCertificate: 検索対象のリーフ証明書
    ///   - searchInfos: 検索対象のLoTEコンテキスト情報配列
    func findIssuerCertificate(
        for leafCertificate: Certificate,
        searchInfos: [LoTEContextSearchInfo]
    ) async throws -> IssuerCertificateResult

    /// x5c証明書チェーンの発行者証明書を取得
    /// x5cの末尾証明書の発行者をトラストリストから検索
    /// - Parameters:
    ///   - x5cCertificates: x5cヘッダーから取得した証明書チェーン
    ///   - searchInfos: 検索対象のLoTEコンテキスト情報配列
    func getIssuerCertificatesForChain(
        x5cCertificates: [Certificate],
        searchInfos: [LoTEContextSearchInfo]
    ) async throws -> [SecCertificate]
}

/// 発行者証明書検索結果
struct IssuerCertificateResult {
    let entity: TrustedEntity
    let service: TrustedEntityService
    let issuerCertificate: Certificate
    let matchMethod: MatchMethod  // .akiSki or .distinguishedName
}

/// マッチング方法
enum MatchMethod {
    case akiSki           // AKI/SKIによるマッチング
    case distinguishedName // DNによるフォールバックマッチング
}
```

### TrustAnchorManager

信頼アンカー証明書の管理。

```swift
// tw2023_wallet/Signature/TrustAnchorManager.swift

class TrustAnchorManager {
    static let shared = TrustAnchorManager()

    /// ルートCA証明書
    private(set) var anchorCertificates: [SecCertificate]

    /// 中間証明書
    private(set) var intermediateCertificates: [SecCertificate]

    /// カスタムアンカーが設定されているか
    var hasCustomAnchors: Bool

    /// 追加証明書を持つ使い捨てインスタンスを生成
    /// (シングルトンの証明書を継承 + 追加証明書)
    static func createInstance(
        withAdditionalCertificates additionalCertificates: [SecCertificate]
    ) -> TrustAnchorManager
}
```

### X5CJWTVerifier

x5c/x5uヘッダーを使用したJWT検証のラッパー層。JWTOperationsとX509CertificateOperationsを統合して証明書チェーン検証を行う。

```swift
// tw2023_wallet/Signature/X5CJWTVerifier.swift

enum X5CJWTVerifier {
    typealias VerifiedX5CJwt = (decoded: JWT, certs: [Certificate])

    /// x5cヘッダーでJWTを検証 (署名検証 + 証明書チェーン検証)
    /// 証明書ベースの検索でトラストリストから発行者証明書を取得
    /// - Parameters:
    ///   - jwt: 検証対象のJWT
    ///   - contextSearchInfos: 検索対象のLoTEコンテキスト情報配列
    ///   - verifyCertChain: 証明書チェーン検証を行うか
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

### JWTOperations

純粋なJWT操作（署名、検証、デコード）を提供。

```swift
// tw2023_wallet/Signature/JWT.swift

enum JWTOperations {
    /// JWTに署名
    static func sign(
        keyAlias: String,
        header: [String: Any],
        payload: [String: Any]
    ) -> Result<String, SignatureError>

    /// 公開鍵でJWT署名を検証
    static func verifyJwt(
        jwt: String,
        publicKey: SecKey
    ) -> Result<JWT, JWTVerificationError>

    /// JWTをデコード
    static func decodeJwt(jwt: String) throws -> ([String: Any], [String: Any], String?)

    /// JWTをデコードしてx5cヘッダーを抽出
    static func decodeJwtWithX5C(
        jwt: String
    ) -> Result<(decoded: JWT, x5c: [String]), JWTVerificationError>

    /// JWTをデコードしてx5uヘッダーを抽出
    static func decodeJwtWithX5U(
        jwt: String
    ) -> Result<(decoded: JWT, x5uUrl: String), JWTVerificationError>
}
```

## Error Types

### SignedMetadataError

```swift
enum SignedMetadataError: LocalizedError {
    case unsupportedSignatureMethod(String)  // x5c以外の署名方式
    case invalidTyp(String)                   // typ != openidvci-issuer-metadata+jwt
    case missingRequiredClaim(String)         // sub, iat等の必須クレーム欠落
    case subjectMismatch(expected: String, actual: String)  // sub不一致
    case expiredMetadata                      // 期限切れ
    case signatureVerificationFailed(String)  // 署名検証失敗
    case certificateValidationFailed(String)  // 証明書チェーン検証失敗
}
```

### MetadataError

```swift
enum MetadataError: LocalizedError {
    // ... (既存のエラー)
    case signedMetadataValidationFailed(SignedMetadataError)
    case contentTypeMismatch(expected: String, actual: String)
}
```

### TrustedListError

```swift
enum TrustedListError: Error {
    case noLoTEConfigured                     // LoTE情報が指定されていない
    case invalidURL(String)
    case fetchFailed(URL, Error)
    case parseError(Error)
    case issuerCertificateNotFound            // 発行者証明書が見つからない
    case noCertificatesInService
    case certificateParseError
}
```

## Data Models

### Signed Metadata JWT Structure

```json
{
  "header": {
    "alg": "ES256",
    "typ": "openidvci-issuer-metadata+jwt",
    "x5c": ["<leaf-cert-base64>", "<intermediate-cert-base64>", ...]
  },
  "payload": {
    "iss": "<party attesting to claims>",
    "sub": "<credential-issuer-identifier>",
    "iat": 1234567890,
    "exp": 1234567890,
    "credential_issuer": "...",
    "credential_endpoint": "...",
    "credential_configurations_supported": { ... }
  }
}
```

### LoTE Document Structure (ETSI TS 119 602)

```json
{
  "LoTE": {
    "ListAndSchemeInformation": {
      "SchemeOperatorName": [{ "lang": "en", "value": "Operator Name" }],
      "ListIssueDateTime": "2026-01-01T00:00:00Z",
      "NextUpdate": "2026-06-01T00:00:00Z"
    },
    "TrustedEntitiesList": [
      {
        "TrustedEntityInformation": {
          "TEName": [{ "lang": "en", "value": "Entity Name" }]
        },
        "TrustedEntityServices": [
          {
            "ServiceInformation": {
              "ServiceTypeIdentifier": "http://example.com/SvcType/CredentialIssuance",
              "ServiceStatus": "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/granted",
              "ServiceSupplyPoints": [
                { "uriValue": "https://issuer.example.com" }
              ],
              "ServiceDigitalIdentity": {
                "X509Certificates": ["-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"]
              }
            }
          }
        ]
      }
    ]
  }
}
```

## Implementation Files

| File | Description |
|------|-------------|
| `tw2023_wallet/Services/OID/VCI/VCIMetadataClient.swift` | メタデータ取得クライアント |
| `tw2023_wallet/Services/OID/VCI/SignedMetadataValidator.swift` | 署名付きメタデータ検証 |
| `tw2023_wallet/Services/TrustedList/TrustedListManager.swift` | トラストリスト管理 |
| `tw2023_wallet/Services/TrustedList/TrustedListModels.swift` | LoTEデータモデル |
| `tw2023_wallet/Services/TrustedList/TrustedListConfig.swift` | LoTE設定モデル・ローダー |
| `tw2023_wallet/Signature/TrustAnchorManager.swift` | 信頼アンカー証明書管理 |
| `tw2023_wallet/Signature/X5CJWTVerifier.swift` | x5c/x5u JWT検証ラッパー |
| `tw2023_wallet/Signature/JWT.swift` | JWT操作 |
| `tw2023_wallet/Signature/X509CertificateOperations.swift` | 証明書チェーン検証 |

## Configuration

### Trusted List Config (TrustedListConfig.json)

LoTE (List of Trusted Entities) の設定ファイル。JSON形式で複数のLoTEとそのコンテキストを定義できる。

```json
{
  "lotes": {
    "jp-lote": {
      "url": "https://tl.eujp.ownd-project.com/api/trusted-list.jwt",
      "context": {
        "AccessCertificateVerification": {
          "condition": {
            "loteType": "http://tl.eujp.ownd-project.com/LoTEType/private",
            "serviceTypeIdentifier": "http://tl.eujp.ownd-project.com/SvcType/OID4VCI/CredentialIssuance"
          }
        },
        "AccessCertificateStatusConfirmation": {
          "condition": {
            "loteType": "http://tl.eujp.ownd-project.com/LoTEType/private",
            "serviceTypeIdentifier": "http://tl.eujp.ownd-project.com/SvcType/OID4VCI/CredentialIssuance",
            "status": "granted"
          }
        }
      }
    }
  }
}
```

### TrustedListConfigLoader

設定ファイルの読み込みとLoTEContextSearchInfo生成を担当。

```swift
// tw2023_wallet/Services/TrustedList/TrustedListConfig.swift

enum TrustedListConfigLoader {
    /// 設定ファイルを読み込む
    static func loadConfig() -> TrustedListConfig?

    /// 指定されたコンテキスト名からLoTEContextSearchInfo配列を生成
    /// - Parameter contextName: コンテキスト名 (例: "AccessCertificateVerification")
    /// - Returns: LoTEContextSearchInfo配列
    static func createContextSearchInfos(
        contextName: String
    ) -> [LoTEContextSearchInfo]
}

/// VCIMetadataClient等に渡すLoTEコンテキスト検索情報
struct LoTEContextSearchInfo {
    let url: URL
    let contextName: String
    let condition: SearchCondition

    struct SearchCondition {
        let loteType: String?
        let serviceTypeIdentifier: String?
        let status: String?  // nil = フィルタリングなし (grantedでないものも対象)
    }
}
```

### 使用例

```swift
// VCIでのメタデータ取得時
let contextSearchInfos = TrustedListConfigLoader.createContextSearchInfos(
    contextName: "AccessCertificateVerification"
)

let metadata = try await retrieveAllMetadata(
    issuer: issuerURL,
    preferSignedMetadata: true,
    contextSearchInfos: contextSearchInfos
)
```

### Build Phase設定

Xcode Build Phaseに「Copy Trusted List Config」スクリプトを追加:

```bash
CONFIG_SOURCE="${SRCROOT}/TrustedListConfig.json"
CONFIG_DEST="${BUILT_PRODUCTS_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}/TrustedListConfig.json"

if [ -f "$CONFIG_SOURCE" ]; then
    cp "$CONFIG_SOURCE" "$CONFIG_DEST"
    echo "TrustedListConfig.json copied to bundle"
else
    echo "TrustedListConfig.json not found (optional)"
fi
```

## Certificate-Based Search

### 概要

トラストリストからの証明書検索は、サービスURL（ServiceSupplyPoints）ではなく、証明書の識別子に基づいて行われます。

### 検索アルゴリズム

1. **AKI/SKIマッチング（優先）**
   - リーフ証明書のAuthority Key Identifier (AKI) を取得
   - トラストリスト内の各証明書のSubject Key Identifier (SKI) と比較
   - マッチした証明書を発行者証明書として返却

2. **DNマッチング（フォールバック）**
   - AKI/SKIが利用できない場合に使用
   - リーフ証明書のIssuer Distinguished Name (DN) を取得
   - トラストリスト内の各証明書のSubject DN と比較
   - マッチした証明書を発行者証明書として返却

### 条件フィルタリング

検索時に以下の条件でフィルタリングが可能:

- `loteType`: LoTEの種類 (例: private, public)
- `serviceTypeIdentifier`: サービスタイプ (例: CredentialIssuance)
- `status`: サービスステータス (例: granted, withdrawn)

## References

### Specifications

- [OID4VCI 1.0 Section 12.2.2 - Obtaining Credential Issuer Metadata](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#section-12.2.2)
- [OID4VCI 1.0 Section 12.2.3 - Signed Metadata](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#section-12.2.3)
- [ETSI TS 119 602 - Trusted Lists](https://www.etsi.org/deliver/etsi_ts/119600_119699/119602/01.01.01_60/ts_119602v010101p.pdf)
- [RFC 7515 - JSON Web Signature](https://www.rfc-editor.org/rfc/rfc7515.html)
- [RFC 5280 - X.509 PKI Certificate](https://www.rfc-editor.org/rfc/rfc5280.html)

### Related Documentation

- [X.509 Certificate Chain Validation](../../x509-certificate-chain-validation.md)
- [API Reference](./api.md)
- [Security](./security.md)

### Work Documents

- [Signed Metadata Implementation](../../work/2026-01-05-signed-metadata-implementation.md)
- [Accept Header Fix](../../work/2026-01-06-signed-metadata-accept-header-fix.md)
- [Trust List Support](../../work/2026-01-07-work-trusted-list-support.md)
- [Metadata Validation Refactoring](../../work/2026-01-08-metadata-validation-refactoring.md)
- [JWT Chain Validation Refactoring](../../work/2026-01-08-refactor-jwt-chain-validation.md)
- [LoTE Service Type Support](../../work/2026-01-09-lote-service-type-support.md)
