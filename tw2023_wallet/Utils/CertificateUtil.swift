//
//  CertificateUtil.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2023/12/26.
//

import ASN1Decoder
import CryptoKit
import Foundation
import Security
import SwiftASN1
import X509

class CertificateHandler: NSObject, URLSessionDelegate {
    var certificateChainResult: [X509Certificate?] = []  // Property to store certificate chain
    var pemCertificateChainResult: [String?] = []  // PEM形式の証明書チェーン
    var derCertificateChainResult: [Data?] = []  // DER形式の証明書チェーン

    let semaphore = DispatchSemaphore(value: 0)

    func urlSession(
        _ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        print("urlSession start")
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
            let serverTrust = challenge.protectionSpace.serverTrust
        {
            var certificateChain: [SecCertificate] = []

            if let certificateRefs = SecTrustCopyCertificateChain(serverTrust) {
                for i in 0..<CFArrayGetCount(certificateRefs) {
                    if let certificateRef = CFArrayGetValueAtIndex(certificateRefs, i) {
                        let unmanagedCertificate = Unmanaged<SecCertificate>.fromOpaque(
                            certificateRef)
                        let certificate = unmanagedCertificate.takeUnretainedValue()
                        certificateChain.append(certificate)
                    }
                }
            }

            for certificate in certificateChain {
                // certificate der bytes
                var certificateDerData = Data()
                certificateDerData.append(SecCertificateCopyData(certificate) as Data)
                do {
                    certificateChainResult.append(try X509Certificate(data: certificateDerData))
                    // X509Certificateに変換できたデータだけと加える
                    derCertificateChainResult.append(certificateDerData)
                    let pemFormat = convertToPEM(derData: certificateDerData)
                    pemCertificateChainResult.append(pemFormat)
                }
                catch {
                    certificateChainResult.append(nil)
                    derCertificateChainResult.append(nil)
                    pemCertificateChainResult.append(nil)
                }
            }
        }
        semaphore.signal()
        completionHandler(.performDefaultHandling, nil)
        print("urlSession end")
    }

    private func convertToPEM(derData: Data) -> String {
        let base64String = derData.base64EncodedString(options: [
            .lineLength64Characters, .endLineWithLineFeed,
        ])
        return "-----BEGIN CERTIFICATE-----\n\(base64String)\n-----END CERTIFICATE-----\n"
    }
}

// struct CertificateInfo {
//    let domain: String?
//    let organization: String?
//    let locality: String?
//    let state: String?
//    let country: String?
//    let cert: CertificateInfo?
//
//    func getFullAddress() -> String {
//        let addressParts = [locality, state, country].compactMap { $0 }
//        return addressParts.joined(separator: ", ")
//    }
//}
class CertificateInfo: Codable {
    let domain: String?
    let organization: String?
    let locality: String?
    let state: String?
    let country: String?
    let street: String?
    let email: String?
    var issuer: CertificateInfo?

    init(
        domain: String?, organization: String?, locality: String?, state: String?, country: String?,
        street: String?, email: String?, issuer: CertificateInfo?
    ) {
        self.domain = domain
        self.organization = organization
        self.locality = locality
        self.state = state
        self.country = country
        self.street = street
        self.email = email
        self.issuer = issuer
    }

    func getFullAddress() -> String {
        let addressParts = [locality, state, country].compactMap { $0 }
        return addressParts.joined(separator: ", ")
    }
}

func extractFirstCertSubject(url: String) -> (CertificateInfo?, [Data?]) {
    let (certificateChain, certificateDerChain) = extractCertificateChain(url: url)
    if certificateChain.isEmpty {
        return (nil, [])
    }

    guard let firstCertificate = certificateChain[0] else {
        return (nil, [])
    }
    let issuer = issuerCertificateInfo(certificate: firstCertificate)
    return (
        x509Certificate2CertificateInfo(firstCertificate: firstCertificate, issuer: issuer),
        certificateDerChain
    )
}

