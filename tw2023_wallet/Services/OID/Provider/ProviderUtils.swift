//
//  ProviderUtils.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2024/10/02.
//

import Foundation

/// Format vp_token as DCQL response format: {"credential_id": ["token", ...]}
func conformToFormData(preparedData: [PreparedSubmissionData]) -> String? {
    if preparedData.isEmpty {
        return "{}"
    }

    // Group tokens by DCQL credential ID
    var tokensByCredentialId: [String: [String]] = [:]
    for data in preparedData {
        if tokensByCredentialId[data.dcqlCredentialId] == nil {
            tokensByCredentialId[data.dcqlCredentialId] = []
        }
        tokensByCredentialId[data.dcqlCredentialId]?.append(data.vpToken)
    }

    // Serialize to JSON
    let jsonEncoder = JSONEncoder()
    if let jsonData = try? jsonEncoder.encode(tokensByCredentialId),
        let jsonString = String(data: jsonData, encoding: .utf8)
    {
        return jsonString
    }
    return nil
}

func sendFormData(
    formData: [String: String],
    url: URL,
    responseMode: ResponseMode,
    clientMetadata: RPRegistrationMetadataPayload? = nil,
    using session: URLSession = URLSession.shared
) async throws -> (Data, HTTPURLResponse, URL) {

    var request: URLRequest

    switch responseMode {
        case .directPost:
            request = URLRequest(url: url)
            request.httpMethod = "POST"

            let formBody = formData.map { key, value in
                let encodedKey =
                    key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let encodedValue =
                    value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "\(encodedKey)=\(encodedValue.replacingOccurrences(of: "+", with: "%2B"))"
            }.joined(separator: "&")

            request.httpBody = formBody.data(using: .utf8)
            request.setValue(
                "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        case .directPostJwt:
            // Encrypt response as JWE (HAIP-compliant)
            request = URLRequest(url: url)
            request.httpMethod = "POST"

            // Get encryption public key from client_metadata.jwks
            guard let jwks = clientMetadata?.jwks,
                  let encryptionKey: ClientJWK = jwks.keys.first(where: { $0.use == "enc" || $0.alg == "ECDH-ES" }) ?? jwks.keys.first
            else {
                print("No encryption key found in client_metadata.jwks, falling back to plain response")
                // Fallback to plain response if no encryption key
                let formBody = formData.map { key, value in
                    let encodedKey =
                        key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    let encodedValue =
                        value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                    return "\(encodedKey)=\(encodedValue.replacingOccurrences(of: "+", with: "%2B"))"
                }.joined(separator: "&")
                request.httpBody = formBody.data(using: .utf8)
                request.setValue(
                    "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                break
            }

            // Build payload to encrypt (vp_token only, state is sent separately)
            var encryptPayload: [String: Any] = [:]
            if let vpToken = formData["vp_token"] {
                // Parse vp_token JSON string back to object
                if let vpTokenData = vpToken.data(using: .utf8),
                   let vpTokenJson = try? JSONSerialization.jsonObject(with: vpTokenData) {
                    encryptPayload["vp_token"] = vpTokenJson
                } else {
                    encryptPayload["vp_token"] = vpToken
                }
            }

            // Encrypt payload
            let jwe = try JWEUtil.encrypt(payload: encryptPayload, recipientPublicKey: encryptionKey)
            print("JWE encrypted response created")

            // Build form data: response=<JWE>&state=<state>
            var encryptedFormData: [String: String] = ["response": jwe]
            if let state = formData["state"] {
                encryptedFormData["state"] = state
            }

            let formBody = encryptedFormData.map { key, value in
                let encodedKey =
                    key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                let encodedValue =
                    value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                return "\(encodedKey)=\(encodedValue.replacingOccurrences(of: "+", with: "%2B"))"
            }.joined(separator: "&")

            request.httpBody = formBody.data(using: .utf8)
            request.setValue(
                "application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        default:
            print("Unsupported responseMode : \(responseMode)")
            throw OpenIdProviderIllegalStateException.illegalResponseModeState
    }

    do {
        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }

        guard (200...399).contains(httpResponse.statusCode) else {
            throw NetworkError.statusCodeNotSuccessful(httpResponse.statusCode)
        }

        return (data, httpResponse, url)
    }
    catch {
        throw NetworkError.other(error)
    }
}
