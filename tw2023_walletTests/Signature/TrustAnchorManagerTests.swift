//
//  TrustAnchorManagerTests.swift
//  tw2023_walletTests
//
//  Tests for TrustAnchorManager certificate loading and management.
//

import CryptoKit
import Foundation
import Security
import SwiftASN1
import X509
import XCTest

@testable import tw2023_wallet

final class TrustAnchorManagerTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        // Clear any existing certificates before each test
        TrustAnchorManager.shared.clear()
    }

    override func tearDownWithError() throws {
        TrustAnchorManager.shared.clear()
        try super.tearDownWithError()
    }

    // MARK: - Basic Tests

    func testSharedInstance() {
        let manager1 = TrustAnchorManager.shared
        let manager2 = TrustAnchorManager.shared

        XCTAssertTrue(manager1 === manager2, "Should return the same instance")
    }

    func testInitialState() {
        let manager = TrustAnchorManager.shared
        manager.clear()

        XCTAssertFalse(manager.hasCustomAnchors, "Should not have custom anchors after clear")
        XCTAssertTrue(manager.anchorCertificates.isEmpty, "Anchor certificates should be empty")
        XCTAssertTrue(
            manager.intermediateCertificates.isEmpty, "Intermediate certificates should be empty")
    }

    func testClearCertificates() {
        let manager = TrustAnchorManager.shared

        // Add a test certificate
        let testCert = createTestCertificate()
        if let cert = testCert {
            manager.addAnchorCertificate(cert)
        }

        XCTAssertTrue(manager.hasCustomAnchors, "Should have custom anchors after adding")

        // Clear
        manager.clear()

        XCTAssertFalse(manager.hasCustomAnchors, "Should not have custom anchors after clear")
        XCTAssertTrue(manager.anchorCertificates.isEmpty, "Anchor certificates should be empty")
    }

    // MARK: - Add Certificate Tests

    func testAddAnchorCertificate() {
        let manager = TrustAnchorManager.shared

        guard let testCert = createTestCertificate() else {
            XCTFail("Failed to create test certificate")
            return
        }

        manager.addAnchorCertificate(testCert)

        XCTAssertEqual(manager.anchorCertificates.count, 1, "Should have 1 anchor certificate")
        XCTAssertTrue(manager.hasCustomAnchors, "Should have custom anchors")
    }

    func testAddIntermediateCertificate() {
        let manager = TrustAnchorManager.shared

        guard let testCert = createTestCertificate() else {
            XCTFail("Failed to create test certificate")
            return
        }

        manager.addIntermediateCertificate(testCert)

        XCTAssertEqual(
            manager.intermediateCertificates.count, 1, "Should have 1 intermediate certificate")
        XCTAssertFalse(
            manager.hasCustomAnchors,
            "Should not have custom anchors (only intermediates don't count)")
    }

    func testAddAnchorCertificateFromDerData() {
        let manager = TrustAnchorManager.shared

        guard let testCert = createTestX509Certificate() else {
            XCTFail("Failed to create test X509 certificate")
            return
        }

        let derData = try! testCert.serializeAsPEM().derBytes
        let result = manager.addAnchorCertificate(derData: Data(derData))

        XCTAssertTrue(result, "Should successfully add certificate from DER data")
        XCTAssertEqual(manager.anchorCertificates.count, 1, "Should have 1 anchor certificate")
    }

    func testAddIntermediateCertificateFromDerData() {
        let manager = TrustAnchorManager.shared

        guard let testCert = createTestX509Certificate() else {
            XCTFail("Failed to create test X509 certificate")
            return
        }

        let derData = try! testCert.serializeAsPEM().derBytes
        let result = manager.addIntermediateCertificate(derData: Data(derData))

        XCTAssertTrue(result, "Should successfully add certificate from DER data")
        XCTAssertEqual(
            manager.intermediateCertificates.count, 1, "Should have 1 intermediate certificate")
    }

    func testAddInvalidDerData() {
        let manager = TrustAnchorManager.shared

        let invalidData = Data("not a certificate".utf8)
        let result = manager.addAnchorCertificate(derData: invalidData)

        XCTAssertFalse(result, "Should fail to add invalid DER data")
        XCTAssertTrue(manager.anchorCertificates.isEmpty, "Should have no anchor certificates")
    }

    // MARK: - All Certificates Test

    func testAllCertificates() {
        let manager = TrustAnchorManager.shared

        guard let cert1 = createTestCertificate(),
            let cert2 = createTestCertificate()
        else {
            XCTFail("Failed to create test certificates")
            return
        }

        manager.addAnchorCertificate(cert1)
        manager.addIntermediateCertificate(cert2)

        XCTAssertEqual(manager.allCertificates.count, 2, "Should have 2 total certificates")
    }

    // MARK: - Reload Test

    func testReload() {
        let manager = TrustAnchorManager.shared

        // Add a certificate
        guard let testCert = createTestCertificate() else {
            XCTFail("Failed to create test certificate")
            return
        }
        manager.addAnchorCertificate(testCert)

        XCTAssertEqual(manager.anchorCertificates.count, 1, "Should have 1 certificate before reload")

        // Reload (this will clear programmatically added certs and reload from bundle)
        manager.reload()

        // After reload, programmatically added certificates are cleared
        // Only certificates from bundle will remain (if any)
        XCTAssertTrue(manager.isLoaded, "Should be loaded after reload")
    }

    // MARK: - Self-Signed Certificate Detection Tests

    func testSelfSignedCertificateDetection() {
        // createTestX509Certificate creates a self-signed certificate (issuer == subject)
        guard let selfSignedCert = createTestX509Certificate() else {
            XCTFail("Failed to create self-signed certificate")
            return
        }

        let derData = try! selfSignedCert.serializeAsPEM().derBytes
        guard let secCert = SecCertificateCreateWithData(nil, Data(derData) as CFData) else {
            XCTFail("Failed to convert to SecCertificate")
            return
        }

        // Verify issuer == subject for self-signed cert
        let issuer = SecCertificateCopyNormalizedIssuerSequence(secCert)
        let subject = SecCertificateCopyNormalizedSubjectSequence(secCert)

        XCTAssertNotNil(issuer, "Issuer should not be nil")
        XCTAssertNotNil(subject, "Subject should not be nil")
        XCTAssertEqual(issuer! as Data, subject! as Data, "Self-signed cert should have issuer == subject")
    }

    func testNonSelfSignedCertificateDetection() {
        // Create a certificate chain: root (self-signed) -> leaf (not self-signed)
        let rootKey = P256.Signing.PrivateKey()
        let leafKey = P256.Signing.PrivateKey()

        guard let rootCert = createSelfSignedCertificate(privateKey: rootKey, commonName: "Test Root"),
              let leafCert = createSignedCertificate(
                  subjectKey: leafKey,
                  issuerKey: rootKey,
                  issuerName: "Test Root",
                  subjectName: "Test Leaf"
              ) else {
            XCTFail("Failed to create certificate chain")
            return
        }

        let rootDer = try! rootCert.serializeAsPEM().derBytes
        let leafDer = try! leafCert.serializeAsPEM().derBytes

        guard let rootSecCert = SecCertificateCreateWithData(nil, Data(rootDer) as CFData),
              let leafSecCert = SecCertificateCreateWithData(nil, Data(leafDer) as CFData) else {
            XCTFail("Failed to convert to SecCertificate")
            return
        }

        // Root should be self-signed
        let rootIssuer = SecCertificateCopyNormalizedIssuerSequence(rootSecCert)! as Data
        let rootSubject = SecCertificateCopyNormalizedSubjectSequence(rootSecCert)! as Data
        XCTAssertEqual(rootIssuer, rootSubject, "Root cert should be self-signed")

        // Leaf should NOT be self-signed
        let leafIssuer = SecCertificateCopyNormalizedIssuerSequence(leafSecCert)! as Data
        let leafSubject = SecCertificateCopyNormalizedSubjectSequence(leafSecCert)! as Data
        XCTAssertNotEqual(leafIssuer, leafSubject, "Leaf cert should NOT be self-signed")
    }

    private func createSelfSignedCertificate(privateKey: P256.Signing.PrivateKey, commonName: String) -> Certificate? {
        let publicKey = Certificate.PublicKey(privateKey.publicKey)
        let signingKey = Certificate.PrivateKey(privateKey)

        let name = try? DistinguishedName {
            CommonName(commonName)
            OrganizationName("Test Organization")
            CountryName("JP")
        }

        guard let subjectName = name else { return nil }

        // Use a time window that is definitely valid (1 hour ago to 1 year from now)
        let notBefore = Date().addingTimeInterval(-60 * 60)
        let notAfter = Date().addingTimeInterval(60 * 60 * 24 * 365)
        let extensions = try? Certificate.Extensions {
            Critical(BasicConstraints.isCertificateAuthority(maxPathLength: nil))
        }

        return try? Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: publicKey,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: subjectName,
            subject: subjectName,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions ?? Certificate.Extensions(),
            issuerPrivateKey: signingKey
        )
    }

    private func createSignedCertificate(
        subjectKey: P256.Signing.PrivateKey,
        issuerKey: P256.Signing.PrivateKey,
        issuerName: String,
        subjectName: String
    ) -> Certificate? {
        let publicKey = Certificate.PublicKey(subjectKey.publicKey)
        let signingKey = Certificate.PrivateKey(issuerKey)

        let issuer = try? DistinguishedName {
            CommonName(issuerName)
            OrganizationName("Test Organization")
            CountryName("JP")
        }

        let subject = try? DistinguishedName {
            CommonName(subjectName)
            OrganizationName("Test Organization")
            CountryName("JP")
        }

        guard let issuerDN = issuer, let subjectDN = subject else { return nil }

        // Use a time window that is definitely valid (1 hour ago to 1 year from now)
        let notBefore = Date().addingTimeInterval(-60 * 60)
        let notAfter = Date().addingTimeInterval(60 * 60 * 24 * 365)
        let extensions = try? Certificate.Extensions {
            Critical(BasicConstraints.notCertificateAuthority)
        }

        return try? Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: publicKey,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: issuerDN,
            subject: subjectDN,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions ?? Certificate.Extensions(),
            issuerPrivateKey: signingKey
        )
    }

    // MARK: - Disposable Instance Tests

    func testCreateDisposableInstanceWithAdditionalCertificates() {
        // First, add some certificates to the singleton
        let manager = TrustAnchorManager.shared
        guard let sharedRootCert = createTestCertificate() else {
            XCTFail("Failed to create shared root certificate")
            return
        }
        manager.addAnchorCertificate(sharedRootCert)

        // Create a disposable instance with additional certificates
        guard let additionalCert = createTestCertificate() else {
            XCTFail("Failed to create additional certificate")
            return
        }

        let disposable = TrustAnchorManager.createInstance(withAdditionalCertificates: [additionalCert])

        // Disposable should have both: inherited from singleton + additional
        // Since we added 1 to singleton and 1 additional (both self-signed = anchors)
        XCTAssertEqual(disposable.anchorCertificates.count, 2,
                       "Disposable should have 2 anchor certificates (1 inherited + 1 additional)")
    }

    func testCreateDisposableInstanceInheritsSingletonCertificates() {
        let manager = TrustAnchorManager.shared

        // Add root CA and intermediate to singleton
        let rootKey = P256.Signing.PrivateKey()
        let intermediateKey = P256.Signing.PrivateKey()

        guard let rootCert = createSelfSignedCertificate(privateKey: rootKey, commonName: "Shared Root"),
              let intermediateCert = createSignedCertificate(
                  subjectKey: intermediateKey,
                  issuerKey: rootKey,
                  issuerName: "Shared Root",
                  subjectName: "Shared Intermediate"
              ) else {
            XCTFail("Failed to create shared certificates")
            return
        }

        let rootDer = try! rootCert.serializeAsPEM().derBytes
        let intermediateDer = try! intermediateCert.serializeAsPEM().derBytes

        guard let rootSecCert = SecCertificateCreateWithData(nil, Data(rootDer) as CFData),
              let intermediateSecCert = SecCertificateCreateWithData(nil, Data(intermediateDer) as CFData) else {
            XCTFail("Failed to convert to SecCertificate")
            return
        }

        manager.addAnchorCertificate(rootSecCert)
        manager.addIntermediateCertificate(intermediateSecCert)

        // Create disposable without additional certificates
        let disposable = TrustAnchorManager.createInstance(withAdditionalCertificates: [])

        // Disposable should inherit all from singleton
        XCTAssertEqual(disposable.anchorCertificates.count, manager.anchorCertificates.count,
                       "Disposable should inherit all anchor certificates from singleton")
        XCTAssertEqual(disposable.intermediateCertificates.count, manager.intermediateCertificates.count,
                       "Disposable should inherit all intermediate certificates from singleton")
    }

    func testDisposableInstanceDoesNotAffectSingleton() {
        let manager = TrustAnchorManager.shared
        let originalAnchorCount = manager.anchorCertificates.count
        let originalIntermediateCount = manager.intermediateCertificates.count

        // Create a disposable instance with additional certificates
        guard let additionalCert = createTestCertificate() else {
            XCTFail("Failed to create additional certificate")
            return
        }

        let disposable = TrustAnchorManager.createInstance(withAdditionalCertificates: [additionalCert])

        // Verify disposable has additional certificates
        XCTAssertGreaterThanOrEqual(disposable.anchorCertificates.count, originalAnchorCount)

        // Verify singleton is unchanged
        XCTAssertEqual(manager.anchorCertificates.count, originalAnchorCount,
                       "Singleton anchor count should be unchanged")
        XCTAssertEqual(manager.intermediateCertificates.count, originalIntermediateCount,
                       "Singleton intermediate count should be unchanged")
    }

    func testDisposableInstanceClassifiesCertificatesCorrectly() {
        // Create a mix of self-signed (root) and non-self-signed (intermediate) certificates
        let rootKey = P256.Signing.PrivateKey()
        let intermediateKey = P256.Signing.PrivateKey()

        guard let rootCert = createSelfSignedCertificate(privateKey: rootKey, commonName: "Additional Root"),
              let intermediateCert = createSignedCertificate(
                  subjectKey: intermediateKey,
                  issuerKey: rootKey,
                  issuerName: "Additional Root",
                  subjectName: "Additional Intermediate"
              ) else {
            XCTFail("Failed to create certificates")
            return
        }

        let rootDer = try! rootCert.serializeAsPEM().derBytes
        let intermediateDer = try! intermediateCert.serializeAsPEM().derBytes

        guard let rootSecCert = SecCertificateCreateWithData(nil, Data(rootDer) as CFData),
              let intermediateSecCert = SecCertificateCreateWithData(nil, Data(intermediateDer) as CFData) else {
            XCTFail("Failed to convert to SecCertificate")
            return
        }

        // Clear singleton first
        TrustAnchorManager.shared.clear()

        // Create disposable with both types
        let disposable = TrustAnchorManager.createInstance(withAdditionalCertificates: [rootSecCert, intermediateSecCert])

        // Root should be classified as anchor (self-signed)
        XCTAssertEqual(disposable.anchorCertificates.count, 1,
                       "Should have 1 anchor certificate (self-signed)")

        // Intermediate should be classified as intermediate (not self-signed)
        XCTAssertEqual(disposable.intermediateCertificates.count, 1,
                       "Should have 1 intermediate certificate (not self-signed)")
    }

    func testDisposableInstanceHasCustomAnchors() {
        // Clear singleton
        TrustAnchorManager.shared.clear()

        // Create disposable with a self-signed certificate
        guard let rootCert = createTestCertificate() else {
            XCTFail("Failed to create certificate")
            return
        }

        let disposable = TrustAnchorManager.createInstance(withAdditionalCertificates: [rootCert])

        XCTAssertTrue(disposable.hasCustomAnchors,
                      "Disposable with self-signed cert should have custom anchors")
    }

    func testDisposableInstanceWithoutAnchors() {
        // Clear singleton
        TrustAnchorManager.shared.clear()

        // Create non-self-signed certificate
        let rootKey = P256.Signing.PrivateKey()
        let leafKey = P256.Signing.PrivateKey()

        guard let intermediateCert = createSignedCertificate(
                  subjectKey: leafKey,
                  issuerKey: rootKey,
                  issuerName: "External Root",
                  subjectName: "Intermediate"
              ) else {
            XCTFail("Failed to create certificate")
            return
        }

        let intermediateDer = try! intermediateCert.serializeAsPEM().derBytes
        guard let intermediateSecCert = SecCertificateCreateWithData(nil, Data(intermediateDer) as CFData) else {
            XCTFail("Failed to convert to SecCertificate")
            return
        }

        // Create disposable with only intermediate (no anchor)
        let disposable = TrustAnchorManager.createInstance(withAdditionalCertificates: [intermediateSecCert])

        XCTAssertFalse(disposable.hasCustomAnchors,
                       "Disposable with only intermediate certs should not have custom anchors")
    }

    // MARK: - Helper Methods

    private func createTestCertificate() -> SecCertificate? {
        guard let x509Cert = createTestX509Certificate() else {
            return nil
        }

        let derData = try? x509Cert.serializeAsPEM().derBytes
        guard let data = derData else {
            return nil
        }

        return SecCertificateCreateWithData(nil, Data(data) as CFData)
    }

    private func createTestX509Certificate() -> Certificate? {
        let privateKey = P256.Signing.PrivateKey()
        let publicKey = Certificate.PublicKey(privateKey.publicKey)
        let signingKey = Certificate.PrivateKey(privateKey)

        let name = try? DistinguishedName {
            CommonName("Test Certificate")
            OrganizationName("Test Organization")
            CountryName("JP")
        }

        guard let subjectName = name else {
            return nil
        }

        // Use a time window that is definitely valid (1 hour ago to 1 year from now)
        let notBefore = Date().addingTimeInterval(-60 * 60)
        let notAfter = Date().addingTimeInterval(60 * 60 * 24 * 365)

        let extensions = try? Certificate.Extensions {
            Critical(
                BasicConstraints.isCertificateAuthority(maxPathLength: nil)
            )
        }

        return try? Certificate(
            version: .v3,
            serialNumber: Certificate.SerialNumber(),
            publicKey: publicKey,
            notValidBefore: notBefore,
            notValidAfter: notAfter,
            issuer: subjectName,
            subject: subjectName,
            signatureAlgorithm: .ecdsaWithSHA256,
            extensions: extensions ?? Certificate.Extensions(),
            issuerPrivateKey: signingKey
        )
    }
}
