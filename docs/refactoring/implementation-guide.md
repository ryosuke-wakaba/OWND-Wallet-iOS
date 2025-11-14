# Credential Issuance リファクタリング実装ガイド

## 概要

このドキュメントは、[Credential Issuanceリファクタリング計画](./credential-issuance-refactoring.md)の具体的な実装方法を示すガイドです。各フェーズの実装例とベストプラクティスを含みます。

## フェーズ1: 基盤改善

### 1.1 エラーハンドリングの統一

#### ステップ1: 新しいエラー型を作成

```swift
// tw2023_wallet/Errors/CredentialIssuanceErrors.swift
import Foundation

/// Credential Issuance process errors
enum CredentialIssuanceError: Error, LocalizedError {
    // MARK: - Data Loading Errors

    /// Metadata loading failed
    case metadataLoadFailed(reason: String)

    /// Credential offer is invalid
    case credentialOfferInvalid(reason: String)

    // MARK: - Configuration Errors

    /// Credential configuration not found in metadata
    case configurationNotFound(id: String)

    /// Credential offer has no configuration IDs
    case emptyConfiguration

    // MARK: - Proof Errors

    /// Failed to generate proof
    case proofGenerationFailed(reason: String)

    /// Requested proof type is not supported
    case unsupportedProofType(supported: [String], requested: String?)

    // MARK: - Credential Request Errors

    /// Credential request failed
    case credentialRequestFailed(statusCode: Int, body: String?)

    /// Received credential validation failed
    case credentialValidationFailed(reason: String)

    // MARK: - Storage Errors

    /// Failed to save credential
    case storageFailed(underlyingError: Error)

    // MARK: - Deferred Issuance Errors

    /// Transaction ID required but not provided
    case transactionIdRequired

    /// Deferred issuance is not yet supported
    case deferredIssuanceNotSupported

    // MARK: - Conversion Errors

    /// Failed to convert credential to internal format
    case conversionFailed(reason: String)

    // MARK: - LocalizedError Implementation

    var errorDescription: String? {
        switch self {
        case .metadataLoadFailed(let reason):
            return NSLocalizedString(
                "Failed to load issuer metadata: \(reason)",
                comment: "Metadata load error")
        case .credentialOfferInvalid(let reason):
            return NSLocalizedString(
                "Invalid credential offer: \(reason)",
                comment: "Invalid offer error")
        case .configurationNotFound(let id):
            return NSLocalizedString(
                "Credential configuration '\(id)' not found",
                comment: "Configuration not found error")
        case .emptyConfiguration:
            return NSLocalizedString(
                "Credential offer has no configurations",
                comment: "Empty configuration error")
        case .proofGenerationFailed(let reason):
            return NSLocalizedString(
                "Failed to generate proof: \(reason)",
                comment: "Proof generation error")
        case .unsupportedProofType(let supported, let requested):
            let requestedStr = requested ?? "none"
            let supportedStr = supported.joined(separator: ", ")
            return NSLocalizedString(
                "Proof type '\(requestedStr)' is not supported. Supported types: \(supportedStr)",
                comment: "Unsupported proof type error")
        case .credentialRequestFailed(let statusCode, let body):
            let bodyStr = body ?? "No details available"
            return NSLocalizedString(
                "Credential request failed (HTTP \(statusCode)): \(bodyStr)",
                comment: "Credential request error")
        case .credentialValidationFailed(let reason):
            return NSLocalizedString(
                "Received credential is invalid: \(reason)",
                comment: "Credential validation error")
        case .storageFailed(let error):
            return NSLocalizedString(
                "Failed to save credential: \(error.localizedDescription)",
                comment: "Storage error")
        case .transactionIdRequired:
            return NSLocalizedString(
                "Transaction ID is required for deferred credential issuance",
                comment: "Transaction ID required error")
        case .deferredIssuanceNotSupported:
            return NSLocalizedString(
                "Deferred credential issuance is not yet supported",
                comment: "Deferred issuance not supported error")
        case .conversionFailed(let reason):
            return NSLocalizedString(
                "Failed to convert credential: \(reason)",
                comment: "Conversion error")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .metadataLoadFailed:
            return NSLocalizedString(
                "Check your network connection and try again",
                comment: "Metadata load recovery")
        case .credentialOfferInvalid:
            return NSLocalizedString(
                "Please scan a valid QR code from the issuer",
                comment: "Invalid offer recovery")
        case .configurationNotFound, .emptyConfiguration:
            return NSLocalizedString(
                "Please contact the credential issuer",
                comment: "Configuration error recovery")
        case .unsupportedProofType:
            return NSLocalizedString(
                "Your wallet may need to be updated. Please contact support.",
                comment: "Unsupported proof type recovery")
        case .credentialRequestFailed:
            return NSLocalizedString(
                "Please try again later or contact the issuer",
                comment: "Request failed recovery")
        case .credentialValidationFailed:
            return NSLocalizedString(
                "Please contact the credential issuer",
                comment: "Validation failed recovery")
        case .storageFailed:
            return NSLocalizedString(
                "Please check your device storage and try again",
                comment: "Storage failed recovery")
        case .deferredIssuanceNotSupported:
            return NSLocalizedString(
                "Please contact the issuer for immediate issuance",
                comment: "Deferred issuance recovery")
        default:
            return NSLocalizedString(
                "Please try again or contact support",
                comment: "Generic recovery suggestion")
        }
    }
}
```