func x509Certificate2CertificateInfo(
    firstCertificate: X509Certificate, issuer: CertificateInfo? = nil
) -> CertificateInfo {
    // TODO: Subject Alt Nameから取得する必要がある。
    // 2.5.4.3はdeprecated
    let domain = firstCertificate.subject(oidString: "2.5.4.3")?.joined(separator: " ")
    let organization = firstCertificate.subject(oidString: "2.5.4.10")?.joined(separator: " ")
    let locality = firstCertificate.subject(oidString: "2.5.4.7")?.joined(separator: " ")
    let state = firstCertificate.subject(oidString: "2.5.4.8")?.joined(separator: " ")
    let country = firstCertificate.subject(oidString: "2.5.4.6")?.joined(separator: " ")
    let street = firstCertificate.subject(oidString: "2.5.4.9")?.joined(separator: " ")
    let email = firstCertificate.subject(oidString: "1.2.840.113549.1.9.1")?.joined(separator: " ")

    return CertificateInfo(
        domain: domain, organization: organization, locality: locality, state: state,
        country: country, street: street, email: email, issuer: issuer)
}

func issuerCertificateInfo(certificate: X509Certificate) -> CertificateInfo? {
    guard certificate.issuerDistinguishedName != nil else {
        return nil
    }

    let domain = certificate.issuer(oidString: "2.5.4.3")
    let organization = certificate.issuer(oidString: "2.5.4.10")
    let locality = certificate.issuer(oidString: "2.5.4.7")
    let state = certificate.issuer(oidString: "2.5.4.8")
    let country = certificate.issuer(oidString: "2.5.4.6")
    let street = certificate.issuer(oidString: "2.5.4.9")
    let email = certificate.issuer(oidString: "1.2.840.113549.1.9.1")

    return CertificateInfo(
        domain: domain, organization: organization, locality: locality, state: state,
        country: country, street: street, email: email, issuer: nil)
}

func x509Certificate2CertificateInfo(pemData: Data) -> CertificateInfo {
    let certificate = try! X509Certificate(data: pemData)
    // 発行者（issuer）の情報を取得
    let issuerCertInfo = issuerCertificateInfo(certificate: certificate)
    // 被発行者（subject）の情報を取得
    let subjectCertInfo = x509Certificate2CertificateInfo(
        firstCertificate: certificate, issuer: issuerCertInfo)
    return subjectCertInfo
}

func extractCertificateInfo(from distinguishedName: String) -> CertificateInfo {
    var domain: String?
    var organization: String?
    var locality: String?
    var state: String?
    var country: String?
    var street: String?
    var email: String?

    let subjectParts = distinguishedName.split(separator: ",")

    for part in subjectParts {
        let trimmedPart = part.trimmingCharacters(in: .whitespaces)
        switch trimmedPart {
            case let value where value.hasPrefix("CN="):
                domain = String(value.dropFirst("CN=".count))
            case let value where value.hasPrefix("O="):
                organization = String(value.dropFirst("O=".count))
            case let value where value.hasPrefix("L="):
                locality = String(value.dropFirst("L=".count))
            case let value where value.hasPrefix("ST="):
                state = String(value.dropFirst("ST=".count))
            case let value where value.hasPrefix("C="):
                country = String(value.dropFirst("C=".count))
            case let value where value.hasPrefix("STREET="):
                street = String(value.dropFirst("STREET=".count))
            case let value where value.hasPrefix("E="):
                email = String(value.dropFirst("E=".count))
            default:
                break
        }
    }

    return CertificateInfo(
        domain: domain, organization: organization, locality: locality, state: state,
        country: country, street: street, email: email, issuer: nil)
}

func extractIssuerAndSubject(from certificateDescription: String) -> (
    issuer: String, subject: String
) {
    let issuerRegex = try! NSRegularExpression(pattern: "issuer: \"(.*?)\",", options: [])
    let subjectRegex = try! NSRegularExpression(pattern: "subject: \"(.*?)\",", options: [])

    let issuerMatch = issuerRegex.firstMatch(
        in: certificateDescription,
        range: NSRange(certificateDescription.startIndex..., in: certificateDescription))
    let subjectMatch = subjectRegex.firstMatch(
        in: certificateDescription,
        range: NSRange(certificateDescription.startIndex..., in: certificateDescription))

    let issuer =
        issuerMatch.map {
            String(certificateDescription[Range($0.range, in: certificateDescription)!])
        } ?? ""
    let subject =
        subjectMatch.map {
            String(certificateDescription[Range($0.range, in: certificateDescription)!])
        } ?? ""

    return (issuer, subject)
}

