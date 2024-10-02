//
//  Types.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2024/01/13.
//

import Foundation

typealias KeyPair = (publicKey: SecKey, privateKey: SecKey)
typealias KeyPairData = (publicKey: (Data, Data), privateKey: Data)

protocol KeyBinding {
    func generateJwt(sdJwt: String, selectedDisclosures: [Disclosure], aud: String, nonce: String)
        throws -> String
}

protocol JwtVpJsonGenerator {
    func generateJwt(
        vcJwt: String, headerOptions: HeaderOptions, payloadOptions: JwtVpJsonPayloadOptions
    ) -> String
    func getJwk() -> [String: String]
}

struct HeaderOptions: Codable {
    var alg: String = "ES256"
    var typ: String = "JWT"
    var jwk: String? = nil
}

struct JwtVpJsonPayloadOptions: Codable {
    var iss: String? = nil
    var jti: String? = nil
    var aud: String
    var nbf: Int64? = nil
    var iat: Int64? = nil
    var exp: Int64? = nil
    var nonce: String
}

struct VpJwtPayload {
    var iss: String?
    var jti: String?
    var aud: String?
    var nbf: Int64?
    var iat: Int64?
    var exp: Int64?
    var nonce: String?
    var vp: [String: Any]

    enum CodingKeys: String, CodingKey {
        case iss, jti, aud, nbf, iat, exp, nonce, vp
    }

    init(
        iss: String?, jti: String?, aud: String?, nbf: Int64?, iat: Int64?, exp: Int64?,
        nonce: String?, vp: [String: Any]
    ) {
        self.iss = iss
        self.jti = jti
        self.aud = aud
        self.nbf = nbf
        self.iat = iat
        self.exp = exp
        self.nonce = nonce
        self.vp = vp
    }

    // 手動で辞書を構築し、エンコードするメソッド
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        if let iss = iss { dict["iss"] = iss }
        if let jti = jti { dict["jti"] = jti }
        if let aud = aud { dict["aud"] = aud }
        if let nbf = nbf { dict["nbf"] = nbf }
        if let iat = iat { dict["iat"] = iat }
        if let exp = exp { dict["exp"] = exp }
        if let nonce = nonce { dict["nonce"] = nonce }
        dict["vp"] = vp

        return dict
    }
}
