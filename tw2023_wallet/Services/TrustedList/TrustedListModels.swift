//
//  TrustedListModels.swift
//  tw2023_wallet
//
//  Data models for ETSI TS 119 602 (LoTE: List of Trusted Entities) format.
//

import Foundation

// MARK: - Root Structure

/// LoTE (List of Trusted Entities) document root
struct LoTEDocument: Codable {
    let LoTE: LoTE
}

/// Main LoTE structure
struct LoTE: Codable {
    let ListAndSchemeInformation: ListAndSchemeInformation
    let TrustedEntitiesList: [TrustedEntity]
}

// MARK: - Scheme Information

struct ListAndSchemeInformation: Codable {
    let LoTEVersionIdentifier: Int
    let LoTESequenceNumber: Int
    let SchemeOperatorName: [LocalizedString]
    let SchemeOperatorAddress: SchemeOperatorAddress?
    let ListIssueDateTime: String
    let NextUpdate: String?
    let LoTEType: String?
    let SchemeName: [LocalizedString]?
    let SchemeInformationURI: [LocalizedURI]?
    let StatusDeterminationApproach: String?
    let SchemeTerritory: String?
    let HistoricalInformationPeriod: Int?
}

struct SchemeOperatorAddress: Codable {
    let SchemeOperatorPostalAddress: [PostalAddress]?
    let SchemeOperatorElectronicAddress: [LocalizedURI]?
}

struct PostalAddress: Codable {
    let lang: String?
    let StreetAddress: String?
    let Locality: String?
    let PostalCode: String?
    let Country: String?
}

// MARK: - Trusted Entity

struct TrustedEntity: Codable {
    let TrustedEntityInformation: TrustedEntityInformation
    let TrustedEntityServices: [TrustedEntityService]
}

struct TrustedEntityInformation: Codable {
    let TEName: [LocalizedString]
    let TETradeName: [LocalizedString]?
    let TEAddress: TEAddress?
    let TEInformationURI: [LocalizedURI]?
}

struct TEAddress: Codable {
    let TEPostalAddress: [PostalAddress]?
    let TEElectronicAddress: [LocalizedURI]?
}

// MARK: - Service

struct TrustedEntityService: Codable {
    let ServiceInformation: ServiceInformation
}

struct ServiceInformation: Codable {
    let ServiceName: [LocalizedString]
    let ServiceDigitalIdentity: ServiceDigitalIdentity
    let ServiceTypeIdentifier: String
    let ServiceStatus: String
    let StatusStartingTime: String
    let ServiceSupplyPoints: [URIValue]?
}

struct ServiceDigitalIdentity: Codable {
    let X509Certificates: [String]?
}

// MARK: - Common Types

struct LocalizedString: Codable {
    let lang: String
    let value: String
}

struct LocalizedURI: Codable {
    let lang: String
    let uriValue: String
}

struct URIValue: Codable {
    let uriValue: String
}

// MARK: - Service Type Constants

enum TrustedListServiceType {
    /// Credential Issuance service type
    static let credentialIssuance = "http://example.com/SvcType/CredentialIssuance"

    /// Credential Verifier service type (ETSI standard)
    static let credentialVerifier = "http://uri.etsi.org/TrstSvc/Svctype/CA/QC"

    /// Wallet Provider service type (ETSI standard)
    static let walletProvider = "http://uri.etsi.org/TrstSvc/Svctype/WalletProvider"
}

// MARK: - Service Status Constants

enum TrustedListServiceStatus {
    /// Service is granted/active
    static let granted = "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/granted"

    /// Service is withdrawn
    static let withdrawn = "http://uri.etsi.org/TrstSvc/TrustedList/Svcstatus/withdrawn"
}
