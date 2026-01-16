# JAdES署名検証機能の実装

## ステータス
- [x] 作業ドキュメント作成
- [x] ブランチ作成
- [x] JAdESSignatureVerifier.swift 実装
- [x] TrustedListManager 統合
- [x] テスト作成
- [x] ビルド確認
- [x] 動作確認
- [ ] レビュー

## 概要

TrustedListManager でダウンロードした JWT 形式の Trusted List に対して、JAdES Baseline-B (ETSI TS 119 182-1) に基づく署名検証機能を実装する。

現在、`TrustedListManager.fetchTrustedList()` は JWT 形式のレスポンスを検出した場合、ペイロードの抽出のみを行い署名検証は行っていない。本実装により、署名検証を追加してリストの真正性と完全性を保証する。

## 対象ファイル

### 新規作成

| ファイル | 責務 |
|---------|------|
| `tw2023_wallet/Signature/JAdESSignatureVerifier.swift` | JAdES Baseline-B 署名検証モジュール |
| `tw2023_walletTests/Signature/JAdESSignatureVerifierTests.swift` | 単体テスト |

### 変更

| ファイル | 変更内容 |
|---------|---------|
| `tw2023_wallet/Services/TrustedList/TrustedListManager.swift` | JAdES検証の呼び出し、エラー型追加 |

## JAdES Baseline-B 仕様

ETSI TS 119 182-1 に基づき、以下のヘッダー属性を検証する。

### 必須ヘッダー属性

| 属性 | 説明 |
|-----|------|
| `sigT` | 署名作成日時 (ISO 8601 / RFC 3339 形式) |
| `x5t#S256` | 署名に使用したX.509証明書のSHA-256ハッシュ値 (Base64URL) |
| `crit` | 重要ヘッダーパラメータ (`["sigT", "x5t#S256"]` など) |

### JWTヘッダー例

```json
{
  "alg": "ES256",
  "typ": "JWT",
  "x5c": ["MIIB..."],
  "crit": ["sigT", "x5t#S256"],
  "sigT": "2026-01-10T12:00:00Z",
  "x5t#S256": "a1b2c3..."
}
```

## 実装詳細

### JAdESSignatureVerifier.swift

```swift
enum JAdESSignatureVerifier {
    // MARK: - Error Types

    enum JAdESVerificationError: Error, LocalizedError {
        // sigT検証エラー
        case sigTMissing
        case sigTInvalidFormat(String)
        case sigTInFuture(sigT: Date, now: Date, tolerance: TimeInterval)
        case sigTOutsideCertificateValidity(sigT: Date, notBefore: Date, notAfter: Date)

        // x5t#S256検証エラー
        case x5tS256Missing
        case x5tS256Mismatch(expected: String, actual: String)

        // 証明書エラー
        case noCertificateProvided
        case certificateExtractionFailed(String)
        case publicKeyExtractionFailed

        // 署名エラー
        case signatureVerificationFailed(String)
        case unsupportedAlgorithm(String)

        // critヘッダーエラー
        case criticalHeaderNotProcessed(String)
    }

    // MARK: - Configuration

    struct VerificationOptions {
        let clockSkewTolerance: TimeInterval  // デフォルト: 300秒 (5分)
        let validateSigTAgainstCertValidity: Bool  // デフォルト: true
        let requireCritValidation: Bool  // デフォルト: true

        static let `default` = VerificationOptions(
            clockSkewTolerance: 300,
            validateSigTAgainstCertValidity: true,
            requireCritValidation: true
        )
    }

    // MARK: - Result

    struct VerificationResult {
        let payload: Data
        let signingTime: Date
        let certificateThumbprint: String
    }

    // MARK: - Public Methods

    /// x5cヘッダーから証明書を取得して検証
    static func verifyJAdES(
        jwt: String,
        options: VerificationOptions = .default
    ) -> Result<VerificationResult, JAdESVerificationError>

    /// 外部から提供された証明書で検証 (TrustedList用)
    static func verifyJAdES(
        jwt: String,
        signingCertificate: SecCertificate,
        options: VerificationOptions = .default
    ) -> Result<VerificationResult, JAdESVerificationError>
}
```

### 検証ロジック

#### 1. sigT (Signing Time) 検証

```swift
private static func validateSigT(
    header: [String: Any],
    certificate: Certificate?,
    options: VerificationOptions
) -> Result<Date, JAdESVerificationError> {
    // 1. 存在確認
    guard let sigTString = header["sigT"] as? String else {
        return .failure(.sigTMissing)
    }

    // 2. ISO 8601 パース
    guard let sigT = sigTString.toDateFromISO8601() else {
        return .failure(.sigTInvalidFormat(sigTString))
    }

    // 3. 未来日時チェック (5分の許容)
    let now = Date()
    let maxAllowedTime = now.addingTimeInterval(options.clockSkewTolerance)
    if sigT > maxAllowedTime {
        return .failure(.sigTInFuture(sigT: sigT, now: now, tolerance: options.clockSkewTolerance))
    }

    // 4. 証明書有効期間チェック (オプション)
    if options.validateSigTAgainstCertValidity, let cert = certificate {
        let notBefore = cert.notValidBefore
        let notAfter = cert.notValidAfter
        if sigT < notBefore || sigT > notAfter {
            return .failure(.sigTOutsideCertificateValidity(
                sigT: sigT, notBefore: notBefore, notAfter: notAfter
            ))
        }
    }

    return .success(sigT)
}
```

#### 2. x5t#S256 (Certificate Thumbprint) 検証

