//
//  DCQLMatcherTests.swift
//  tw2023_walletTests
//
//  Tests for DCQL Credential Matching (OID4VP 1.0 Section 6.4.1)
//

import XCTest

@testable import tw2023_wallet

class DCQLMatcherTests: XCTestCase {

    var matcher: DCQLMatcher!

    // Test SD-JWT with disclosures:
    // - verified_at, last_name, first_name, is_order_than_15, is_order_than_18, is_order_than_20, is_order_than_65
    let testSdJwt = "eyJ0eXAiOiJzZCtqd3QiLCJhbGciOiJFUzI1NksiLCJ4NWMiOlsiTUlJQzFqQ0NBYjZnQXdJQkFnSVVXd3ZhU1RyMjgxV3o1R0wrQjNsK1ZONW1YWm93RFFZSktvWklodmNOQVFFTEJRQXdKVEVqTUNFR0ExVUVBd3dhVkdWemRDQkRaWEowYVdacFkyRjBaU0JCZFhSb2IzSnBkSGt3SGhjTk1qTXhNVEE1TURFMU5UTXpXaGNOTWpReE1UQTRNREUxTlRNeldqQnFNUXN3Q1FZRFZRUUdFd0pLVURFU01CQUdBMVVFQ0F3SjVwMng1THFzNllPOU1SSXdFQVlEVlFRSERBbm1sckRscnIvbGpMb3hIVEFiQmdOVkJBb01GT2FncXVXOGorUzhtdWVrdmtSaGRHRlRhV2R1TVJRd0VnWURWUVFEREF0a1lYUmhjMmxuYmk1cWNEQldNQkFHQnlxR1NNNDlBZ0VHQlN1QkJBQUtBMElBQk0yNW53b21QdlZ1dkdzOGdnZVU2dnUzMmQrK0I3eWJ5MWI1R0JUbkcraFJxd1hnL0xZTFg0RldzQ0htZXFHZzFVZzA1MEhOTHM5WVBqMkdaVEprWVFLamdZWXdnWU13RmdZRFZSMFJCQTh3RFlJTFpHRjBZWE5wWjI0dWFuQXdIUVlEVlIwT0JCWUVGRVVTZUpNOEtTcXg1M0c0ZVUxQjQvMW5qQUhZTUVvR0ExVWRJd1JETUVHaEthUW5NQ1V4SXpBaEJnTlZCQU1NR2xSbGMzUWdRMlZ5ZEdsbWFXTmhkR1VnUVhWMGFHOXlhWFI1Z2hRdHdBL3hzMmxxbzFTRUJXTlhtbWVFaGJqdXF6QU5CZ2txaGtpRzl3MEJBUXNGQUFPQ0FRRUFIZFIzdXV0b0MrUlE3NTBNY0x6OWVGdHpFcnVZa0dVMGFDbkNNenBNSjNITVc2M3BPS0ZWVmhwTnhpcnorcG0vRnBEd0FjTFQxamdLdmRiSDRjYWk4b1RmZDg0R3VFbGR4T3lOWVZySXlia0pPSmxhMXRabG9XNldqR2ZLVlk4WUFhS3dIVlFCY3dhL3N0ZDE4ajNnN0NBL2g5VjR3S1V0UFlMS05vYkFPay9DU0QyQkNIU2R0NDlNUmRrZ3lpZ2p4aDY1NHFrL0RJc3JLejZWVVI3L1VQdnVHdXdQdFpoaElzLzg5T29OWjJ5dk1LQ2ZmTUdITEw5VEtlR0dWVmY5b3pWeFYvbE5ibmVYbUdEMmt2WjF6RmJSd2FZQ213NERjSUFZTGlqMjluYWhib1k4MGhkdDg2SFplNDJlc1FTQkRCemFUeUE0RXZYSDVsNUFVdFNIbWc9PSIsIk1JSUMwVENDQWJrQ0ZDM0FEL0d6YVdxalZJUUZZMWVhWjRTRnVPNnJNQTBHQ1NxR1NJYjNEUUVCQ3dVQU1DVXhJekFoQmdOVkJBTU1HbFJsYzNRZ1EyVnlkR2xtYVdOaGRHVWdRWFYwYUc5eWFYUjVNQjRYRFRJek1URXdPVEF4TkRrME5Wb1hEVEkwTVRFd09EQXhORGswTlZvd0pURWpNQ0VHQTFVRUF3d2FWR1Z6ZENCRFpYSjBhV1pwWTJGMFpTQkJkWFJvYjNKcGRIa3dnZ0VpTUEwR0NTcUdTSWIzRFFFQkFRVUFBNElCRHdBd2dnRUtBb0lCQVFEQ2oyZzFtN1lRWmIxTE1PbE15MnpyT0NnOWNBRXpySzdyY3R5bUZGZDlyNzdKTU9pMWMzbnpJbTZaV2Vtd1NOeEdZMnlVU0IrQ05ISkRRK1c5dk8yTS85RkZ2dUt4TWZWQ0RERUJWMXc5cmtOZGpJR2N2aExBNlZqaHhvQU4wWDRWUm04cHpXN0tLc3I5UE1yMkhaVmJxb3JMVG5Ua0M1YUhob3FWY0xlL09Gbm00TnpVMDJCOXhlY2Fhb3FhalBBWEhsdEZ0RCtEVktFNm1RdVJ0RDhLT0lSaFBmSDlVdW9yT1lWMmVtTEt3MWI3TUZNNU84SUVUY0tEMnRhemNIUlFiRmlvLzZWU1lYaWtCekhJOWJ0dGZkMnFtbVRtVE9MSWhGc2dUYm5acWxHYzltWWIzSEEybVN5blhnMC9OemRPNE1zRi9iaEZtd1N2Q3hCUENZbVJBZ01CQUFFd0RRWUpLb1pJaHZjTkFRRUxCUUFEZ2dFQkFMekhCZXZPeGJWWEhEOGlIZGhqTHFiVURpWmtPTzg0VU5JRk9JY2VxNEo2ODVxeEphSlo2NVNKVjZmM2d3YlJhM0JDZUpzTEdTa3RjS0o1a2NOOFMzc0ZBQm1Nb1lTQm4vS0xHMjY3Mm9PQ21kYVpWL25vdHVoeDJwd3FyVHROLzVadzE0VWxBNzhiSDhzdUN6SEtwZFNiR1I3clpRbVh5QWtJbDJWVUdPRkNrbFdLeWxzWEZZY29UL2p3Z2dUbGYyNnp3Ynpsa2pJRkZZK3NYcjBuOGdDYWw5bzQwZUhhTldBc2tOZEEyQ3ZpcXg1RklsdG83L09LMGxyS2lKeGtOSThFY0JCUVJlMG1EbnpqNlFYeFlMT3FpaEMxb3dRdWtVY05GSGR5YTRsdlZYMWYxaHgyUkRMWUcycWd2WmVQemY2R3lSSDBtVVM5YXNwNmNCUjhBc2M9Il19.eyJjbmYiOnsia3R5IjoiRUMiLCJjcnYiOiJzZWNwMjU2azEiLCJ4IjoidFZ3VHBCRTB2QVlpdnZXOGlseWtnYWQ4RFM3cHFVcUNiUU9JQ2gwU29nbyIsInkiOiJTalZIbS1QX0NrWUVteURDR2p5OUlWc3Rsb0YyVDB3cUZVREtMeUVER1J3In0sImlhdCI6MCwidHlwZSI6IiIsImlzcyI6IiIsIl9zZCI6WyIySTdTcFVQcE11R1VlMjVDM21wN0ExRG10R1NiQnBnN0Qwb2dRbHI0VWZFIiwicmdyVW42M0ZhblJkTGlqc3pPUEkyN0FOUHA0NnVpV2kxRFdYX3k0VlRqWSIsIndpT2ZDdTUwYmpURldoZkktWGJmNGFlR19WSi0zOWdYV3BXQV9ILVdEUG8iLCIwSFdCUEZmVTFJSjhZYXFsUGdJeEJHQ3QtNlUtTjJJRWw3X1JzMTY5OGdFIiwiOEI1M1BENzdHMkMyajFnd180V0o4a1pTalY3S0I5MjNodVhpMVBWeGpmYyIsIlN2VXdfSFh5cVNqcUxLTHN6dG5GcHlEMkRwb1JsczYybG44SzVMcFUxS0EiLCJfU0lKLUtqTWxzaGtnbkFtYmVxM0pPenduVGhNU0hzZ08wTW1BQXJadHBnIl19.dNzrFlXB98jAUxzMxWG6hgbXb59fsX_Ib0tpYOOh_6d4qsxYIfh8_VkcrcSZmCmVr-p8tjXk_PfEdM25XgP9fA~WyJjRXdQVDU2NmNpSVhMb1VUIiwidmVyaWZpZWRfYXQiLDBd~WyJteE0xRjdOQzBmY1hDdERnIiwibGFzdF9uYW1lIiwiIl0~WyJXYmRLbTVEMzYwZVNNczltIiwiZmlyc3RfbmFtZSIsIiJd~WyJuR05ldXRwTjY4UEFRdGVvIiwiaXNfb3JkZXJfdGhhbl8xNSIsZmFsc2Vd~WyJ0TGljVHJwdWh2c2ZrMmlSIiwiaXNfb3JkZXJfdGhhbl8xOCIsZmFsc2Vd~WyJjYmFBSGY4eUl6RXFack8xIiwiaXNfb3JkZXJfdGhhbl8yMCIsZmFsc2Vd~WyJhUEpQcHhTb2dIMkpKYUhMIiwiaXNfb3JkZXJfdGhhbl82NSIsZmFsc2Vd~"