#### ステップ2: ViewModelを更新

```swift
// Before
throw CredentialOfferViewModelError.LoadDataDidNotFinishuccessfully

// After
throw CredentialIssuanceError.metadataLoadFailed(
    reason: "Credential offer or metadata is missing"
)
```

```swift
// Before
throw CredentialOfferViewModelError.UnsupportedProofType(supportedTypes: supportedTypes)

// After
throw CredentialIssuanceError.unsupportedProofType(
    supported: supportedTypes,
    requested: "jwt"
)
```

#### ステップ3: UIでのエラー表示を更新

```swift
// PinCodeInput.swift
catch {
    print("Error in sendRequest: \(error)")
    // Use localizedDescription from LocalizedError
    if let localizedError = error as? LocalizedError,
       let description = localizedError.errorDescription {
        errorMessage = description

        // Add recovery suggestion if available
        if let suggestion = localizedError.recoverySuggestion {
            errorMessage += "\n\n\(suggestion)"
        }
    } else {
        errorMessage = "\(error)"
    }
    showErrorDialog = true
}
```

### 1.2 定数の管理

#### CredentialFormat enum作成

```swift
// tw2023_wallet/Constants/CredentialFormats.swift
import Foundation

/// Verifiable Credential formats supported by the wallet
enum CredentialFormat: String, CaseIterable {
    /// SD-JWT VC (Legacy format name from OID4VCI Draft)
    case sdJwtVC = "vc+sd-jwt"

    /// DC+SD-JWT (OID4VCI 1.0 Final format name)
    case dcSDJWT = "dc+sd-jwt"

    /// JWT VC JSON
    case jwtVCJson = "jwt_vc_json"

    /// Linked Data Proof VC
    case ldpVC = "ldp_vc"

    // MARK: - Helper Properties

    /// Returns true if this format is an SD-JWT variant
    var isSDJWT: Bool {
        switch self {
        case .sdJwtVC, .dcSDJWT:
            return true
        default:
            return false
        }
    }

    /// Returns true if this format is JWT-based
    var isJWTBased: Bool {
        switch self {
        case .sdJwtVC, .dcSDJWT, .jwtVCJson:
            return true
        case .ldpVC:
            return false
        }
    }

    /// Returns the preferred format name (for new implementations)
    static var preferredSDJWT: CredentialFormat {
        return .dcSDJWT
    }

    // MARK: - Initialization

    /// Initialize from a string, supporting both old and new format names
    init?(rawValue: String) {
        switch rawValue {
        case "vc+sd-jwt":
            self = .sdJwtVC
        case "dc+sd-jwt":
            self = .dcSDJWT
        case "jwt_vc_json":
            self = .jwtVCJson
        case "ldp_vc":
            self = .ldpVC
        default:
            return nil
        }
    }
}
```

#### 使用例

