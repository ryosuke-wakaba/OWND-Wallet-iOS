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

        // Debug: Log original credential disclosures and _sd array
        print("[createVpTokenForSdJwtVc] ===== DEBUG: Original Credential Analysis =====")
        SDJwtUtil.debugPrintStructure(credential)
        let credentialParts = credential.split(separator: "~").map(String.init)
        print("[createVpTokenForSdJwtVc] Credential parts count: \(credentialParts.count)")
        if credentialParts.count > 1 {
            let originalDisclosures = Array(credentialParts.dropFirst().dropLast(credentialParts.last?.contains(".") == true ? 1 : 0))
            print("[createVpTokenForSdJwtVc] Original disclosures in credential: \(originalDisclosures.count)")
            for (i, d) in originalDisclosures.enumerated() {
                let decoded = SDJwtUtil.decodeDisclosure([d]).first
                // Calculate hash for this disclosure
                if let disclosureData = d.data(using: .utf8) {
                    let hash = disclosureData.sha256ToBase64Url()
                    print("[createVpTokenForSdJwtVc] OriginalDisclosure[\(i)]: key=\(decoded?.key ?? "nil"), hash=\(hash)")
                } else {
                    print("[createVpTokenForSdJwtVc] OriginalDisclosure[\(i)]: key=\(decoded?.key ?? "nil"), base64url=\(d.prefix(50))...")
                }
            }
        }

        // Only include actual SD-JWT disclosures that should be submitted
        // (filter out direct payload claims which have disclosure.disclosure == nil)
        let selectedDisclosures = discloseClaims.filter { $0.isSubmit && $0.disclosure.disclosure != nil }.map { $0.disclosure }
        print("[createVpTokenForSdJwtVc] ===== DEBUG: Selected Disclosures =====")
        print("[createVpTokenForSdJwtVc] Total discloseClaims: \(discloseClaims.count)")
        print("[createVpTokenForSdJwtVc] Selected disclosures (isSubmit=true): \(selectedDisclosures.count)")
        for (i, d) in selectedDisclosures.enumerated() {
            print("[createVpTokenForSdJwtVc] Disclosure[\(i)]: key=\(d.key ?? "nil"), base64url=\(d.disclosure?.prefix(50) ?? "nil")...")
            // Calculate hash for comparison with _sd array
            if let disclosureStr = d.disclosure,
               let disclosureData = disclosureStr.data(using: .utf8) {
                let hash = disclosureData.sha256ToBase64Url()
                print("[createVpTokenForSdJwtVc] Disclosure[\(i)]: sha256_hash=\(hash)")
            }
        }
        print(String(describing: credentialQuery))

        // Get _sd_alg from SD-JWT payload (defaults to "sha-256")
        let sdAlg = SDJwtUtil.getSdAlg(credential)

        let keyBindingJwt = try kb.generateJwt(
            sdJwt: credential,
            selectedDisclosures: selectedDisclosures,
            aud: clientId,
            nonce: nonce,
            sdAlg: sdAlg
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

        // RFC 9901: SD-JWT+KB format
        // - With disclosures: <JWT>~<D1>~<D2>~<KB-JWT>
        // - Without disclosures: <JWT>~<KB-JWT> (single tilde, not double)
        let disclosurePart = selectedDisclosures.isEmpty
            ? ""
            : selectedDisclosures.map { $0.disclosure! }.joined(separator: "~") + "~"
        let vpToken = issuerSignedJwt + "~" + disclosurePart + keyBindingJwt

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
            let (_, payload, _) = try JWTOperations.decodeJwt(jwt: credential)
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
