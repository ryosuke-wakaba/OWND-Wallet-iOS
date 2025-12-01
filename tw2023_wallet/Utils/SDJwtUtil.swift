//
//  SDJwtUtil.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2023/12/26.
//

import ASN1Decoder
import Foundation

struct Disclosure: Codable {
    let id: String
    let disclosure: String?
    let key: String?
    let value: String?

    init(disclosure: String?, key: String?, value: String?) {
        self.disclosure = disclosure
        self.key = key
        self.value = value

        if let disclosure = self.disclosure {
            self.id = disclosure
        }
        else {
            if let key = key, let value = value {
                self.id = "\(key)-\(value)"
            }
            else if let key = key {
                self.id = key
            }
            else if let value = value {
                self.id = value
            }
            else {
                self.id = "defaultID"
            }
        }
    }
}

func convertDisclosureValue(value: Any) -> String {
    if let boolValue = value as? Bool {
        return boolValue ? "Yes" : "No"
    }
    else if let arrayValue = value as? [Any] {
        // Convert array elements to strings and join with comma
        return arrayValue.map { convertDisclosureValue(value: $0) }.joined(separator: ", ")
    }
    else {
        return String(describing: value)
    }
}

struct SDJwtUtil {
    struct SDJwtParts {
        let issuerSignedJwt: String
        let disclosures: [String]
        let keyBindingJwt: String?
    }

    static func base64urlToBase64(base64url: String) -> String {
        var base64 =
            base64url
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        if base64.count % 4 != 0 {
            base64.append(String(repeating: "=", count: 4 - base64.count % 4))
        }
        return base64
    }

    static func divideSDJwt(sdJwt: String) throws -> SDJwtParts {
        let hasKBJWT = !sdJwt.hasSuffix("~")

        var parts = sdJwt.split(separator: "~").map { String($0) }
        guard parts.count > 0 else {
            throw NSError(
                domain: "com.example.error", code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Invalid SD-JWT: No parts found"])
        }

        let issuerSignedJwt = parts[0]
        parts.removeFirst()

        var keyBindingJwt: String?
        if hasKBJWT {
            keyBindingJwt = parts.popLast()
        }

        let disclosures = parts

        return SDJwtParts(
            issuerSignedJwt: issuerSignedJwt, disclosures: disclosures, keyBindingJwt: keyBindingJwt
        )
    }

    static func decodeDisclosure(_ disclosures: [String]) -> [Disclosure] {
        return disclosures.map { d in
            let decodedString =
                String(
                    data: Data(base64Encoded: base64urlToBase64(base64url: d)) ?? Data(),
                    encoding: .utf8) ?? ""
            guard
                let decoded = try? JSONSerialization.jsonObject(
                    with: decodedString.data(using: .utf8)!) as? [Any]
            else {
                return Disclosure(disclosure: d, key: nil, value: nil)
            }

            var key: String?
            var value: String?

            key = decoded[1] as? String
            value = convertDisclosureValue(value: decoded[2])

            return Disclosure(disclosure: d, key: key, value: value)
        }
    }

    static func decodeSDJwt(_ credential: String) throws -> [Disclosure] {
        let dividedJwt = try divideSDJwt(sdJwt: credential)
        return decodeDisclosure(dividedJwt.disclosures)
    }

    static func getDecodedJwtHeader(_ sdJwt: String) -> [String: Any]? {
        let parts = sdJwt.split(separator: "~").map { String($0) }
        let issuerJwt = parts.first
        let issuerParts = issuerJwt?.split(separator: ".").map { String($0) }
        let headerData = issuerParts?.first.flatMap {
            Data(base64Encoded: base64urlToBase64(base64url: $0))
        }
        let header = headerData.flatMap { String(data: $0, encoding: .utf8) }
        guard let headerData = header?.data(using: .utf8),
            let headerJSON = try? JSONSerialization.jsonObject(with: headerData) as? [String: Any]
        else {
            return nil
        }

        return headerJSON
    }

    /// Get the _sd_alg value from SD-JWT payload
    /// - Parameter sdJwt: SD-JWT string
    /// - Returns: _sd_alg value (defaults to "sha-256" if not present)
    static func getSdAlg(_ sdJwt: String) -> String {
        let parts = sdJwt.split(separator: "~").map { String($0) }
        guard let issuerJwt = parts.first else {
            return "sha-256"
        }

        let jwtParts = issuerJwt.split(separator: ".").map { String($0) }
        guard jwtParts.count >= 2 else {
            return "sha-256"
        }

        let payloadBase64 = jwtParts[1]
        guard let payloadData = Data(base64Encoded: base64urlToBase64(base64url: payloadBase64)),
              let payloadString = String(data: payloadData, encoding: .utf8),
              let payloadJson = try? JSONSerialization.jsonObject(
                  with: payloadString.data(using: .utf8)!) as? [String: Any],
              let sdAlg = payloadJson["_sd_alg"] as? String
        else {
            return "sha-256"  // Default per SD-JWT spec
        }

        return sdAlg
    }

    static func extractX5cValues(_ header: [String: Any]) -> [String]? {
        guard let x5cJsonArray = header["x5c"] as? [String] else { return nil }
        return x5cJsonArray
    }

    static func getX509CertificatesFromJwt(_ jwt: [String: Any]) -> [(String, Data)]? {
        guard let x5cValues = extractX5cValues(jwt) else { return nil }
        var result: [(String, Data)] = []

        for cert in x5cValues {
            guard let der = Data(base64Encoded: cert),
                let pem = SignatureUtil.base64strToPem(base64str: cert)
            else {
                return nil
            }
            result.append((pem, der))
        }
        return result
    }
}