func certificate2CertificateInfo(from cert: Certificate) -> CertificateInfo {
    let certificateDescription = String(describing: cert)
    let (issuer, subject) = extractIssuerAndSubject(from: certificateDescription)
    let iss = extractCertificateInfo(from: issuer)
    let sub = extractCertificateInfo(from: subject)
    sub.issuer = iss
    return sub
}

func extractCertificateChain(url: String) -> ([X509Certificate?], [Data?]) {
    let timeout_in_second: Double = 3
    var extractedCertificates: [X509Certificate?] = []
    var extractedDerCertificates: [Data?] = []

    let targetURL = URL(string: url)!
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = timeout_in_second
    configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
    let certificateHandler = CertificateHandler()
    let session = URLSession(
        configuration: configuration, delegate: certificateHandler, delegateQueue: nil)

    // This is an asynchronous operation
    let task = session.dataTask(with: targetURL) { _, _, _ in
        // After the completion of the URLSession task,
        // certificateHandler.certificateChainResult will contain the certificate chain

        // Fetch the certificate chain from the CertificateHandler instance
        //        extractedCertificates = certificateHandler.certificateChainResult
        //        extractedDerCertificates = certificateHandler.derCertificateChainResult
    }
    task.resume()
    certificateHandler.semaphore.wait()
    extractedCertificates = certificateHandler.certificateChainResult
    extractedDerCertificates = certificateHandler.derCertificateChainResult

    return (extractedCertificates, extractedDerCertificates)
}

func createDistinguishedName(
    commonName: String, organizationName: String, localityName: String, stateOrProvinceName: String,
    countryName: String
) throws -> DistinguishedName {
    let distinguishedName = try DistinguishedName {
        CommonName(commonName)
        OrganizationName(organizationName)
        LocalityName(localityName)
        StateOrProvinceName(stateOrProvinceName)
        CountryName(countryName)
    }
    return distinguishedName
}

func generateCertificate(
    subjectKey: Certificate.PublicKey,
    subjectDistinguishedName: DistinguishedName,
    issuerKey: Certificate.PrivateKey,
    issuerDistinguishedName: DistinguishedName,
    notBefore: Date,
    notAfter: Date,
    isCa: Bool,
    subjectAlternativeName: [String] = []
) -> Certificate? {
    do {

        let serialNumberValue = UInt64(Date().timeIntervalSince1970)
        let serialNumber = Certificate.SerialNumber(serialNumberValue)

        let ca =
            if isCa {
                BasicConstraints.isCertificateAuthority(maxPathLength: nil)
            }
            else {
                BasicConstraints.notCertificateAuthority
            }
        let exKeyUsage = try ExtendedKeyUsage([.serverAuth, .clientAuth])
        let san = SubjectAlternativeNames(subjectAlternativeName.map { .dnsName($0) })
        let extentions = try Certificate.Extensions {
            exKeyUsage
            Critical(ca)
            san
        }

        // https://swiftpackageindex.com/apple/swift-certificates/main/documentation/x509/certificate
        let cert = try Certificate(
            version: Certificate.Version.v3,
            serialNumber: serialNumber,
            publicKey: subjectKey,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: issuerDistinguishedName,
            subject: subjectDistinguishedName,
            signatureAlgorithm: Certificate.SignatureAlgorithm.ecdsaWithSHA256,
            extensions: extentions,
            issuerPrivateKey: issuerKey
        )
        return cert
    }
    catch {
        print("Error creating Certificate: \(error)")
        return nil
    }
}

/// Calculate SHA-256 hash of X.509 certificate (Base64URL encoded)
/// Used for x509_hash Client Identifier Prefix in OID4VP 1.0
func calculateX509CertificateHash(_ certificate: Certificate) -> String? {
    do {
        // Get DER-encoded certificate data
        var serializer = DER.Serializer()
        try serializer.serialize(certificate)
        let derData = Data(serializer.serializedBytes)

        // Calculate SHA-256 hash using CryptoKit
        let hash = SHA256.hash(data: derData)

        // Base64URL encode (no padding)
        let base64 = Data(hash).base64EncodedString()
        let base64Url = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")

        return base64Url
    } catch {
        print("Error calculating certificate hash: \(error)")
        return nil
    }
}

