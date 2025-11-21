//
//  DCQLMatcher.swift
//  tw2023_wallet
//
//  DCQL Credential Matching for OID4VP 1.0
//

import Foundation

// MARK: - DCQL Matcher

class DCQLMatcher {

    /// Match credentials against a DCQL query
    /// - Parameters:
    ///   - query: The DCQL query from the verifier
    ///   - sdJwt: The SD-JWT credential to match
    /// - Returns: Matched credential query and disclosures with optionality, or nil if no match
    func matchCredential(
        query: DcqlQuery,
        sdJwt: String
    ) -> DcqlCredentialMatch? {
        guard let sdJwtParts = try? SDJwtUtil.divideSDJwt(sdJwt: sdJwt) else {
            return nil
        }

        let allDisclosures = SDJwtUtil.decodeDisclosure(sdJwtParts.disclosures)
        let sourcePayload = Dictionary(
            uniqueKeysWithValues: allDisclosures.compactMap { disclosure in
                if let key = disclosure.key, let value = disclosure.value {
                    return (key, value)
                } else {
                    return nil
                }
            }
        )

        // Try to match against each credential query
        for credentialQuery in query.credentials {
            // Check format
            guard credentialQuery.format == "vc+sd-jwt" || credentialQuery.format == "dc+sd-jwt" else {
                continue
            }

            // Check vct if specified
            if let meta = credentialQuery.meta, let vctValues = meta.vctValues {
                // Get vct from JWT payload
                guard let jwtPayload = try? getJwtPayload(sdJwtParts.issuerSignedJwt),
                      let vct = jwtPayload["vct"] as? String,
                      vctValues.contains(vct) else {
                    continue
                }
            }

            // Match claims
            let matchedClaims = matchClaims(
                credentialQuery: credentialQuery,
                sourcePayload: sourcePayload,
                allDisclosures: allDisclosures
            )

            if let matchedClaims = matchedClaims {
                return DcqlCredentialMatch(
                    credentialQuery: credentialQuery,
                    disclosuresWithOptionality: matchedClaims
                )
            }
        }

        return nil
    }

    /// Match claims from a credential query against the credential's disclosures
    private func matchClaims(
        credentialQuery: DcqlCredentialQuery,
        sourcePayload: [String: String],
        allDisclosures: [Disclosure]
    ) -> [DisclosureWithOptionality]? {
        guard let claims = credentialQuery.claims else {
            // No claims specified means all claims are acceptable
            return allDisclosures.map { disclosure in
                DisclosureWithOptionality(
                    disclosure: disclosure,
                    isSubmit: true,
                    isUserSelectable: false
                )
            }
        }

        // Build a map of claim paths to their requirements
        var requiredPaths = Set<String>()
        for claim in claims {
            // DCQL path is an array, we use the last element as the key
            if let lastPath = claim.path.last {
                requiredPaths.insert(lastPath)
            }
        }

        // Check if all required claims are present in the credential
        let availableKeys = Set(sourcePayload.keys)
        guard requiredPaths.isSubset(of: availableKeys) else {
            return nil
        }

        // Create disclosures with optionality
        return allDisclosures.map { disclosure in
            guard let dkey = disclosure.key else {
                return DisclosureWithOptionality(
                    disclosure: disclosure,
                    isSubmit: false,
                    isUserSelectable: false
                )
            }

            if requiredPaths.contains(dkey) {
                // This claim is required by the query
                return DisclosureWithOptionality(
                    disclosure: disclosure,
                    isSubmit: true,
                    isUserSelectable: false
                )
            } else {
                // This claim is not required, don't submit
                return DisclosureWithOptionality(
                    disclosure: disclosure,
                    isSubmit: false,
                    isUserSelectable: false
                )
            }
        }
    }

    /// Extract JWT payload from the issuer-signed JWT
    private func getJwtPayload(_ jwt: String) throws -> [String: Any] {
        let segments = jwt.components(separatedBy: ".")
        guard segments.count >= 2 else {
            throw JWTError.invalidFormat
        }

        let payloadSegment = segments[1]
        guard let payloadData = base64UrlDecode(payloadSegment) else {
            throw JWTError.invalidPayload
        }

        let jsonObject = try JSONSerialization.jsonObject(with: payloadData, options: [])
        guard let payload = jsonObject as? [String: Any] else {
            throw JWTError.decodingFailed
        }

        return payload
    }
}

// MARK: - DcqlQuery Extension for Convenience

extension DcqlQuery {
    /// Find the first matching credential query for an SD-JWT
    func firstMatchedCredentialQuery(sdJwt: String) -> DcqlCredentialMatch? {
        let matcher = DCQLMatcher()
        return matcher.matchCredential(query: self, sdJwt: sdJwt)
    }
}