```swift
// Before
if format == "dc+sd-jwt" {
    // ...
}

// After
let format = CredentialFormat(rawValue: formatString)
if format?.isSDJWT == true {
    // ...
}
```

```swift
// Before
case "vc+sd-jwt", "dc+sd-jwt":
    // SD-JWT specific logic

// After
case let format where format.isSDJWT:
    // SD-JWT specific logic
```

#### Cryptography定数

```swift
// tw2023_wallet/Constants/CryptographyConstants.swift
import Foundation

/// Cryptography-related constants
enum CryptographyConstants {
    /// Key aliases for the Keychain
    enum KeyAlias {
        /// Key binding key for OID4VCI proof generation
        static let keyBinding = "key_binding"

        /// Key for JWT VP JSON signatures
        static let jwtVpJson = "jwt_vp_json_key"

        /// Device-specific key
        static let deviceKey = "device_key"
    }

    /// Supported signing algorithms
    enum SigningAlgorithm: String {
        case es256 = "ES256"
        case es384 = "ES384"
        case es512 = "ES512"

        /// Currently supported algorithms for OID4VCI proofs
        static var supportedForProofs: [SigningAlgorithm] {
            return [.es256]
        }
    }
}
```

### 1.3 重複コードの除去

#### JWTParsingUtil作成

```swift
// tw2023_wallet/Utils/JWTParsingUtil.swift
import Foundation

/// JWT claims extracted from a JWT token
struct JWTClaims {
    let issuer: String?
    let subject: String?
    let issuedAt: Int64?
    let expiresAt: Int64?
    let audience: String?
    let jwtId: String?

    init(from payload: [String: Any]) {
        self.issuer = payload["iss"] as? String
        self.subject = payload["sub"] as? String
        self.issuedAt = payload["iat"] as? Int64
        self.expiresAt = payload["exp"] as? Int64
        self.audience = payload["aud"] as? String
        self.jwtId = payload["jti"] as? String
    }
}

/// Utilities for parsing JWT tokens
enum JWTParsingUtil {

    /// Decodes a JWT payload to a dictionary
    /// - Parameter jwt: The JWT string (format: header.payload.signature)
    /// - Returns: The decoded payload as a dictionary, or nil if parsing fails
    static func decodePayload(_ jwt: String) -> [String: Any]? {
        let components = jwt.components(separatedBy: ".")
        guard components.count >= 2 else {
            return nil
        }

        guard let decodedPayload = components[1].base64UrlDecoded(),
              let decodedString = String(data: decodedPayload, encoding: .utf8),
              let jsonData = decodedString.data(using: .utf8),
              let payload = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any]
        else {
            return nil
        }

        return payload
    }

    /// Extracts standard JWT claims from a JWT token
    /// - Parameter jwt: The JWT string
    /// - Returns: Extracted claims, or nil if parsing fails
    static func extractStandardClaims(_ jwt: String) -> JWTClaims? {
        guard let payload = decodePayload(jwt) else {
            return nil
        }
        return JWTClaims(from: payload)
    }

    /// Extracts the credential type from a JWT based on the format
    /// - Parameters:
    ///   - jwt: The JWT string
    ///   - format: The credential format
    /// - Returns: The credential type/vct, or nil if not found
    static func extractCredentialType(from jwt: String, format: CredentialFormat) -> String? {
        guard let payload = decodePayload(jwt) else {
            return nil
        }

        switch format {
        case .dcSDJWT, .sdJwtVC:
            // SD-JWT uses "vct" (verifiable credential type)
            return payload["vct"] as? String
        case .jwtVCJson:
            // JWT VC JSON uses "type"
            return payload["type"] as? String
        case .ldpVC:
            return nil
        }
    }

    /// Extracts complete credential information from a JWT
    /// - Parameters:
    ///   - jwt: The JWT string
    ///   - format: The credential format
    /// - Returns: Credential information or nil if parsing fails
    static func extractCredentialInfo(from jwt: String, format: CredentialFormat) -> CredentialInfo? {
        guard let claims = extractStandardClaims(jwt),
              let issuer = claims.issuer,
              let issuedAt = claims.issuedAt,
              let expiresAt = claims.expiresAt,
              let type = extractCredentialType(from: jwt, format: format)
        else {
            return nil
        }

        return CredentialInfo(
            issuer: issuer,
            issuedAt: issuedAt,
            expiresAt: expiresAt,
            type: type
        )
    }
}

/// Credential information extracted from JWT
struct CredentialInfo {
    let issuer: String
    let issuedAt: Int64
    let expiresAt: Int64
    let type: String
}
```

