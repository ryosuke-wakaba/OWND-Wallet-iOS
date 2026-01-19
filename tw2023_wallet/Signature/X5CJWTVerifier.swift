//
//  X5CJWTVerifier.swift
//  tw2023_wallet
//
//  Created on 2026/01/08.
//

import Foundation
import JWTDecode
import X509

/// X.509証明書チェーンを使用したJWT検証
/// JWTの署名検証と証明書チェーン検証を統合的に実行するラッパー層
///
/// ## 責務の分離
/// - JWTUtil: 純粋なJWT署名検証
/// - SignatureUtil: 証明書チェーン検証
/// - X5CJWTVerifier: 上記を統合してx5c/x5u検証を提供
enum X5CJWTVerifier {

    typealias VerifiedX5CJwt = (decoded: JWT, certs: [Certificate])

    /// x5cヘッダーを使用したJWT検証（署名検証 + 証明書チェーン検証）
    /// - Parameters:
    ///   - jwt: 検証対象のJWT文字列
    ///   - issuerURL: TrustedListから証明書を取得するためのIssuer URL（オプション）
    ///   - loteSearchInfos: 検索対象のLoTE情報配列
    ///   - verifyCertChain: 証明書チェーン検証を行うかどうか
    /// - Returns: 検証済みJWTと証明書、またはエラー
    static func verifyJwtWithX5C(
        jwt: String,
        issuerURL: String?,
        loteSearchInfos: [LoTESearchInfo],
        verifyCertChain: Bool = true
    ) async -> Result<VerifiedX5CJwt, JWTOperations.VerificationError> {
        // 1. JWTをデコードしてx5cを取得（JWTUtilを使用）
        let decodeResult = JWTOperations.decodeJwtWithX5C(jwt: jwt)
        guard case .success(let decoded) = decodeResult else {
            if case .failure(let error) = decodeResult {
                return .failure(error)
            }
            return .failure(.verificationFailed("Unable to decode jwt"))
        }
        let (decodedJwt, x5c) = decoded

        // 2. x5cからX509証明書に変換
        let certificates: [Certificate]
        do {
            certificates = try X509CertificateOperations.convertPemToX509Certificates(pemChain: x5c)
        } catch let error as X509CertificateError {
            print("🔐 [X5CJWTVerifier] Failed to convert x5c to certificates: \(error.localizedDescription)")
            return .failure(.verificationFailed(error.localizedDescription))
        } catch {
            print("🔐 [X5CJWTVerifier] Failed to convert x5c to certificates: \(error)")
            return .failure(.verificationFailed("Unable to convert x5c: \(error.localizedDescription)"))
        }
        print("🔐 [X5CJWTVerifier] Certificates converted: \(certificates.count)")

        // 3. 最初の証明書から公開鍵を抽出
        let firstCert = certificates[0]
        let subjectPublicKeyInfoBytes = firstCert.publicKey.subjectPublicKeyInfoBytes
        let publicKeyData = Data(subjectPublicKeyInfoBytes)
        let publicKeyCFData = publicKeyData as CFData

        var error: Unmanaged<CFError>?
        guard
            let secKey = SecKeyCreateWithData(
                publicKeyCFData,
                [
                    kSecAttrKeyType: kSecAttrKeyTypeEC,
                    kSecAttrKeyClass: kSecAttrKeyClassPublic,
                ] as CFDictionary, &error)
        else {
            print("🔐 [X5CJWTVerifier] Failed to create SecKey: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
            return .failure(.verificationFailed("Unable to Convert Public Key"))
        }
        print("🔐 [X5CJWTVerifier] SecKey created successfully")

        // 4. JWTの署名を検証（JWTUtilを使用）
        let jwtValidation = JWTOperations.verifyJwt(jwt: jwt, publicKey: secKey)
        print("🔐 [X5CJWTVerifier] JWT signature validation result: \(jwtValidation)")

        guard case .success = jwtValidation else {
            return .failure(.verificationFailed("Unable to verify jwt"))
        }

        // 5. 証明書チェーン検証（オプション）
        if verifyCertChain {
            let chainValidationResult = await validateCertificateChain(
                certificates: certificates,
                issuerURL: issuerURL,
                loteSearchInfos: loteSearchInfos
            )

            if case .failure(let certError) = chainValidationResult {
                return .failure(.certificateValidationFailed(certError))
            }
        } else {
            print("🔐 [X5CJWTVerifier] Skip ValidateCertificateChain!!!")
        }

        return .success((decodedJwt, certificates))
    }

    /// x5uヘッダーを使用したJWT検証
    /// - Parameter jwt: 検証対象のJWT文字列
    /// - Returns: 検証済みJWT、またはエラー
    static func verifyJwtWithX5U(jwt: String) -> Result<JWT, JWTOperations.VerificationError> {
        // 1. JWTをデコードしてx5uを取得（JWTUtilを使用）
        let decodeResult = JWTOperations.decodeJwtWithX5U(jwt: jwt)
        guard case .success(let decoded) = decodeResult else {
            if case .failure(let error) = decodeResult {
                return .failure(error)
            }
            return .failure(.verificationFailed("Unable to decode jwt"))
        }
        let (decodedJwt, x5uUrl) = decoded

        // 2. URLから証明書を取得
        guard let certificates = X509CertificateOperations.getX509CertificatesFromUrl(url: x5uUrl) else {
            return .failure(.verificationFailed("Unable to get x5u"))
        }

        // 3. 最初の証明書から公開鍵を抽出
        let firstCert = certificates[0]
        let subjectPublicKeyInfoBytes = firstCert.publicKey.subjectPublicKeyInfoBytes
        let publicKeyData = Data(subjectPublicKeyInfoBytes)
        let publicKeyCFData = publicKeyData as CFData

        var error: Unmanaged<CFError>?
        guard
            let secKey = SecKeyCreateWithData(
                publicKeyCFData,
                [
                    kSecAttrKeyType: kSecAttrKeyTypeEC,
                    kSecAttrKeyClass: kSecAttrKeyClassPublic,
                ] as CFDictionary, &error)
        else {
            return .failure(.verificationFailed("Unable to Convert Public Key"))
        }

        // 4. 証明書をSecCertificateに変換
        let secCertificates: [SecCertificate] = certificates.compactMap { cert in
            let pem = try? cert.serializeAsPEM()
            guard let derData = pem.map({ Data($0.derBytes) }) else { return nil }
            return SecCertificateCreateWithData(nil, derData as CFData)
        }

        guard secCertificates.count == certificates.count else {
            return .failure(.verificationFailed("Unable to convert certificates"))
        }

        // 5. 証明書チェーン検証（SignatureUtilを使用）
        let chainValidation = X509CertificateOperations.validateCertificateChainWithCustomAnchors(
            certificates: secCertificates
        )

        switch chainValidation {
        case .success:
            break
        case .failure(let certError):
            return .failure(.certificateValidationFailed(certError))
        }

        // 6. JWT署名検証（JWTUtilを使用）
        let jwtValidation = JWTOperations.verifyJwt(jwt: jwt, publicKey: secKey)
        if case .success = jwtValidation {
            return .success(decodedJwt)
        }

        return .failure(.verificationFailed("Unable to verify jwt"))
    }

    // MARK: - New API (Certificate-Based Search)

    /// x5cヘッダーを使用したJWT検証（証明書ベースの発行者検索を使用）
    /// AKI/SKIまたはDN一致でトラストリストから発行者証明書を検索
    /// - Parameters:
    ///   - jwt: 検証対象のJWT文字列
    ///   - contextSearchInfos: 検索対象のコンテキスト情報配列
    ///   - verifyCertChain: 証明書チェーン検証を行うかどうか
    /// - Returns: 検証済みJWTと証明書、またはエラー
    static func verifyJwtWithX5CUsingCertificateSearch(
        jwt: String,
        contextSearchInfos: [LoTEContextSearchInfo],
        verifyCertChain: Bool = true
    ) async -> Result<VerifiedX5CJwt, JWTOperations.VerificationError> {
        // 1. JWTをデコードしてx5cを取得
        let decodeResult = JWTOperations.decodeJwtWithX5C(jwt: jwt)
        guard case .success(let decoded) = decodeResult else {
            if case .failure(let error) = decodeResult {
                return .failure(error)
            }
            return .failure(.verificationFailed("Unable to decode jwt"))
        }
        let (decodedJwt, x5c) = decoded

        // 2. x5cからX509証明書に変換
        let certificates: [Certificate]
        do {
            certificates = try X509CertificateOperations.convertPemToX509Certificates(pemChain: x5c)
        } catch let error as X509CertificateError {
            print("🔐 [X5CJWTVerifier] Failed to convert x5c to certificates: \(error.localizedDescription)")
            return .failure(.verificationFailed(error.localizedDescription))
        } catch {
            print("🔐 [X5CJWTVerifier] Failed to convert x5c to certificates: \(error)")
            return .failure(.verificationFailed("Unable to convert x5c: \(error.localizedDescription)"))
        }
        print("🔐 [X5CJWTVerifier] Certificates converted: \(certificates.count)")

        // 3. 最初の証明書から公開鍵を抽出
        let firstCert = certificates[0]
        let subjectPublicKeyInfoBytes = firstCert.publicKey.subjectPublicKeyInfoBytes
        let publicKeyData = Data(subjectPublicKeyInfoBytes)
        let publicKeyCFData = publicKeyData as CFData

        var error: Unmanaged<CFError>?
        guard
            let secKey = SecKeyCreateWithData(
                publicKeyCFData,
                [
                    kSecAttrKeyType: kSecAttrKeyTypeEC,
                    kSecAttrKeyClass: kSecAttrKeyClassPublic,
                ] as CFDictionary, &error)
        else {
            print("🔐 [X5CJWTVerifier] Failed to create SecKey: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
            return .failure(.verificationFailed("Unable to Convert Public Key"))
        }
        print("🔐 [X5CJWTVerifier] SecKey created successfully")

        // 4. JWTの署名を検証
        let jwtValidation = JWTOperations.verifyJwt(jwt: jwt, publicKey: secKey)
        print("🔐 [X5CJWTVerifier] JWT signature validation result: \(jwtValidation)")

        guard case .success = jwtValidation else {
            return .failure(.verificationFailed("Unable to verify jwt"))
        }

        // 5. 証明書チェーン検証（証明書ベースの発行者検索を使用）
        if verifyCertChain {
            let chainValidationResult = await validateCertificateChainWithCertificateSearch(
                certificates: certificates,
                contextSearchInfos: contextSearchInfos
            )

            if case .failure(let certError) = chainValidationResult {
                return .failure(.certificateValidationFailed(certError))
            }
        } else {
            print("🔐 [X5CJWTVerifier] Skip ValidateCertificateChain!!!")
        }

        return .success((decodedJwt, certificates))
    }

    /// 証明書チェーン検証（証明書ベースの発行者検索を使用）
    private static func validateCertificateChainWithCertificateSearch(
        certificates: [Certificate],
        contextSearchInfos: [LoTEContextSearchInfo]
    ) async -> Result<Void, CertificateValidationError> {
        // X509.CertificateをSecCertificateに変換
        let secCertificates: [SecCertificate] = certificates.compactMap { cert in
            let pem = try? cert.serializeAsPEM()
            guard let derData = pem.map({ Data($0.derBytes) }) else { return nil }
            return SecCertificateCreateWithData(nil, derData as CFData)
        }

        guard secCertificates.count == certificates.count else {
            print("🔐 [X5CJWTVerifier] Failed to convert all certificates to SecCertificate")
            return .failure(.chainIncomplete)
        }

        // TrustAnchorManagerを決定（証明書ベースの検索を使用）
        let trustAnchorManager: TrustAnchorManager
        if !contextSearchInfos.isEmpty {
            print("🔐 [X5CJWTVerifier] ========== Using Certificate-Based Search ==========")
            do {
                let additionalCerts = try await TrustedListManager.shared.getIssuerCertificatesForChain(
                    x5cCertificates: certificates,
                    searchInfos: contextSearchInfos
                )
                trustAnchorManager = TrustAnchorManager.createInstance(
                    withAdditionalCertificates: additionalCerts
                )
                print("🔐 [X5CJWTVerifier] Found \(additionalCerts.count) issuer certificate(s) from TrustedList")
            } catch {
                print("🔐 [X5CJWTVerifier] ⚠️ Certificate-based search failed: \(error). Using singleton.")
                trustAnchorManager = TrustAnchorManager.shared
            }
        } else {
            print("🔐 [X5CJWTVerifier] No contextSearchInfos provided, using singleton TrustAnchorManager")
            trustAnchorManager = TrustAnchorManager.shared
        }

        // 証明書チェーン検証
        let chainValidation = X509CertificateOperations.validateCertificateChainWithCustomAnchors(
            certificates: secCertificates,
            trustAnchorManager: trustAnchorManager
        )

        switch chainValidation {
        case .success:
            print("🔐 [X5CJWTVerifier] Certificate chain validation succeeded")
            return .success(())
        case .failure(let certError):
            print("🔐 [X5CJWTVerifier] Certificate chain validation failed: \(certError.errorDescription ?? "unknown")")
            return .failure(certError)
        }
    }

    // MARK: - Legacy Private Methods

    /// 証明書チェーン検証（レガシーAPI用）
    @available(*, deprecated, message: "Use validateCertificateChainWithCertificateSearch instead")
    private static func validateCertificateChain(
        certificates: [Certificate],
        issuerURL: String?,
        loteSearchInfos: [LoTESearchInfo]
    ) async -> Result<Void, CertificateValidationError> {
        // X509.Certificateを SecCertificateに変換
        let secCertificates: [SecCertificate] = certificates.compactMap { cert in
            let pem = try? cert.serializeAsPEM()
            guard let derData = pem.map({ Data($0.derBytes) }) else { return nil }
            return SecCertificateCreateWithData(nil, derData as CFData)
        }

        guard secCertificates.count == certificates.count else {
            print("🔐 [X5CJWTVerifier] Failed to convert all certificates to SecCertificate")
            return .failure(.chainIncomplete)
        }

        // TrustAnchorManagerを決定
        let trustAnchorManager: TrustAnchorManager
        if let issuerURL = issuerURL, !loteSearchInfos.isEmpty {
            print("🔐 [X5CJWTVerifier] ========== Using TrustedList for issuer: \(issuerURL) ==========")
            do {
                let additionalCerts = try await TrustedListManager.shared.getCertificates(
                    forServiceURL: issuerURL,
                    loteInfos: loteSearchInfos
                )
                trustAnchorManager = TrustAnchorManager.createInstance(
                    withAdditionalCertificates: additionalCerts
                )
            } catch {
                print("🔐 [X5CJWTVerifier] ⚠️ TrustedList lookup failed: \(error). Using singleton.")
                trustAnchorManager = TrustAnchorManager.shared
            }
        } else {
            print("🔐 [X5CJWTVerifier] No issuerURL or loteSearchInfos provided, using singleton TrustAnchorManager")
            trustAnchorManager = TrustAnchorManager.shared
        }

        // 証明書チェーン検証（SignatureUtilを使用）
        let chainValidation = X509CertificateOperations.validateCertificateChainWithCustomAnchors(
            certificates: secCertificates,
            trustAnchorManager: trustAnchorManager
        )

        switch chainValidation {
        case .success:
            print("🔐 [X5CJWTVerifier] Certificate chain validation succeeded")
            return .success(())
        case .failure(let certError):
            print("🔐 [X5CJWTVerifier] Certificate chain validation failed: \(certError.errorDescription ?? "unknown")")
            return .failure(certError)
        }
    }
}
