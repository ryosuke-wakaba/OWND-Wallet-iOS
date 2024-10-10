//
//  SerializeUtil.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2023/12/26.
//

import Foundation

enum JsonSerializationError: Error {
    case UnableToEncodeString
}

extension Dictionary where Key == String, Value == Any {

    public func toBase64UrlString() throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: self, options: [])
        return jsonData.base64URLEncodedString()
    }

    public func toString() throws -> String {
        let jsonData = try JSONSerialization.data(withJSONObject: self, options: [])
        guard let jsonString = String(data: jsonData, encoding: .utf8) else {
            throw JsonSerializationError.UnableToEncodeString
        }
        return jsonString
    }
}
