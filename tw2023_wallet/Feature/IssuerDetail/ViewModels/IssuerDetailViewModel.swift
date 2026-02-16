//
//  IssuerDetailViewModel.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2024/01/16.
//

import Foundation
import X509

@Observable
class IssuerDetailViewModel {
    var isLoading = false
    var hasLoadedData = false
    var certInfo: CertificateInfo? = nil
    var jwtIssuer: String? = nil

    func loadData(credential: Credential?) async {
        guard ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" else {
            print("now previewing")
            return
        }
        guard !hasLoadedData else { return }
        print("load data..")
        isLoading = true

        if let credential = credential {
            // Extract JWT issuer (iss claim) from credential payload
            extractJwtIssuer(credential: credential)

            do {
                try await processX509Certificate(credential: credential)
            }
            catch {
                print("Unable to interpret x.509 certificate")
            }
        }

        isLoading = false
        hasLoadedData = true
        print("done")
    }

    private func extractJwtIssuer(credential: Credential) {
        let format = credential.format
        let credentialFormat = CredentialFormat(formatString: format)

        let info: [String: Any]
        if credentialFormat?.isSDJWT == true {
            info = JWTParsingUtil.extractSDJwtInfo(credential: credential.payload, format: format)
        } else {
            info = JWTParsingUtil.extractInfoFromJwt(jwt: credential.payload, format: format)
        }

        if let iss = info["iss"] as? String, !iss.isEmpty {
            jwtIssuer = iss
        }
    }

    func respectForHeader(header: [String: Any], credential: Credential) async throws {
        // X509証明書チェーンのURLを取得
        let x5cValue = header["x5c"] as? [String]
        let x5uValue = header["x5u"] as? String

        if x5cValue != nil {
            try await certificateFromX5c(credential: credential)
        }
        else if x5uValue != nil {
            certificateFromX5u(url: x5uValue!)
        }
        else {
            // todo: X509証明書以外の発行者認証の方式に対応する
        }
    }

    func processX509Certificate(credential: Credential) async throws {
        let jwt = credential.payload

        // Check if the format is SD-JWT variant
        let credentialFormat = CredentialFormat(formatString: credential.format)
        if credentialFormat?.isSDJWT == true {
            // SDJwtUtilを使用してJWTヘッダーをデコード
            guard let header = SDJwtUtil.getDecodedJwtHeader(jwt) else {
                return
            }
            try await respectForHeader(header: header, credential: credential)
        }
        else {
            // JWTUtilを使用してJWTヘッダーをデコード
            let (header, _, _) = try! JWTOperations.decodeJwt(jwt: jwt)
            try await respectForHeader(header: header, credential: credential)
        }
    }

    func certificateFromX5u(url: String) {
        let (certificate, _) = extractFirstCertSubject(url: url)
        if let certificate = certificate {
            certInfo = certificate
            // TODO: TLS通信の中から取得した証明書の検証
            /*
        DispatchQueue.global(qos: .background).async {
                guard let certificates = X509CertificateOperations.getX509CertificatesFromUrl(url: url) else {
                    return
                }

                // SignatureUtilを使用して証明書チェーンの検証
                do {
                    if try X509CertificateOperations.validateCertificateChain(certificates: certificates) {
                        self.certInfo = certificate2CertificateInfo(from: certificates[0])
                    }
                } catch {
                    // エラー処理
                }
            }
                  */

        }
    }

    func certificateFromX5c(credential: Credential) async throws {
        let jwt = credential.payload

        // SDJwtUtilを使用してJWTヘッダーをデコード
        guard let decodedJwtHeader = SDJwtUtil.getDecodedJwtHeader(jwt),
            let certificates = SDJwtUtil.getX509CertificatesFromJwt(decodedJwtHeader)
        else {
            return
        }

        // DERデータからX509.Certificateに変換
        let pemCertificate = certificates[0].0
        let derCertificates = certificates.map { $0.1 }
        var x509Certificates: [Certificate] = []
        for derData in derCertificates {
            do {
                let cert = try Certificate(derEncoded: Array(derData))
                x509Certificates.append(cert)
            } catch {
                print("🔐 [IssuerDetail] Failed to parse DER certificate: \(error)")
                return
            }
        }

        guard let leafCertificate = x509Certificates.first else {
            print("🔐 [IssuerDetail] No leaf certificate found")
            return
        }

        // トラストリストでリーフ証明書の公開鍵が一致するサービスを検索
        let contextSearchInfos = TrustedListConfigLoader.createContextSearchInfos(
            contextName: "IssuerCertificateVerification"
        )

        if !contextSearchInfos.isEmpty {
            print("🔐 [IssuerDetail] Using TrustedList for public key verification")
            let isTrusted = await TrustedListManager.shared.isPublicKeyTrusted(
                certificate: leafCertificate,
                searchInfos: contextSearchInfos
            )

            if isTrusted {
                print("🔐 [IssuerDetail] ✅ Leaf certificate public key is trusted")
                let pemCertificateInData = pemCertificate.data(using: .ascii)
                certInfo =
                    pemCertificateInData != nil
                    ? x509Certificate2CertificateInfo(pemData: pemCertificateInData!) : nil
            } else {
                print("🔐 [IssuerDetail] ❌ Leaf certificate public key not found in trust list")
            }
        } else {
            print("🔐 [IssuerDetail] No TrustedList configured for IssuerCertificateVerification")
        }
    }
}