#### MetadataDecoder作成

```swift
// tw2023_wallet/Utils/MetadataDecoder.swift
import Foundation

/// Utilities for encoding/decoding credential issuer metadata
enum MetadataDecoder {

    /// Decodes credential issuer metadata from a JSON string
    /// - Parameter jsonString: JSON string representation of metadata
    /// - Returns: Decoded metadata, or nil if decoding fails
    static func decode(from jsonString: String) -> CredentialIssuerMetadata? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            return nil
        }

        return decode(from: jsonData)
    }

    /// Decodes credential issuer metadata from JSON data
    /// - Parameter data: JSON data representation of metadata
    /// - Returns: Decoded metadata, or nil if decoding fails
    static func decode(from data: Data) -> CredentialIssuerMetadata? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        return try? decoder.decode(CredentialIssuerMetadata.self, from: data)
    }

    /// Encodes credential issuer metadata to a JSON string
    /// - Parameter metadata: The metadata to encode
    /// - Returns: JSON string representation, or nil if encoding fails
    static func encode(_ metadata: CredentialIssuerMetadata) -> String? {
        guard let data = encode(metadata) else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    /// Encodes credential issuer metadata to JSON data
    /// - Parameter metadata: The metadata to encode
    /// - Returns: JSON data representation, or nil if encoding fails
    static func encode(_ metadata: CredentialIssuerMetadata) -> Data? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        return try? encoder.encode(metadata)
    }
}
```

#### 既存コードを更新

```swift
// Before (CredentialOfferViewModel)
private func extractInfoFromJwt(jwt: String, format: String) -> [String: Any] {
    guard let decodedPayload = jwt.components(separatedBy: ".")[1].base64UrlDecoded(),
        let decodedString = String(data: decodedPayload, encoding: .utf8),
        let jsonData = decodedString.data(using: .utf8),
        let jwtDictionary = try? JSONSerialization.jsonObject(with: jsonData, options: [])
            as? [String: Any]
    else {
        return [:]
    }

    let iss = jwtDictionary["iss"] as? String ?? ""
    let iat = jwtDictionary["iat"] as? Int64 ?? 0
    let exp = jwtDictionary["exp"] as? Int64 ?? 0
    let typeOrVct: String
    if format == "dc+sd-jwt" {
        typeOrVct = jwtDictionary["vct"] as? String ?? ""
    }
    else {
        typeOrVct = jwtDictionary["type"] as? String ?? ""
    }

    return ["iss": iss, "iat": iat, "exp": exp, "typeOrVct": typeOrVct]
}

// After
private func extractInfoFromJwt(jwt: String, format: CredentialFormat) -> CredentialInfo? {
    return JWTParsingUtil.extractCredentialInfo(from: jwt, format: format)
}
```

```swift
// Before (CredentialDataManager)
func parsedMetaData() -> CredentialIssuerMetadata? {
    if let jsonData = self.credentialIssuerMetadata.data(using: .utf8) {
        do {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let result = try decoder.decode(CredentialIssuerMetadata.self, from: jsonData)
            return result
        }
        catch {
            print("Error converting JSON string to CredentialIssuerMetadata: \(error)")
        }
    }
    return nil
}

// After
func parsedMetaData() -> CredentialIssuerMetadata? {
    return MetadataDecoder.decode(from: self.credentialIssuerMetadata)
}
```

## テストの書き方

### Unit Testの例

