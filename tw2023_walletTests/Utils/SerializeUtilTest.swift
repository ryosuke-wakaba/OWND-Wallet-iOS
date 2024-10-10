//
//  SerializeUtilTest.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2024/10/10.
//

import XCTest

@testable import tw2023_wallet

final class SerializeUtilTest: XCTestCase {
    func testToString() {
        let data: [String: Any] = ["foo": 123]
        XCTAssertTrue((try! data.toString()) == "{\"foo\":123}")
    }
    func testToBase64UrlString() {
        let data: [String: Any] = ["foo": 123]
        XCTAssertTrue((try! data.toBase64UrlString()) == "eyJmb28iOjEyM30")
    }
}
