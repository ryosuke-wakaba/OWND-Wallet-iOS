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
    using session: URLSession = URLSession.shared
) async throws -> (Data, HTTPURLResponse, URL) {

    var request: URLRequest

    switch responseMode {
        case .directPost, .directPostJwt:
            // TODO: directPostJwt should encrypt/sign the response as JWT
            // For now, treat it the same as directPost
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
