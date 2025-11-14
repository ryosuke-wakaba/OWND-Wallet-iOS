//
//  MetadataDecoder.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Utility for decoding credential issuer metadata
struct MetadataDecoder {

    /// Decode CredentialIssuerMetadata from JSON string
    /// - Parameter jsonString: JSON string representation of the metadata
    /// - Returns: CredentialIssuerMetadata or nil if decoding fails
    static func decode(jsonString: String) -> CredentialIssuerMetadata? {
        guard let jsonData = jsonString.data(using: .utf8) else {
            print("MetadataDecoder: Failed to convert JSON string to Data")
            return nil
        }

        return decode(jsonData: jsonData)
    }

    /// Decode CredentialIssuerMetadata from JSON Data
    /// - Parameter jsonData: JSON data representation of the metadata
    /// - Returns: CredentialIssuerMetadata or nil if decoding fails
    static func decode(jsonData: Data) -> CredentialIssuerMetadata? {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let metadata = try decoder.decode(CredentialIssuerMetadata.self, from: jsonData)
            return metadata
        } catch {
            print("MetadataDecoder: Failed to decode CredentialIssuerMetadata: \(error)")
            return nil
        }
    }

    /// Encode CredentialIssuerMetadata to JSON string
    /// - Parameter metadata: The metadata to encode
    /// - Returns: JSON string or nil if encoding fails
    static func encode(metadata: CredentialIssuerMetadata) -> String? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        do {
            let jsonData = try encoder.encode(metadata)
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("MetadataDecoder: Failed to encode CredentialIssuerMetadata: \(error)")
            return nil
        }
    }

    /// Encode CredentialIssuerMetadata to JSON Data
    /// - Parameter metadata: The metadata to encode
    /// - Returns: JSON Data or nil if encoding fails
    static func encodeToData(metadata: CredentialIssuerMetadata) -> Data? {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        do {
            return try encoder.encode(metadata)
        } catch {
            print("MetadataDecoder: Failed to encode CredentialIssuerMetadata: \(error)")
            return nil
        }
    }
}