    // Available claims in the test SD-JWT
    let availableClaims = [
        "verified_at", "last_name", "first_name",
        "is_order_than_15", "is_order_than_18", "is_order_than_20", "is_order_than_65"
    ]

    override func setUp() {
        super.setUp()
        matcher = DCQLMatcher()
    }

    override func tearDown() {
        matcher = nil
        super.tearDown()
    }

    // MARK: - Test: claims absent (OID4VP 1.0 Section 6.4.1 Rule 1)

    /// When claims is absent, all disclosures should have isSubmit = false
    /// (Wallet should return only mandatory claims, not selectively disclosable ones)
    func testClaimsAbsent_AllDisclosuresShouldNotBeSubmitted() {
        // Given: DCQL query without claims
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt"
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNotNil(result, "Should match when claims is absent")

        // All disclosures should have isSubmit = false
        for disclosure in result!.disclosuresWithOptionality {
            XCTAssertFalse(
                disclosure.isSubmit,
                "Disclosure '\(disclosure.disclosure.key ?? "unknown")' should have isSubmit = false when claims is absent"
            )
        }
    }

    /// When claims is absent, the match should still succeed (credential matches)
    func testClaimsAbsent_ShouldReturnAllDisclosures() {
        // Given: DCQL query without claims
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt"
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.disclosuresWithOptionality.count, availableClaims.count)
    }

    // MARK: - Test: claims present, claim_sets absent (OID4VP 1.0 Section 6.4.1 Rule 2)

    /// When claims is present with all claims available, matched claims should have isSubmit = true
    func testClaimsPresent_AllClaimsAvailable_MatchedClaimsShouldBeSubmitted() {
        // Given: DCQL query with claims that exist in the credential
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt",
                  "claims": [
                    {"path": ["first_name"]},
                    {"path": ["last_name"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNotNil(result, "Should match when all requested claims are available")

        // Check that requested claims have isSubmit = true
        let requestedClaims = ["first_name", "last_name"]
        for disclosure in result!.disclosuresWithOptionality {
            if let key = disclosure.disclosure.key {
                if requestedClaims.contains(key) {
                    XCTAssertTrue(
                        disclosure.isSubmit,
                        "Requested claim '\(key)' should have isSubmit = true"
                    )
                } else {
                    XCTAssertFalse(
                        disclosure.isSubmit,
                        "Non-requested claim '\(key)' should have isSubmit = false"
                    )
                }
            }
        }
    }

    /// When claims is present but some claims are missing, should return nil
    func testClaimsPresent_SomeClaimsMissing_ShouldReturnNil() {
        // Given: DCQL query with claims that don't exist in the credential
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt",
                  "claims": [
                    {"path": ["first_name"]},
                    {"path": ["non_existent_claim"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNil(result, "Should not match when required claims are missing")
    }

    /// When claims array is empty, should match with no claims submitted
    func testClaimsPresent_EmptyClaimsArray_ShouldMatchWithNoClaimsSubmitted() {
        // Given: DCQL query with empty claims array
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt",
                  "claims": []
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNotNil(result, "Should match when claims array is empty")

        // All disclosures should have isSubmit = false (no claims requested)
        for disclosure in result!.disclosuresWithOptionality {
            XCTAssertFalse(
                disclosure.isSubmit,
                "Disclosure '\(disclosure.disclosure.key ?? "unknown")' should have isSubmit = false when claims array is empty"
            )
        }
    }

    // MARK: - Test: Format matching

    /// When format doesn't match, should return nil
    func testFormatMismatch_ShouldReturnNil() {
        // Given: DCQL query with wrong format
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "jwt_vc_json",
                  "claims": [
                    {"path": ["first_name"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNil(result, "Should not match when format doesn't match")
    }

    /// When format is dc+sd-jwt, should match
    func testFormatDcSdJwt_ShouldMatch() {
        // Given: DCQL query with dc+sd-jwt format
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "dc+sd-jwt",
                  "claims": [
                    {"path": ["first_name"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNotNil(result, "Should match when format is dc+sd-jwt")
    }

    // MARK: - Test: Multiple credential queries

    /// When first credential query doesn't match but second does, should return second
    func testMultipleCredentialQueries_FirstFails_SecondMatches() {
        // Given: DCQL query with two credential queries
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "credential_1",
                  "format": "vc+sd-jwt",
                  "claims": [
                    {"path": ["non_existent_claim"]}
                  ]
                },
                {
                  "id": "credential_2",
                  "format": "vc+sd-jwt",
                  "claims": [
                    {"path": ["first_name"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNotNil(result, "Should match the second credential query")
        XCTAssertEqual(result!.credentialQuery.id, "credential_2")
    }

    // MARK: - Test: VCT matching

    /// When VCT matches, should return match
    func testVctMatch_ShouldMatch() {
        // Note: The test SD-JWT doesn't have a vct claim in the payload,
        // so we test that when vct_values is not specified, matching proceeds
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt",
                  "claims": [
                    {"path": ["first_name"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNotNil(result, "Should match when vct_values is not specified")
    }

    // MARK: - Test: Single claim request

    /// Request a single claim
    func testSingleClaimRequest_ShouldMatchOnlyThatClaim() {
        // Given
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt",
                  "claims": [
                    {"path": ["verified_at"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNotNil(result)

        let submittedClaims = result!.disclosuresWithOptionality.filter { $0.isSubmit }
        XCTAssertEqual(submittedClaims.count, 1, "Only one claim should be submitted")
        XCTAssertEqual(submittedClaims.first?.disclosure.key, "verified_at")
    }

    // MARK: - Test: All available claims request

    /// Request all available claims
    func testAllClaimsRequest_ShouldMatchAllClaims() {
        // Given
        let claimsJson = availableClaims.map { "{\"path\": [\"\($0)\"]}" }.joined(separator: ",")
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt",
                  "claims": [\(claimsJson)]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = matcher.matchCredential(query: query, sdJwt: testSdJwt)

        // Then
        XCTAssertNotNil(result)

        let submittedClaims = result!.disclosuresWithOptionality.filter { $0.isSubmit }
        XCTAssertEqual(submittedClaims.count, availableClaims.count, "All claims should be submitted")
    }

    // MARK: - Test: Invalid SD-JWT

    /// When SD-JWT is empty (truly invalid), should return nil
    func testInvalidSdJwt_EmptyString_ShouldReturnNil() {
        // Given
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt"
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When: Empty string causes SDJwtUtil.divideSDJwt to throw
        let result = matcher.matchCredential(query: query, sdJwt: "")

        // Then
        XCTAssertNil(result, "Should return nil for empty SD-JWT")
    }

    /// When SD-JWT has no disclosures and claims is absent, should still match (with empty disclosures)
    func testSdJwtWithNoDisclosures_ClaimsAbsent_ShouldMatch() {
        // Given
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt"
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When: SD-JWT with just issuer JWT, no disclosures (ends with ~)
        let result = matcher.matchCredential(query: query, sdJwt: "eyJhbGciOiJFUzI1NiJ9.eyJpc3MiOiJ0ZXN0In0.sig~")

        // Then: Should match but with empty disclosures
        XCTAssertNotNil(result, "Should match SD-JWT with no disclosures when claims is absent")
        XCTAssertTrue(result!.disclosuresWithOptionality.isEmpty, "Should have empty disclosures")
    }

    // MARK: - Test: DcqlQuery Extension

    /// Test the convenience extension method
    func testDcqlQueryExtension_FirstMatchedCredentialQuery() {
        // Given
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt",
                  "claims": [
                    {"path": ["first_name"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        // When
        let result = query.firstMatchedCredentialQuery(sdJwt: testSdJwt)

        // Then
        XCTAssertNotNil(result)
        XCTAssertEqual(result!.credentialQuery.id, "test_credential")
    }
}
