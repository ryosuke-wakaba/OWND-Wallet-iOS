//
//  KeyBindingImpl.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2024/01/13.
//

import CommonCrypto
import Foundation

enum KeyBindingImplError: Error {
    case UnexpectedDisclosureValue
    case UnsupportedHashAlgorithm(String)
}

class KeyBindingImpl: KeyBinding {
    private let keyAlias: String

    init(keyAlias: String) {
        self.keyAlias = keyAlias
    }
    func generateJwt(
        sdJwt: String,
        selectedDisclosures: [Disclosure],
        aud: String,
        nonce: String,
        sdAlg: String
    ) throws -> String {
        // Validate _sd_alg - currently only sha-256 is supported
        // Per SD-JWT spec, _sd_alg is case-sensitive and must match IANA registry exactly
        guard sdAlg == "sha-256" else {
            throw KeyBindingImplError.UnsupportedHashAlgorithm(sdAlg)
        }

        let parts = sdJwt.split(separator: "~").map(String.init)
        let issuerSignedJwt = parts[0]

        let hasNilValue = selectedDisclosures.contains { disclosure in
            disclosure.disclosure == nil
        }

        if hasNilValue {
            throw KeyBindingImplError.UnexpectedDisclosureValue
        }

        let sd =
            issuerSignedJwt + "~"
            + selectedDisclosures.map { $0.disclosure! }.joined(separator: "~") + "~"

        print("[KeyBinding] SD string for hash (first 500 chars): \(String(sd.prefix(500)))")
        print("[KeyBinding] SD string length: \(sd.count)")
        print("[KeyBinding] Number of disclosures: \(selectedDisclosures.count)")

        // Use UTF-8 encoding instead of ASCII to handle all characters
        guard let sdData = sd.data(using: .utf8) else {
            print("[KeyBinding] ERROR: Failed to convert SD string to UTF-8 data")
            throw KeyBindingImplError.UnexpectedDisclosureValue
        }
        let sdHash = sdData.sha256ToBase64Url()
        print("[KeyBinding] Calculated sd_hash: \(sdHash)")
        let header = ["typ": "kb+jwt", "alg": "ES256"]
        let payload: [String: Any] = [
            "aud": aud,
            "iat": Int(Date().timeIntervalSince1970),
            "sd_hash": sdHash,  // Note: no underscore prefix per SD-JWT spec for KB-JWT
            "nonce": nonce,
        ]
        let result = JWTOperations.sign(keyAlias: keyAlias, header: header, payload: payload)
        switch result {
            case let .success(jwt):
                return jwt
            case let .failure(error):
                throw error
        }
    }
}

extension Data {
    func sha256ToBase64Url() -> String {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        self.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(self.count), &hash)
        }
        return Data(hash).base64URLEncodedString()
    }
}
