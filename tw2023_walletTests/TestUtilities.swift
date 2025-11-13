//
//  TestUtilities.swift
//  tw2023_walletTests
//
//  Created by katsuyoshi ozaki on 2024/06/24.
//

import Foundation
import XCTest

enum TestUtilityError: Error {
    case FailedToLoadResourceJson(fileName: String)
}

func loadJsonTestData(fileName: String) throws -> Data {
    guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
        let jsonData = try? Data(contentsOf: url)
    else {
        XCTFail("Cannot read test data: \(fileName)")
        throw TestUtilityError.FailedToLoadResourceJson(fileName: fileName)
    }
    return jsonData
}

/// Loads and combines base credential issuer metadata with credential configurations from credential_supported files
/// - Parameters:
///   - credentialSupportedFileNames: Array of credential_supported file names (without .json extension)
/// - Returns: Combined JSON data ready for decoding into CredentialIssuerMetadata
func loadCredentialIssuerMetadata(credentialSupportedFileNames: [String]) throws -> Data {
    // Load base metadata
    let baseData = try loadJsonTestData(fileName: "credential_issuer_metadata_base")
    guard var baseJson = try JSONSerialization.jsonObject(with: baseData) as? [String: Any] else {
        throw TestUtilityError.FailedToLoadResourceJson(fileName: "credential_issuer_metadata_base")
    }

    // Initialize credential_configurations_supported
    var configurations: [String: Any] = [:]

    // Load and merge each credential_supported file
    for fileName in credentialSupportedFileNames {
        let credentialData = try loadJsonTestData(fileName: fileName)
        guard let credentialJson = try JSONSerialization.jsonObject(with: credentialData) as? [String: Any] else {
            throw TestUtilityError.FailedToLoadResourceJson(fileName: fileName)
        }

        // Extract credential_configurations_supported from the file
        if let credentialConfigs = credentialJson["credential_configurations_supported"] as? [String: Any] {
            // Merge into configurations
            for (key, value) in credentialConfigs {
                configurations[key] = value
            }
        } else {
            // If the file doesn't have the wrapper, treat the whole content as a single configuration
            // The key should be the fileName itself or derived from it
            configurations[fileName] = credentialJson
        }
    }

    // Add credential_configurations_supported to base metadata
    baseJson["credential_configurations_supported"] = configurations

    // Convert back to Data
    let combinedData = try JSONSerialization.data(withJSONObject: baseJson, options: [.prettyPrinted, .sortedKeys])
    return combinedData
}
