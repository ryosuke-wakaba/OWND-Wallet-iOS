//
//  DCQLMatcher.swift
//  tw2023_wallet
//
//  DCQL Credential Matching for OID4VP 1.0
//

import Foundation

// MARK: - DCQL Matcher

class DCQLMatcher {

    /// Reserved JWT claims that should not be treated as credential claims
    private static let reservedJwtClaims: Set<String> = [
        "iss", "sub", "aud", "exp", "nbf", "iat", "jti",  // Standard JWT claims
        "vct", "cnf", "_sd", "_sd_alg", "status"           // SD-JWT specific claims
    ]

    /// Match credentials against a DCQL query
    /// - Parameters:
    ///   - query: The DCQL query from the verifier
    ///   - sdJwt: The SD-JWT credential to match
    /// - Returns: Matched credential query and disclosures with optionality, or nil if no match
    func matchCredential(
        query: DcqlQuery,
        sdJwt: String
    ) -> DcqlCredentialMatch? {
        print("[DCQLMatcher] Starting credential matching")

        guard let sdJwtParts = try? SDJwtUtil.divideSDJwt(sdJwt: sdJwt) else {
            print("[DCQLMatcher] Failed to parse SD-JWT")
            return nil
        }

        // Get disclosures (selectively disclosable claims)
        let allDisclosures = SDJwtUtil.decodeDisclosure(sdJwtParts.disclosures)
        var sourcePayload = Dictionary(
            uniqueKeysWithValues: allDisclosures.compactMap { disclosure in
                if let key = disclosure.key, let value = disclosure.value {
                    return (key, value)
                } else {
                    return nil
                }
            }
        )

        // Also extract claims directly from JWT payload (non-selectively-disclosable claims)
        var directPayloadClaimKeys: Set<String> = []
        if let jwtPayload = try? getJwtPayload(sdJwtParts.issuerSignedJwt) {
            for (key, value) in jwtPayload {
                // Skip reserved claims
                guard !DCQLMatcher.reservedJwtClaims.contains(key) else { continue }

                // Convert value to string
                let stringValue: String
                if let strVal = value as? String {
                    stringValue = strVal
                } else if let boolVal = value as? Bool {
                    stringValue = boolVal ? "true" : "false"
                } else if let numVal = value as? NSNumber {
                    stringValue = numVal.stringValue
                } else {
                    // For complex types, use JSON serialization
                    if let data = try? JSONSerialization.data(withJSONObject: value),
                       let str = String(data: data, encoding: .utf8) {
                        stringValue = str
                    } else {
                        stringValue = String(describing: value)
                    }
                }

                // Only add if not already in disclosures (disclosures take precedence)
                if sourcePayload[key] == nil {
                    directPayloadClaimKeys.insert(key)
                    sourcePayload[key] = stringValue
                }
            }
        }

        print("[DCQLMatcher] Credential has \(allDisclosures.count) disclosures")
        print("[DCQLMatcher] Credential has \(directPayloadClaimKeys.count) direct payload claims: \(directPayloadClaimKeys.sorted())")
        print("[DCQLMatcher] Available claim keys: \(sourcePayload.keys.sorted())")

        // Get VCT from credential
        if let jwtPayload = try? getJwtPayload(sdJwtParts.issuerSignedJwt),
           let credentialVct = jwtPayload["vct"] as? String {
            print("[DCQLMatcher] Credential VCT: \(credentialVct)")
        } else {
            print("[DCQLMatcher] Credential has no VCT or failed to extract")
        }

        // Try to match against each credential query
        for (index, credentialQuery) in query.credentials.enumerated() {
            print("[DCQLMatcher] Checking query[\(index)]: format=\(credentialQuery.format)")

            // Check format
            guard credentialQuery.format == "vc+sd-jwt" || credentialQuery.format == "dc+sd-jwt" else {
                print("[DCQLMatcher] Query[\(index)] skipped: format '\(credentialQuery.format)' not supported")
                continue
            }

            // Check vct if specified
            if let meta = credentialQuery.meta, let vctValues = meta.vctValues {
                print("[DCQLMatcher] Query[\(index)] requires VCT: \(vctValues)")
                // Get vct from JWT payload
                guard let jwtPayload = try? getJwtPayload(sdJwtParts.issuerSignedJwt),
                      let vct = jwtPayload["vct"] as? String else {
                    print("[DCQLMatcher] Query[\(index)] failed: could not extract VCT from credential")
                    continue
                }
                guard vctValues.contains(vct) else {
                    print("[DCQLMatcher] Query[\(index)] failed: VCT mismatch - credential has '\(vct)'")
                    continue
                }
                print("[DCQLMatcher] Query[\(index)] VCT matched")
            }

            // Match claims
            let matchedClaims = matchClaims(
                credentialQuery: credentialQuery,
                sourcePayload: sourcePayload,
                allDisclosures: allDisclosures,
                directPayloadClaimKeys: directPayloadClaimKeys
            )

            if let matchedClaims = matchedClaims {
                print("[DCQLMatcher] Query[\(index)] MATCHED with \(matchedClaims.count) claims")
                return DcqlCredentialMatch(
                    credentialQuery: credentialQuery,
                    disclosuresWithOptionality: matchedClaims
                )
            } else {
                print("[DCQLMatcher] Query[\(index)] failed: claims matching failed")
            }
        }

        print("[DCQLMatcher] No matching query found")
        return nil
    }

    /// Match claims from a credential query against the credential's disclosures and direct payload claims
    private func matchClaims(
        credentialQuery: DcqlCredentialQuery,
        sourcePayload: [String: String],
        allDisclosures: [Disclosure],
        directPayloadClaimKeys: Set<String>
    ) -> [DisclosureWithOptionality]? {
        guard let claims = credentialQuery.claims else {
            // OID4VP 1.0 Section 6.4.1: If claims is absent, the Verifier is requesting
            // no claims that are selectively disclosable; the Wallet MUST return only
            // the claims that are mandatory to present (SD-JWT and KB-JWT only).
            print("[DCQLMatcher] No claims specified in query, returning all disclosures as non-submit")
            return allDisclosures.map { disclosure in
                DisclosureWithOptionality(
                    disclosure: disclosure,
                    isSubmit: false,  // Do not submit selectively disclosable claims
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

        print("[DCQLMatcher] Required claims: \(requiredPaths.sorted())")

        // Check if all required claims are present in the credential
        // (either as disclosures or as direct payload claims)
        let availableKeys = Set(sourcePayload.keys)
        let missingClaims = requiredPaths.subtracting(availableKeys)
        guard missingClaims.isEmpty else {
            print("[DCQLMatcher] Claims matching failed - missing claims: \(missingClaims.sorted())")
            return nil
        }

        // Log which required claims are from direct payload vs disclosures
        let requiredFromDirectPayload = requiredPaths.intersection(directPayloadClaimKeys)
        let requiredFromDisclosures = requiredPaths.subtracting(directPayloadClaimKeys)
        print("[DCQLMatcher] Required claims from direct payload (no disclosure needed): \(requiredFromDirectPayload.sorted())")
        print("[DCQLMatcher] Required claims from disclosures: \(requiredFromDisclosures.sorted())")
        print("[DCQLMatcher] All required claims are present")

        // Create disclosures with optionality
        // Only disclosures need to be submitted; direct payload claims are already visible
        return allDisclosures.map { disclosure in
            guard let dkey = disclosure.key else {
                return DisclosureWithOptionality(
                    disclosure: disclosure,
                    isSubmit: false,
                    isUserSelectable: false
                )
            }

            if requiredPaths.contains(dkey) {
                // This claim is required by the query and is a disclosure
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
