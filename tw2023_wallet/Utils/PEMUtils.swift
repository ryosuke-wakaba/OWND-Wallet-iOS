//
//  PEMUtils.swift
//  tw2023_wallet
//
//  Utilities for loading PEM-encoded keys and certificates from bundled files.
//

import CryptoKit
import Foundation
import Security

enum PEMUtils {

    enum PEMError: Error, LocalizedError {
        case fileNotFound(String)
        case invalidPEMFormat
        case keyCreationFailed
        case certificateCreationFailed
        case unsupportedKeyFormat

        var errorDescription: String? {
            switch self {
            case .fileNotFound(let filename):
                return "PEM file not found: \(filename)"
            case .invalidPEMFormat:
                return "Invalid PEM format"
            case .keyCreationFailed:
                return "Failed to create key from PEM data"
            case .certificateCreationFailed:
                return "Failed to create certificate from PEM data"
            case .unsupportedKeyFormat:
                return "Unsupported key format"
            }
        }
    }

    // MARK: - Private Key Loading

    /// Load private key from bundled PEM file
    /// - Parameter filename: Name of the PEM file (without extension)
    /// - Returns: SecKey private key
    static func loadPrivateKey(filename: String) throws -> SecKey {
        let pemString = try loadPEMFile(filename: filename)
        return try createPrivateKey(fromPEM: pemString)
    }

    /// Create SecKey from PEM-encoded private key string
    /// Supports both PKCS#8 (-----BEGIN PRIVATE KEY-----) and SEC1 (-----BEGIN EC PRIVATE KEY-----) formats
    /// - Parameter pem: PEM-encoded private key string
    /// - Returns: SecKey private key
    static func createPrivateKey(fromPEM pem: String) throws -> SecKey {
        // Use CryptoKit to parse the PEM, which handles both PKCS#8 and SEC1 formats
        let p256PrivateKey: P256.Signing.PrivateKey

        do {
            p256PrivateKey = try P256.Signing.PrivateKey(pemRepresentation: pem)
        } catch {
            print("[PEMUtils] CryptoKit failed to parse PEM: \(error)")
            throw PEMError.invalidPEMFormat
        }

        // Convert CryptoKit key to SecKey using x963 representation
        // x963 format: 04 || x || y || d (65 bytes for public + 32 bytes for private = 97 bytes for P-256)
        let x963Data = p256PrivateKey.x963Representation

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPrivate,
            kSecAttrKeySizeInBits as String: 256,
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateWithData(x963Data as CFData, attributes as CFDictionary, &error) else {
            print("[PEMUtils] Failed to create SecKey from x963 data: \(error?.takeRetainedValue().localizedDescription ?? "unknown")")
            throw PEMError.keyCreationFailed
        }

        print("[PEMUtils] Successfully loaded EC P-256 private key")
        return privateKey
    }

    // MARK: - Certificate Loading

    /// Load certificate from bundled PEM file
    /// - Parameter filename: Name of the PEM file (without extension)
    /// - Returns: SecCertificate
    static func loadCertificate(filename: String) throws -> SecCertificate {
        let pemString = try loadPEMFile(filename: filename)
        return try createCertificate(fromPEM: pemString)
    }

    /// Create SecCertificate from PEM-encoded certificate string
    /// - Parameter pem: PEM-encoded certificate string
    /// - Returns: SecCertificate
    static func createCertificate(fromPEM pem: String) throws -> SecCertificate {
        let base64Content = try extractBase64Content(
            from: pem,
            beginMarker: "-----BEGIN CERTIFICATE-----",
            endMarker: "-----END CERTIFICATE-----"
        )

        guard let certData = Data(base64Encoded: base64Content) else {
            throw PEMError.invalidPEMFormat
        }

        guard let certificate = SecCertificateCreateWithData(nil, certData as CFData) else {
            throw PEMError.certificateCreationFailed
        }

        return certificate
    }

    /// Get certificate chain as base64 strings for x5c header
    /// - Parameter filename: Name of the file containing certificate(s)
    /// - Parameter extension: File extension (default: "cer")
    /// - Returns: Array of base64-encoded certificate strings (DER format)
    static func getCertificateChainForX5C(filename: String, extension ext: String = "cer") throws -> [String] {
        let pemString = try loadPEMFile(filename: filename, extension: ext)
        return try extractCertificateChainBase64(from: pemString)
    }

    /// Extract all certificates from PEM string as base64 DER strings
    /// - Parameter pem: PEM string potentially containing multiple certificates
    /// - Returns: Array of base64-encoded DER certificate data
    static func extractCertificateChainBase64(from pem: String) throws -> [String] {
        var certificates: [String] = []
        let beginMarker = "-----BEGIN CERTIFICATE-----"
        let endMarker = "-----END CERTIFICATE-----"

        var searchRange = pem.startIndex..<pem.endIndex

        while let beginRange = pem.range(of: beginMarker, range: searchRange),
              let endRange = pem.range(of: endMarker, range: beginRange.upperBound..<pem.endIndex) {

            let base64Content = pem[beginRange.upperBound..<endRange.lowerBound]
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\r", with: "")

            certificates.append(base64Content)
            searchRange = endRange.upperBound..<pem.endIndex
        }

        if certificates.isEmpty {
            throw PEMError.invalidPEMFormat
        }

        return certificates
    }

    // MARK: - Helper Methods

    /// Load PEM file content from bundle
    /// - Parameter filename: Name of the file (with or without extension)
    /// - Parameter extension: File extension (default: "key")
    /// - Returns: Content of the PEM file as string
    static func loadPEMFile(filename: String, extension ext: String = "key") throws -> String {
        // Remove extension if already included in filename
        var name = filename
        let extensionWithDot = ".\(ext)"
        if name.hasSuffix(extensionWithDot) {
            name = String(name.dropLast(extensionWithDot.count))
        }

        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else {
            throw PEMError.fileNotFound(filename)
        }

        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Extract base64 content from PEM format
    private static func extractBase64Content(
        from pem: String,
        beginMarker: String,
        endMarker: String,
        alternateBeginMarker: String? = nil,
        alternateEndMarker: String? = nil
    ) throws -> String {
        var effectiveBeginMarker = beginMarker
        var effectiveEndMarker = endMarker

        // Try primary markers first
        if pem.range(of: beginMarker) == nil {
            // Try alternate markers if primary not found
            if let altBegin = alternateBeginMarker, let altEnd = alternateEndMarker,
               pem.range(of: altBegin) != nil {
                effectiveBeginMarker = altBegin
                effectiveEndMarker = altEnd
            } else {
                throw PEMError.invalidPEMFormat
            }
        }

        guard let beginRange = pem.range(of: effectiveBeginMarker),
              let endRange = pem.range(of: effectiveEndMarker) else {
            throw PEMError.invalidPEMFormat
        }

        let base64Content = pem[beginRange.upperBound..<endRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\r", with: "")

        return base64Content
    }
}
