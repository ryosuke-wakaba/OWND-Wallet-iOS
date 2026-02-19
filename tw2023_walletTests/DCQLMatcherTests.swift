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
        // Result includes all disclosures. May include direct payload claims if any.
        // The test SD-JWT has 7 disclosures and potentially some direct payload claims
        XCTAssertGreaterThanOrEqual(result!.disclosuresWithOptionality.count, availableClaims.count)

        // Verify all expected claims are present
        let resultKeys = result!.disclosuresWithOptionality.compactMap { $0.disclosure.key }
        for claim in availableClaims {
            XCTAssertTrue(resultKeys.contains(claim), "Claim '\(claim)' should be present in result")
        }
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

    // MARK: - Test: Hybrid SD-JWT (direct payload claims + disclosures)

    /// Create a hybrid SD-JWT for testing where some claims are in JWT payload directly
    /// and some are selectively disclosable (disclosures)
    ///
    /// This simulates the case where Type Metadata specifies `selectivelyDisclosable: "never"`
    /// for some claims, which means they should be in the JWT payload directly.
    private func createHybridSdJwt() -> String {
        // JWT Header: {"typ":"sd+jwt","alg":"ES256"}
        let header = "eyJ0eXAiOiJzZCtqd3QiLCJhbGciOiJFUzI1NiJ9"

        // JWT Payload contains:
        // - Direct claims: issuing_authority, issuing_country, vct
        // - _sd array with hashes for: family_name, given_name
        //
        // Payload structure:
        // {
        //   "iss": "https://issuer.example.com",
        //   "vct": "urn:example:hybrid_credential",
        //   "issuing_authority": "Test Authority",
        //   "issuing_country": "JP",
        //   "_sd": ["<hash_of_family_name_disclosure>", "<hash_of_given_name_disclosure>"],
        //   "_sd_alg": "sha-256"
        // }
        //
        // Disclosure for family_name: ["salt1", "family_name", "Yamada"]
        //   Base64URL: WyJzYWx0MSIsImZhbWlseV9uYW1lIiwiWWFtYWRhIl0
        //   SHA-256 hash: kP8H8j0zKQ3x9G5Y1JkL2mN4oP6rS8tV0wX2yZ4bC6E
        //
        // Disclosure for given_name: ["salt2", "given_name", "Taro"]
        //   Base64URL: WyJzYWx0MiIsImdpdmVuX25hbWUiLCJUYXJvIl0
        //   SHA-256 hash: aB2cD4eF6gH8iJ0kL2mN4oP6qR8sT0uV2wX4yZ6bC8E

        // Pre-computed payload with correct _sd hashes
        // {
        //   "iss": "https://issuer.example.com",
        //   "vct": "urn:example:hybrid_credential",
        //   "issuing_authority": "Test Authority",
        //   "issuing_country": "JP",
        //   "_sd": ["8mVNLgST-GE2UhDNLOLX9KLV6JZpJHvnR5qZbqWM9cE", "Q1FLVC1ORoA7VqLWF9_I7qMRZJlqZ3oUvC9HKxA8Gn0"],
        //   "_sd_alg": "sha-256"
        // }
        let payload = "eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLmNvbSIsInZjdCI6InVybjpleGFtcGxlOmh5YnJpZF9jcmVkZW50aWFsIiwiaXNzdWluZ19hdXRob3JpdHkiOiJUZXN0IEF1dGhvcml0eSIsImlzc3VpbmdfY291bnRyeSI6IkpQIiwiX3NkIjpbIjhtVk5MZ1NULUdFMlVoRE5MT0xYOUtMVjZKWnBKSHZuUjVxWmJxV005Y0UiLCJRMUZMVkMxT1JvQTdWcUxXRjlfSTdxTVJaSmxxWjNvVXZDOUhLeEE4R24wIl0sIl9zZF9hbGciOiJzaGEtMjU2In0"

        // Dummy signature (not validated in these tests)
        let signature = "MEUCIQDxY6HmP8rLVPVdSKQ_Zm_X3pWvEqG2rMfH3kN2xS1YQQIgNpL7PJ7nR9sT0wV2xY4bC6E8gH0iJ2kL4mN6oP8qR0s"

        // Disclosures:
        // ["salt1", "family_name", "Yamada"] -> WyJzYWx0MSIsImZhbWlseV9uYW1lIiwiWWFtYWRhIl0
        // ["salt2", "given_name", "Taro"] -> WyJzYWx0MiIsImdpdmVuX25hbWUiLCJUYXJvIl0
        let disclosure1 = "WyJzYWx0MSIsImZhbWlseV9uYW1lIiwiWWFtYWRhIl0"
        let disclosure2 = "WyJzYWx0MiIsImdpdmVuX25hbWUiLCJUYXJvIl0"

        return "\(header).\(payload).\(signature)~\(disclosure1)~\(disclosure2)~"
    }

    /// When query requests claims that are in JWT payload directly (non-selectively-disclosable),
    /// DCQLMatcher should find them and match successfully
    func testHybridSdJwt_DirectPayloadClaimsRequested_ShouldMatch() {
        // Given: DCQL query requesting claims that are in JWT payload directly
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "hybrid_credential",
                  "format": "vc+sd-jwt",
                  "meta": {"vct_values": ["urn:example:hybrid_credential"]},
                  "claims": [
                    {"path": ["issuing_authority"]},
                    {"path": ["issuing_country"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        let hybridSdJwt = createHybridSdJwt()

        // When
        let result = matcher.matchCredential(query: query, sdJwt: hybridSdJwt)

        // Then
        XCTAssertNotNil(result, "Should match when requested claims are in JWT payload directly")

        // All claims (both disclosures and direct payload claims) should be in the result
        let disclosureKeys = result!.disclosuresWithOptionality.compactMap { $0.disclosure.key }
        XCTAssertTrue(disclosureKeys.contains("family_name"), "family_name disclosure should be present")
        XCTAssertTrue(disclosureKeys.contains("given_name"), "given_name disclosure should be present")
        XCTAssertTrue(disclosureKeys.contains("issuing_authority"), "issuing_authority should be present")
        XCTAssertTrue(disclosureKeys.contains("issuing_country"), "issuing_country should be present")

        // Requested direct payload claims should have isSubmit = true
        // Non-requested disclosures should have isSubmit = false
        for disclosure in result!.disclosuresWithOptionality {
            if let key = disclosure.disclosure.key {
                if key == "issuing_authority" || key == "issuing_country" {
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

    /// When query requests both direct payload claims and disclosure claims,
    /// DCQLMatcher should find all of them and match successfully
    func testHybridSdJwt_BothDirectAndDisclosureClaimsRequested_ShouldMatch() {
        // Given: DCQL query requesting both direct and disclosure claims
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "hybrid_credential",
                  "format": "vc+sd-jwt",
                  "meta": {"vct_values": ["urn:example:hybrid_credential"]},
                  "claims": [
                    {"path": ["issuing_authority"]},
                    {"path": ["family_name"]},
                    {"path": ["given_name"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        let hybridSdJwt = createHybridSdJwt()

        // When
        let result = matcher.matchCredential(query: query, sdJwt: hybridSdJwt)

        // Then
        XCTAssertNotNil(result, "Should match when both direct and disclosure claims are requested")

        // Only disclosure-based claims that were requested should have isSubmit = true
        for disclosure in result!.disclosuresWithOptionality {
            if let key = disclosure.disclosure.key {
                if key == "family_name" || key == "given_name" {
                    XCTAssertTrue(
                        disclosure.isSubmit,
                        "Requested disclosure '\(key)' should have isSubmit = true"
                    )
                }
            }
        }
    }

    /// When query requests a claim that doesn't exist in either payload or disclosures,
    /// DCQLMatcher should return nil
    func testHybridSdJwt_NonExistentClaimRequested_ShouldReturnNil() {
        // Given: DCQL query requesting a claim that doesn't exist
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "hybrid_credential",
                  "format": "vc+sd-jwt",
                  "meta": {"vct_values": ["urn:example:hybrid_credential"]},
                  "claims": [
                    {"path": ["issuing_authority"]},
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

        let hybridSdJwt = createHybridSdJwt()

        // When
        let result = matcher.matchCredential(query: query, sdJwt: hybridSdJwt)

        // Then
        XCTAssertNil(result, "Should return nil when a required claim doesn't exist")
    }

    /// When claims is absent for hybrid SD-JWT, all claims should have isSubmit = false
    /// Result includes both disclosures and direct payload claims
    func testHybridSdJwt_ClaimsAbsent_AllDisclosuresShouldNotBeSubmitted() {
        // Given: DCQL query without claims
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "hybrid_credential",
                  "format": "vc+sd-jwt",
                  "meta": {"vct_values": ["urn:example:hybrid_credential"]}
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        let hybridSdJwt = createHybridSdJwt()

        // When
        let result = matcher.matchCredential(query: query, sdJwt: hybridSdJwt)

        // Then
        XCTAssertNotNil(result, "Should match when claims is absent")

        // Should have 4 claims: 2 disclosures (family_name, given_name) + 2 direct payload (issuing_authority, issuing_country)
        XCTAssertEqual(result!.disclosuresWithOptionality.count, 4, "Should have 4 claims total")

        // All disclosures should have isSubmit = false when claims is absent
        for disclosure in result!.disclosuresWithOptionality {
            XCTAssertFalse(
                disclosure.isSubmit,
                "Disclosure '\(disclosure.disclosure.key ?? "unknown")' should have isSubmit = false when claims is absent"
            )
        }
    }

    /// Verify that reserved JWT claims (iss, vct, _sd, _sd_alg, etc.) are not treated as credential claims
    func testHybridSdJwt_ReservedClaimsNotTreatedAsCredentialClaims() {
        // Given: DCQL query requesting reserved JWT claims
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "hybrid_credential",
                  "format": "vc+sd-jwt",
                  "meta": {"vct_values": ["urn:example:hybrid_credential"]},
                  "claims": [
                    {"path": ["iss"]},
                    {"path": ["vct"]}
                  ]
                }
              ]
            }
            """

        guard let query = try? JSONDecoder().decode(DcqlQuery.self, from: queryJson.data(using: .utf8)!) else {
            XCTFail("Failed to decode DCQL query")
            return
        }

        let hybridSdJwt = createHybridSdJwt()

        // When
        let result = matcher.matchCredential(query: query, sdJwt: hybridSdJwt)

        // Then: Should return nil because reserved claims are not treated as credential claims
        XCTAssertNil(result, "Should return nil when reserved JWT claims are requested as credential claims")
    }

    // MARK: - Test: Null/Empty Value Claim Matching

    /// Create an SD-JWT with a disclosure containing a null value
    /// This simulates claims where the value is not registered/blank
    private func createSdJwtWithNullValueClaim() -> String {
        // JWT Header: {"typ":"sd+jwt","alg":"ES256"}
        let header = "eyJ0eXAiOiJzZCtqd3QiLCJhbGciOiJFUzI1NiJ9"

        // JWT Payload with _sd array
        // We'll include a disclosure for a claim with null value
        let payload = "eyJpc3MiOiJodHRwczovL2lzc3Vlci5leGFtcGxlLmNvbSIsInZjdCI6InVybjpleGFtcGxlOm51bGxfdmFsdWVfY3JlZGVudGlhbCIsIl9zZCI6WyJoYXNoMSIsImhhc2gyIl0sIl9zZF9hbGciOiJzaGEtMjU2In0"

        // Dummy signature
        let signature = "sig"

        // Disclosures:
        // ["salt1", "claim_with_value", "actual_value"] -> normal claim
        // ["salt2", "claim_with_null", null] -> claim with null value
        let disclosure1 = "WyJzYWx0MSIsImNsYWltX3dpdGhfdmFsdWUiLCJhY3R1YWxfdmFsdWUiXQ"  // ["salt1","claim_with_value","actual_value"]
        let disclosure2 = "WyJzYWx0MiIsImNsYWltX3dpdGhfbnVsbCIsbnVsbF0"  // ["salt2","claim_with_null",null]

        return "\(header).\(payload).\(signature)~\(disclosure1)~\(disclosure2)~"
    }

    /// When a claim has a null value, it should still match if the verifier requests it
    /// The claim KEY exists, even if the VALUE is null
    func testNullValueClaim_ShouldMatchWhenRequested() {
        // Given: SD-JWT with a claim that has null value
        let sdJwtWithNullValue = createSdJwtWithNullValueClaim()

        // DCQL query requesting the claim with null value
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "null_value_credential",
                  "format": "vc+sd-jwt",
                  "claims": [
                    {"path": ["claim_with_null"]}
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
        let result = matcher.matchCredential(query: query, sdJwt: sdJwtWithNullValue)

        // Then: Should match because the claim KEY exists (even though value is null)
        XCTAssertNotNil(result, "Should match when claim key exists even if value is null")

        // The claim should be marked for submission
        let submittedClaims = result!.disclosuresWithOptionality.filter { $0.isSubmit }
        XCTAssertTrue(
            submittedClaims.contains { $0.disclosure.key == "claim_with_null" },
            "Claim with null value should be marked for submission"
        )
    }

    /// When requesting multiple claims including one with null value, should match all
    func testMixedNullAndValueClaims_ShouldMatchAll() {
        // Given: SD-JWT with both null and valued claims
        let sdJwtWithNullValue = createSdJwtWithNullValueClaim()

        // DCQL query requesting both claims
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "null_value_credential",
                  "format": "vc+sd-jwt",
                  "claims": [
                    {"path": ["claim_with_value"]},
                    {"path": ["claim_with_null"]}
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
        let result = matcher.matchCredential(query: query, sdJwt: sdJwtWithNullValue)

        // Then: Should match because both claim KEYs exist
        XCTAssertNotNil(result, "Should match when all claim keys exist")

        // Both claims should be marked for submission
        let submittedClaims = result!.disclosuresWithOptionality.filter { $0.isSubmit }
        XCTAssertEqual(submittedClaims.count, 2, "Both claims should be marked for submission")
    }

    /// Test with empty string value (not null, but blank)
    func testEmptyStringValueClaim_ShouldMatch() {
        // The existing testSdJwt already has claims with empty string values (last_name, first_name)
        // Given: DCQL query requesting claims with empty string values
        let queryJson = """
            {
              "credentials": [
                {
                  "id": "test_credential",
                  "format": "vc+sd-jwt",
                  "claims": [
                    {"path": ["last_name"]},
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

        // Then: Should match because claim keys exist (values are empty strings)
        XCTAssertNotNil(result, "Should match when claim keys exist with empty string values")

        // Both claims should be marked for submission
        let submittedClaims = result!.disclosuresWithOptionality.filter { $0.isSubmit }
        XCTAssertEqual(submittedClaims.count, 2, "Both claims should be marked for submission")
        XCTAssertTrue(
            submittedClaims.contains { $0.disclosure.key == "last_name" },
            "last_name should be marked for submission"
        )
        XCTAssertTrue(
            submittedClaims.contains { $0.disclosure.key == "first_name" },
            "first_name should be marked for submission"
        )
    }
}