func isDomainInSAN(certificate: Certificate, domain: String) -> Bool {
    // SubjectAlternativeNames を取得
    do {
        guard let sanExtension = try certificate.extensions.subjectAlternativeNames else {
            return false
        }

        // SAN のエントリをチェック
        for name in sanExtension {
            switch name {
                case .dnsName(let sanDomain):
                    if sanDomain == domain {
                        return true
                    }
                default:
                    continue
            }
        }

        return false
    }
    catch {
        return false
    }
}

// MARK: - x509_hash Client ID Validation

/// Result of x509_hash client_id validation
enum X509HashValidationResult {
    case success
    case invalidPrefix
    case noCertificates
    case hashCalculationFailed
    case hashMismatch(expected: String, actual: String)

    var errorMessage: String? {
        switch self {
        case .success:
            return nil
        case .invalidPrefix:
            return "client_id does not have x509_hash prefix"
        case .noCertificates:
            return "No certificates provided for validation"
        case .hashCalculationFailed:
            return "Failed to calculate certificate hash"
        case .hashMismatch(let expected, let actual):
            return "Certificate hash does not match client_id: expected \(expected), got \(actual)"
        }
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Validates x509_hash Client Identifier Prefix per OID4VP 1.0 specification
/// - Parameters:
///   - clientId: The client_id with x509_hash prefix (e.g., "x509_hash:Uvo3Htu...")
///   - certificates: Certificate chain from JWT x5c header (first certificate is leaf)
/// - Returns: Validation result indicating success or specific failure reason
func validateX509HashClientId(clientId: String, certificates: [Certificate]) -> X509HashValidationResult {
    // Check prefix
    guard clientId.hasPrefix("x509_hash:") else {
        return .invalidPrefix
    }

    // Check certificates exist
    guard !certificates.isEmpty else {
        return .noCertificates
    }

    // Extract expected hash from client_id
    let expectedHash = String(clientId.dropFirst("x509_hash:".count))

    // Calculate actual hash from leaf certificate
    guard let actualHash = calculateX509CertificateHash(certificates[0]) else {
        return .hashCalculationFailed
    }

    // Compare hashes
    if actualHash == expectedHash {
        return .success
    } else {
        return .hashMismatch(expected: expectedHash, actual: actualHash)
    }
}

// MARK: - Extract CertificateInfo from JWT x5c

/// Extract first dnsName from certificate's Subject Alternative Names
/// - Parameter certificate: X509.Certificate from swift-certificates
/// - Returns: First dnsName found in SAN, or nil if not found
func extractDnsNameFromSAN(certificate: Certificate) -> String? {
    do {
        guard let sanExtension = try certificate.extensions.subjectAlternativeNames else {
            return nil
        }
        for name in sanExtension {
            switch name {
            case .dnsName(let dnsName):
                return dnsName
            default:
                continue
            }
        }
        return nil
    } catch {
        return nil
    }
}

/// Extract CertificateInfo from JWT's x5c header
/// - Parameter jwt: JWT string containing x5c header
/// - Returns: CertificateInfo from the leaf certificate, or nil if extraction fails
func extractCertificateInfoFromJwt(jwt: String) -> CertificateInfo? {
    // Decode JWT to get header
    guard let (header, _, _) = try? JWTUtil.decodeJwt(jwt: jwt),
          let x5c = header["x5c"] as? [String],
          !x5c.isEmpty
    else {
        return nil
    }

    // Convert first (leaf) certificate from base64 to X509Certificate (ASN1Decoder)
    guard let certData = Data(base64Encoded: x5c[0]),
          let x509Cert = try? X509Certificate(data: certData)
    else {
        return nil
    }

    // Extract issuer info
    let issuer = issuerCertificateInfo(certificate: x509Cert)

    // Extract subject info
    var certInfo = x509Certificate2CertificateInfo(firstCertificate: x509Cert, issuer: issuer)

    // Try to get dnsName from SAN using swift-certificates
    if let certificates = try? SignatureUtil.convertPemToX509Certificates(pemChain: x5c),
       let firstCert = certificates.first {
        if let dnsName = extractDnsNameFromSAN(certificate: firstCert) {
            // Override domain with SAN dnsName if available
            certInfo = CertificateInfo(
                domain: dnsName,
                organization: certInfo.organization,
                locality: certInfo.locality,
                state: certInfo.state,
                country: certInfo.country,
                street: certInfo.street,
                email: certInfo.email,
                issuer: certInfo.issuer
            )
        }
    }

    return certInfo
}
