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
    ///   - verifyCertChain: 証明書チェーン検証を行うかどうか
    /// - Returns: 検証済みJWTと証明書、またはエラー
    static func verifyJwtWithX5C(
        jwt: String,
        issuerURL: String?,
        verifyCertChain: Bool = true
    ) async -> Result<VerifiedX5CJwt, JWTVerificationError> {
        // 1. JWTをデコード
        guard let decodedJwt = try? decode(jwt: jwt) else {
            print("🔐 [X5CJWTVerifier] Failed to decode JWT")
            return .failure(.verificationFailed("Unable to decode jwt"))
        }
        print("🔐 [X5CJWTVerifier] JWT decoded, header keys: \(decodedJwt.header.keys)")

        // 2. x5cヘッダーを取得
        guard let x5c = decodedJwt.header["x5c"] as? [String] else {
            print("🔐 [X5CJWTVerifier] x5c not found in header")
            return .failure(.verificationFailed("Unable to get x5c property"))
        }
        print("🔐 [X5CJWTVerifier] x5c found, count: \(x5c.count)")

        // 3. x5cからX509証明書に変換
        let certificates: [Certificate]
        do {
            certificates = try SignatureUtil.convertPemToX509Certificates(pemChain: x5c)
        } catch let error as SignatureUtilError {
            print("🔐 [X5CJWTVerifier] Failed to convert x5c to certificates: \(error.localizedDescription)")
            return .failure(.verificationFailed(error.localizedDescription))
        } catch {
            print("🔐 [X5CJWTVerifier] Failed to convert x5c to certificates: \(error)")
            return .failure(.verificationFailed("Unable to convert x5c: \(error.localizedDescription)"))
        }
        print("🔐 [X5CJWTVerifier] Certificates converted: \(certificates.count)")

        // 4. 最初の証明書から公開鍵を抽出
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

        // 5. JWTの署名を検証（JWTUtilを使用）
        let jwtValidation = JWTUtil.verifyJwt(jwt: jwt, publicKey: secKey)
        print("🔐 [X5CJWTVerifier] JWT signature validation result: \(jwtValidation)")

        guard case .success = jwtValidation else {
            return .failure(.verificationFailed("Unable to verify jwt"))
        }

        // 6. 証明書チェーン検証（オプション）
        if verifyCertChain {
            let chainValidationResult = await validateCertificateChain(
                certificates: certificates,
                issuerURL: issuerURL
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
    static func verifyJwtWithX5U(jwt: String) -> Result<JWT, JWTVerificationError> {
        // 1. JWTをデコード
        guard let decodedJwt = try? decode(jwt: jwt) else {
            return .failure(.verificationFailed("Unable to decode jwt"))
        }

        // 2. x5uヘッダーからURLを取得
        guard let x5uUrl = decodedJwt.header["x5u"] as? String else {
            return .failure(.verificationFailed("Unable to get x5u url"))
        }
        print("x5u url: \(x5uUrl)")

        // 3. URLから証明書を取得
        guard let certificates = SignatureUtil.getX509CertificatesFromUrl(url: x5uUrl) else {
            return .failure(.verificationFailed("Unable to get x5u"))
        }

        // 4. 最初の証明書から公開鍵を抽出
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

        // 5. 証明書をSecCertificateに変換
        let secCertificates: [SecCertificate] = certificates.compactMap { cert in
            let pem = try? cert.serializeAsPEM()
            guard let derData = pem.map({ Data($0.derBytes) }) else { return nil }
            return SecCertificateCreateWithData(nil, derData as CFData)
        }

        guard secCertificates.count == certificates.count else {
            return .failure(.verificationFailed("Unable to convert certificates"))
        }

        // 6. 証明書チェーン検証（SignatureUtilを使用）
        let chainValidation = SignatureUtil.validateCertificateChainWithCustomAnchors(
            certificates: secCertificates
        )

        switch chainValidation {
        case .success:
            break
        case .failure(let certError):
            return .failure(.certificateValidationFailed(certError))
        }

        // 7. JWT署名検証（JWTUtilを使用）
        let jwtValidation = JWTUtil.verifyJwt(jwt: jwt, publicKey: secKey)
        if case .success = jwtValidation {
            return .success(decodedJwt)
        }

        return .failure(.verificationFailed("Unable to verify jwt"))
    }

    // MARK: - Private Methods

    /// 証明書チェーン検証
    private static func validateCertificateChain(
        certificates: [Certificate],
        issuerURL: String?
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
        if let issuerURL = issuerURL {
            print("🔐 [X5CJWTVerifier] ========== Using TrustedList for issuer: \(issuerURL) ==========")
            do {
                let additionalCerts = try await TrustedListManager.shared.getCertificates(
                    forIssuerURL: issuerURL
                )
                trustAnchorManager = TrustAnchorManager.createInstance(
                    withAdditionalCertificates: additionalCerts
                )
            } catch {
                print("🔐 [X5CJWTVerifier] ⚠️ TrustedList lookup failed: \(error). Using singleton.")
                trustAnchorManager = TrustAnchorManager.shared
            }
        } else {
            print("🔐 [X5CJWTVerifier] No issuerURL provided, using singleton TrustAnchorManager")
            trustAnchorManager = TrustAnchorManager.shared
        }

        // 証明書チェーン検証（SignatureUtilを使用）
        let chainValidation = SignatureUtil.validateCertificateChainWithCustomAnchors(
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