```swift
// tw2023_walletTests/Utils/JWTParsingUtilTests.swift
import XCTest
@testable import tw2023_wallet

class JWTParsingUtilTests: XCTestCase {

    func testDecodeValidJWT() {
        // Given: A valid JWT
        let jwt = "eyJhbGciOiJFUzI1NiJ9.eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLmNvbSIsInN1YiI6InVzZXItMTIzIiwiaWF0IjoxNzA1MjAwMDAwLCJleHAiOjE3MzY4MjIwMDAsInZjdCI6IlVuaXZlcnNpdHlEZWdyZWVDcmVkZW50aWFsIn0.signature"

        // When: Decoding the payload
        let payload = JWTParsingUtil.decodePayload(jwt)

        // Then: Should successfully decode
        XCTAssertNotNil(payload)
        XCTAssertEqual(payload?["iss"] as? String, "https://issuer.example.com")
        XCTAssertEqual(payload?["sub"] as? String, "user-123")
    }

    func testExtractStandardClaims() {
        // Given: A JWT with standard claims
        let jwt = createTestJWT()

        // When: Extracting standard claims
        let claims = JWTParsingUtil.extractStandardClaims(jwt)

        // Then: Should extract all standard claims
        XCTAssertNotNil(claims)
        XCTAssertEqual(claims?.issuer, "https://issuer.example.com")
        XCTAssertEqual(claims?.issuedAt, 1705200000)
        XCTAssertEqual(claims?.expiresAt, 1736822000)
    }

    func testExtractCredentialTypeForSDJWT() {
        // Given: An SD-JWT credential
        let jwt = createTestJWT(vct: "UniversityDegreeCredential")

        // When: Extracting credential type
        let type = JWTParsingUtil.extractCredentialType(
            from: jwt,
            format: .dcSDJWT
        )

        // Then: Should extract vct
        XCTAssertEqual(type, "UniversityDegreeCredential")
    }

    func testExtractCredentialInfo() {
        // Given: A complete JWT
        let jwt = createTestJWT()

        // When: Extracting credential info
        let info = JWTParsingUtil.extractCredentialInfo(
            from: jwt,
            format: .dcSDJWT
        )

        // Then: Should extract all information
        XCTAssertNotNil(info)
        XCTAssertEqual(info?.issuer, "https://issuer.example.com")
        XCTAssertEqual(info?.type, "UniversityDegreeCredential")
    }

    // Helper to create test JWT
    private func createTestJWT(vct: String = "UniversityDegreeCredential") -> String {
        // Create a test JWT (simplified, in real tests use proper JWT library)
        let header = ["alg": "ES256"]
        let payload: [String: Any] = [
            "iss": "https://issuer.example.com",
            "sub": "user-123",
            "iat": 1705200000,
            "exp": 1736822000,
            "vct": vct
        ]

        // Encode to JWT format
        // ... (implementation details)
        return "eyJ...test...jwt"
    }
}
```

## チェックリスト

### フェーズ1完了チェックリスト

- [ ] エラーハンドリング
  - [ ] CredentialIssuanceErrors.swift作成
  - [ ] 全エラーケースにerrorDescription実装
  - [ ] 全エラーケースにrecoverySuggestion実装
  - [ ] ViewModelのエラー処理を移行
  - [ ] UIのエラー表示を更新
  - [ ] エラーメッセージのローカライズ

- [ ] 定数管理
  - [ ] CredentialFormats.swift作成
  - [ ] CryptographyConstants.swift作成
  - [ ] 全フォーマット文字列を置換
  - [ ] 全Key aliasを置換
  - [ ] コンパイルエラー解消

- [ ] 重複コード除去
  - [ ] JWTParsingUtil.swift作成
  - [ ] MetadataDecoder.swift作成
  - [ ] ViewModelの重複ロジック削除
  - [ ] CredentialDataManagerの重複ロジック削除
  - [ ] Unit Tests作成

- [ ] テスト
  - [ ] 既存テスト全てパス
  - [ ] 新規Unit Tests作成
  - [ ] コードカバレッジ確認

- [ ] ドキュメント
  - [ ] コードコメント追加
  - [ ] 変更点をREADMEに記載

## 参考資料

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [Error Handling in Swift](https://docs.swift.org/swift-book/LanguageGuide/ErrorHandling.html)
- [Swift Enums](https://docs.swift.org/swift-book/LanguageGuide/Enumerations.html)
