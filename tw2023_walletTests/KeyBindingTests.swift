//
//  KeyBindingTests.swift
//  tw2023_walletTests
//
//  Created by 若葉良介 on 2024/01/15.
//

import XCTest

final class KeyBindingTests: XCTestCase {

    var keyAlias = "testKeyAlias"
    var publicKey: SecKey?
    var privateKey: SecKey?

    override func setUpWithError() throws {
        super.setUp()
        // キーペアの生成
        try KeyPairUtil.generateSignVerifyKeyPair(alias: keyAlias)
        (privateKey, publicKey) = KeyPairUtil.getKeyPair(alias: keyAlias)!
    }

    override func tearDownWithError() throws {
        publicKey = nil
        privateKey = nil
        super.tearDown()
    }

    func testGenerateJwtSignature() throws {
        // 必要なパラメータを設定
        let sdJwt = "sdJwtSample"
        let selectedDisclosures = [
            Disclosure(disclosure: "disclosureSample", key: "keySample", value: "valueSample")
        ]
        let aud = "audSample"
        let nonce = "nonceSample"

        // JWTの生成
        let keyBinding = KeyBindingImpl(keyAlias: keyAlias)
        let jwt = try keyBinding.generateJwt(
            sdJwt: sdJwt,
            selectedDisclosures: selectedDisclosures,
            aud: aud,
            nonce: nonce,
            sdAlg: "sha-256"
        )

        // JWTの検証
        let verificationResult = JWTOperations.verifyJwt(jwt: jwt, publicKey: publicKey!)
        switch verificationResult {
            case .success(_):
                XCTAssertTrue(true, "JWT verification succeeded")
            case .failure(let error):
                XCTFail("JWT verification failed: \(error)")
        }
    }

    func testGenerateJwtWithSha256UpperCase() throws {
        let sdJwt = "sdJwtSample"
        let selectedDisclosures = [
            Disclosure(disclosure: "disclosureSample", key: "keySample", value: "valueSample")
        ]
        let aud = "audSample"
        let nonce = "nonceSample"

        let keyBinding = KeyBindingImpl(keyAlias: keyAlias)

        // Test with "SHA-256" (uppercase) - should throw error per SD-JWT spec (case-sensitive)
        // IANA registry defines "sha-256" (lowercase), not "SHA-256"
        XCTAssertThrowsError(
            try keyBinding.generateJwt(
                sdJwt: sdJwt,
                selectedDisclosures: selectedDisclosures,
                aud: aud,
                nonce: nonce,
                sdAlg: "SHA-256"
            )
        ) { error in
            guard case KeyBindingImplError.UnsupportedHashAlgorithm(let alg) = error else {
                XCTFail("Expected UnsupportedHashAlgorithm error")
                return
            }
            XCTAssertEqual(alg, "SHA-256")
        }
    }

    func testGenerateJwtWithUnsupportedAlgorithm() throws {
        let sdJwt = "sdJwtSample"
        let selectedDisclosures = [
            Disclosure(disclosure: "disclosureSample", key: "keySample", value: "valueSample")
        ]
        let aud = "audSample"
        let nonce = "nonceSample"

        let keyBinding = KeyBindingImpl(keyAlias: keyAlias)

        // Test with unsupported algorithm - should throw error
        XCTAssertThrowsError(
            try keyBinding.generateJwt(
                sdJwt: sdJwt,
                selectedDisclosures: selectedDisclosures,
                aud: aud,
                nonce: nonce,
                sdAlg: "sha-512"
            )
        ) { error in
            guard case KeyBindingImplError.UnsupportedHashAlgorithm(let alg) = error else {
                XCTFail("Expected UnsupportedHashAlgorithm error")
                return
            }
            XCTAssertEqual(alg, "sha-512")
        }
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
