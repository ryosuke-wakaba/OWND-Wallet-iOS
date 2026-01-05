//
//  MetadataClient.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/26.
//

import Foundation

enum MetadataError: LocalizedError {
    // networking error
    case invalidIssuerUrl(issuer: String)
    case httpRequestError(url: URL)
    case httpResponseError(response: URLResponse)

    // data handling error
    case decodingError(data: Data)
    case missingAuthorizationEndpoint(authorizationServer: URL)
    case missingTokenEndpoint(authorizationServer: URL)

    // signed metadata error
    case signedMetadataValidationFailed(SignedMetadataError)

    case unexpectedError

    var errorDescription: String? {
        switch self {
        case .invalidIssuerUrl:
            return "Invalid issuer URL. Please contact the service provider."
        case .httpRequestError:
            return "Network error occurred. Please check your connection and try again."
        case .httpResponseError:
            return "Server error occurred. Please try again later."
        case .decodingError:
            return "Failed to process server response. Please contact the service provider."
        case .missingAuthorizationEndpoint:
            return "Authorization endpoint not found. Please contact the service provider."
        case .missingTokenEndpoint:
            return "Token endpoint not found. Please contact the service provider."
        case .signedMetadataValidationFailed(let signedMetadataError):
            return signedMetadataError.errorDescription
        case .unexpectedError:
            return "An unexpected error occurred. Please try again."
        }
    }
}

func fetchMetadata<T: Decodable>(
    from url: URL, to type: T.Type, using session: URLSession = URLSession.shared
) async throws -> T {
    var data: Data
    var response: URLResponse

    do {
        (data, response) = try await session.data(for: URLRequest(url: url))
    }
    catch {
        throw MetadataError.httpRequestError(url: url)
    }

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw MetadataError.httpResponseError(response: response)
    }

    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase

    do {
        let metaData = try decoder.decode(T.self, from: data)
        return metaData
    }
    catch {
        throw MetadataError.decodingError(data: data)
    }
}

/// Fetches Credential Issuer Metadata with Signed Metadata support (OID4VCI Section 12.2.3)
/// - Parameters:
///   - url: The metadata endpoint URL
///   - issuerIdentifier: The credential issuer identifier (for sub validation in signed metadata)
///   - session: URLSession to use for the request
/// - Returns: CredentialIssuerMetadata
func fetchCredentialIssuerMetadata(
    from url: URL,
    issuerIdentifier: String,
    using session: URLSession = URLSession.shared
) async throws -> CredentialIssuerMetadata {
    // Create request with Accept header preferring signed metadata
    var request = URLRequest(url: url)
    request.setValue("application/jwt, application/json;q=0.9", forHTTPHeaderField: "Accept")

    var data: Data
    var response: URLResponse

    do {
        (data, response) = try await session.data(for: request)
    } catch {
        throw MetadataError.httpRequestError(url: url)
    }

    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
        throw MetadataError.httpResponseError(response: response)
    }

    // Check Content-Type to determine response format
    let contentType = httpResponse.value(forHTTPHeaderField: "Content-Type") ?? ""

    if contentType.contains("application/jwt") {
        // Signed Metadata response
        guard let jwtString = String(data: data, encoding: .utf8) else {
            throw MetadataError.decodingError(data: data)
        }

        // Validate signed metadata
        let validationResult = SignedMetadataValidator.validate(
            jwt: jwtString,
            expectedIssuerIdentifier: issuerIdentifier
        )

        switch validationResult {
        case .failure(let error):
            throw MetadataError.signedMetadataValidationFailed(error)
        case .success(let result):
            // Extract metadata from validated payload
            do {
                let metadataJson = try SignedMetadataValidator.extractMetadataJson(from: result.payload)
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                return try decoder.decode(CredentialIssuerMetadata.self, from: metadataJson)
            } catch {
                throw MetadataError.decodingError(data: data)
            }
        }
    } else {
        // Standard JSON response
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            return try decoder.decode(CredentialIssuerMetadata.self, from: data)
        } catch {
            throw MetadataError.decodingError(data: data)
        }
    }
}

/// Legacy function for backward compatibility (without signed metadata validation)
func fetchCredentialIssuerMetadata(from url: URL, using session: URLSession = URLSession.shared)
    async throws -> CredentialIssuerMetadata
{
    return try await fetchMetadata(from: url, to: CredentialIssuerMetadata.self, using: session)
}

func fetchAuthServerMetadata(from url: URL, using session: URLSession = URLSession.shared)
    async throws -> AuthorizationServerMetadata
{
    return try await fetchMetadata(from: url, to: AuthorizationServerMetadata.self, using: session)
}

func retrieveAllMetadata(issuer: String, using session: URLSession = URLSession.shared)
    async
    throws -> Metadata
{
    guard let issuerUrl = URL(string: issuer) else {
        throw MetadataError.invalidIssuerUrl(issuer: issuer)
    }

    let credentialIssuerMetadataUrl =
        issuerUrl
        .appendingPathComponent(".well-known")
        .appendingPathComponent("openid-credential-issuer")

    // Use signed metadata aware fetch with issuer identifier for validation
    let credentialIssuerMetadata = try await fetchCredentialIssuerMetadata(
        from: credentialIssuerMetadataUrl,
        issuerIdentifier: issuer,
        using: session
    )

    var authorizationServerUrl: URL = issuerUrl
    if let authorizationServers = credentialIssuerMetadata.authorizationServers {
        for server in authorizationServers {
            if let tmpAuthorizationServerUrl = URL(string: server) {
                authorizationServerUrl = tmpAuthorizationServerUrl
                break
            }
        }
    }

    let authorizationServerMetadataUrl =
        authorizationServerUrl
        .appendingPathComponent(".well-known")
        .appendingPathComponent("oauth-authorization-server")

    let authorizationServerMetadata = try await fetchAuthServerMetadata(
        from: authorizationServerMetadataUrl, using: session)

    let grantTypesSupported = authorizationServerMetadata.grantTypesSupported
    let authorizationEndpoint = authorizationServerMetadata.authorizationEndpoint
    let tokenEndpoint = authorizationServerMetadata.tokenEndpoint

    if authorizationEndpoint == nil {
        // todo: Check the `grantTypes` and if all of them are types that do not use the
        //   Authorization Endpoint, there is no need to generate an error.
        throw
            MetadataError.missingAuthorizationEndpoint(authorizationServer: authorizationServerUrl)
    }

    if tokenEndpoint == nil {
        if grantTypesSupported == nil || grantTypesSupported != ["implicit"] {
            // If omitted, the default value is "["authorization_code", "implicit"]".
            throw
                MetadataError.missingTokenEndpoint(
                    authorizationServer: authorizationServerMetadataUrl)
        }
    }

    let result = Metadata(
        credentialIssuerMetadata: credentialIssuerMetadata,
        authorizationServerMetadata: authorizationServerMetadata)

    return result
}