```swift
private static func validateX5tS256(
    header: [String: Any],
    certificate: SecCertificate
) -> Result<String, JAdESVerificationError> {
    // 1. 存在確認
    guard let expectedThumbprint = header["x5t#S256"] as? String else {
        return .failure(.x5tS256Missing)
    }

    // 2. 証明書のSHA-256サムプリント計算
    let derData = SecCertificateCopyData(certificate) as Data
    let hash = SHA256.hash(data: derData)
    let actualThumbprint = Data(hash).base64URLEncodedString()

    // 3. 比較
    if actualThumbprint != expectedThumbprint {
        return .failure(.x5tS256Mismatch(expected: expectedThumbprint, actual: actualThumbprint))
    }

    return .success(actualThumbprint)
}
```

### TrustedListManager 統合

```swift
// TrustedListError に追加
case signatureVerificationFailed(JAdESSignatureVerifier.JAdESVerificationError)

// fetchTrustedList() 内で検証
if let responseString = String(data: data, encoding: .utf8),
   responseString.hasPrefix("eyJ") {
    print("🔐 [TrustedList] Detected JWT format, verifying JAdES signature...")

    let result = JAdESSignatureVerifier.verifyJAdES(
        jwt: responseString,
        options: .default
    )

    switch result {
    case .success(let verificationResult):
        print("🔐 [TrustedList] ✓ JAdES signature verified")
        print("🔐 [TrustedList]   Signing time: \(verificationResult.signingTime)")
        jsonData = verificationResult.payload

    case .failure(let error):
        print("🔐 [TrustedList] ❌ JAdES verification failed: \(error)")
        throw TrustedListError.signatureVerificationFailed(error)
    }
}
```

## 再利用する既存コード

| 既存コード | ファイル | 用途 |
|-----------|---------|------|
| `String.toDateFromISO8601()` | DateFormatterUtil.swift | sigTのISO 8601パース |
| `calculateX509CertificateHash()` | CertificateUtil.swift | 証明書サムプリント計算パターン |
| `JWTOperations.verifyJwt()` | JWTOperations.swift | JWT署名検証 |
| `JWTOperations.decodeJwt()` | JWTOperations.swift | JWTヘッダー・ペイロード取得 |

## 実装済みテストケース

### JAdESSignatureVerifierTests.swift (14テスト)

#### sigT (Signing Time) 検証テスト

| テストケース | 説明 | 期待結果 |
|------------|------|---------|
| `testSigT_WhenMissing_ReturnsError` | sigTヘッダーが存在しない場合 | `sigTMissing` エラー |
| `testSigT_WhenInvalidFormat_ReturnsError` | sigTが不正なフォーマットの場合 | `sigTInvalidFormat` エラー |
| `testSigT_WhenInFuture_ReturnsError` | sigTが未来日時（許容範囲外）の場合 | `sigTInFuture` エラー |
| `testSigT_WhenWithinTolerance_Succeeds` | sigTが許容範囲内（5分以内）の未来日時の場合 | 成功 |
| `testSigT_WhenOutsideCertValidity_ReturnsError` | sigTが証明書有効期間外の場合 | `sigTOutsideCertificateValidity` エラー |

#### x5t#S256 (Certificate Thumbprint) 検証テスト

| テストケース | 説明 | 期待結果 |
|------------|------|---------|
| `testX5tS256_WhenMissing_ReturnsError` | x5t#S256ヘッダーが存在しない場合 | `x5tS256Missing` エラー |
| `testX5tS256_WhenMismatch_ReturnsError` | x5t#S256が実際の証明書ハッシュと一致しない場合 | `x5tS256Mismatch` エラー |
| `testX5tS256_WhenValid_Succeeds` | x5t#S256が正しい場合 | 成功 |

#### 署名検証テスト

| テストケース | 説明 | 期待結果 |
|------------|------|---------|
| `testSignature_WhenValid_Succeeds` | 有効な署名の場合 | 成功 |
| `testSignature_WhenTampered_ReturnsError` | 署名が改竄された場合 | `signatureVerificationFailed` エラー |

#### crit (Critical Header) 検証テスト

| テストケース | 説明 | 期待結果 |
|------------|------|---------|
| `testCrit_WhenUnprocessedHeader_ReturnsError` | critに未対応のヘッダーが含まれる場合 | `criticalHeaderNotProcessed` エラー |

#### 統合テスト

| テストケース | 説明 | 期待結果 |
|------------|------|---------|
| `testFullJAdESVerification_WithValidJwt_Succeeds` | x5cヘッダーから証明書を取得して検証 | 成功 |

#### オプション設定テスト

| テストケース | 説明 | 期待結果 |
|------------|------|---------|
| `testOptions_LenientMode_AcceptsLargerSkew` | lenientオプションで許容範囲拡大（10分） | 8分の未来日時でも成功 |
| `testOptions_DisableCertValidityCheck` | 証明書有効期間チェック無効化 | 期限切れ証明書でも成功 |

### テスト実行結果

```
JAdESSignatureVerifierTests: 14/14 passed ✅
TrustedListManagerTests: 11/11 passed ✅
```

## 関連ファイル

- `tw2023_wallet/Signature/JWTOperations.swift`
- `tw2023_wallet/Signature/X509CertificateOperations.swift`
- `tw2023_wallet/Utils/CertificateUtil.swift`
- `tw2023_wallet/Helper/DateFormatterUtil.swift`
- `tw2023_wallet/Services/TrustedList/TrustedListManager.swift`

## 参考

- [ETSI TS 119 182-1](https://www.etsi.org/deliver/etsi_ts/119100_119199/11918201/01.01.01_60/ts_11918201v010101p.pdf) - JAdES digital signatures
- [ETSI TS 119 602](https://www.etsi.org/deliver/etsi_ts/119600_119699/119602/01.01.01_60/ts_119602v010101p.pdf) - Trusted Lists
- [RFC 7515](https://tools.ietf.org/html/rfc7515) - JSON Web Signature (JWS)
