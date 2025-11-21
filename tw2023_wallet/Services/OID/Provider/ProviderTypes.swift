//
//  ProviderTypes.swift
//  tw2023_wallet
//
//  Created by katsuyoshi ozaki on 2024/10/02.
//

struct ProviderOption {
    let signingCurve: String = "secp256k1"
    let signingAlgo: String = "ES256K"
    let expiresIn: Int64 = 600
}

struct DisclosedClaim: Codable {
    let id: String  // credential identifier
    let types: [String]
    let name: String
    let value: String?
    // let path: String   // when nested claim is supported, it may be needed
}

struct SharedCredential: Codable {
    let id: String
    let purposeForSharing: String?
    let sharedClaims: [DisclosedClaim]
}

struct TokenSendResult: Decodable {
    let statusCode: Int
    let location: String?
    let cookies: [String]?

    let sharedIdToken: String?
    let sharedCredentials: [SharedCredential]?
}

struct PreparedSubmissionData {
    let credentialId: String
    let dcqlCredentialId: String  // DCQL credential query ID
    let vpToken: String
    let disclosedClaims: [DisclosedClaim]
    let purpose: String?
}

struct SubmissionCredential: Codable, Equatable {
    let id: String
    let format: String
    let types: [String]
    let credential: String
    let credentialQuery: DcqlCredentialQuery
    let discloseClaims: [DisclosureWithOptionality]

    static func == (lhs: SubmissionCredential, rhs: SubmissionCredential) -> Bool {
        return lhs.id == rhs.id
    }

    func createVpTokenForSdJwtVc(
        clientId: String,
        nonce: String,
        tokenIndex: Int,
        keyBinding: KeyBinding?
    ) throws -> PreparedSubmissionData {
        guard let kb = keyBinding else {
            throw OpenIdProviderIllegalStateException.illegalKeyBindingState
        }
        let selectedDisclosures = discloseClaims.map { $0.disclosure }
        print(String(describing: credentialQuery))

        let keyBindingJwt = try kb.generateJwt(
            sdJwt: credential, selectedDisclosures: selectedDisclosures, aud: clientId, nonce: nonce
        )

        let parts = credential.split(separator: "~").map(String.init)
        guard let issuerSignedJwt = parts.first else {
            throw OpenIdProviderIllegalInputException.illegalCredentialInput
        }

        let hasNilValue = selectedDisclosures.contains { disclosure in
            disclosure.disclosure == nil
        }

        if hasNilValue {
            throw OpenIdProviderIllegalInputException.illegalDisclosureInput
        }

        let vpToken =
            issuerSignedJwt + "~"
            + selectedDisclosures.map { $0.disclosure! }.joined(separator: "~") + "~"
            + keyBindingJwt

        print("### Created vpToken\n\(vpToken)")

        let disclosedClaims = selectedDisclosures.compactMap { disclosure -> DisclosedClaim? in
            guard let key = disclosure.key else { return nil }
            return DisclosedClaim(
                id: id, types: types, name: key, value: disclosure.value)
        }

        return PreparedSubmissionData(
            credentialId: id,
            dcqlCredentialId: credentialQuery.id,
            vpToken: vpToken,
            disclosedClaims: disclosedClaims,
            purpose: nil)
    }

    func createVpTokenForJwtVc(
        clientId: String,
        nonce: String,
        tokenIndex: Int,
        jwtVpJsonGenerator: JwtVpJsonGenerator?
    ) throws -> PreparedSubmissionData {
        guard let generator = jwtVpJsonGenerator else {
            throw OpenIdProviderIllegalInputException.illegalCredentialInput
        }
        do {
            let (_, payload, _) = try JWTUtil.decodeJwt(jwt: credential)
            if let vcDictionary = payload["vc"] as? [String: Any],
                let credentialSubject = vcDictionary["credentialSubject"] as? [String: Any]
            {
                let disclosedClaims = credentialSubject.map { key, value in
                    return DisclosedClaim(
                        id: id, types: types, name: key,
                        value: value as? String)
                }
                let vpToken = generator.generateJwt(
                    vcJwt: credential, headerOptions: HeaderOptions(),
                    payloadOptions: JwtVpJsonPayloadOptions(aud: clientId, nonce: nonce))

                return PreparedSubmissionData(
                    credentialId: id,
                    dcqlCredentialId: credentialQuery.id,
                    vpToken: vpToken,
                    disclosedClaims: disclosedClaims,
                    purpose: nil
                )
            }
            else {
                throw OpenIdProviderIllegalInputException.illegalCredentialInput
            }
        }
        catch {
            print("Error: \(error)")
            throw error
        }
    }

}
