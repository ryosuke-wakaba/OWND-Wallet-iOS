//
//  ProviderUtils.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2024/10/02.
//

import Foundation

func conformToFormData(preparedData: [PreparedSubmissionData]) -> String? {
    if preparedData.isEmpty {
        return ""
    }
    else if preparedData.count == 1 {
        return preparedData[0].vpToken
    }
    else {
        let tokens = preparedData.map { $0.vpToken }
        let jsonEncoder = JSONEncoder()
        if let jsonData = try? jsonEncoder.encode(tokens),
            let jsonString = String(data: jsonData, encoding: .utf8)
        {
            return jsonString
        }
        else {
            return nil
        }

    }
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
