//
//  CredentialIssuanceErrors.swift
//  tw2023_wallet
//
//  Created by Claude on 2025/01/14.
//

import Foundation

/// Errors that can occur during the credential issuance process (OID4VCI)
enum CredentialIssuanceError: Error {
    // Data Loading Errors
    case loadDataDidNotFinishSuccessfully
    case credentialOfferConfigurationIsEmpty

    // Proof Generation Errors
    case proofGenerationFailed
    case unsupportedProofType(supportedTypes: [String])

    // Deferred Issuance Errors
    case transactionIdIsRequired
    case deferredIssuanceIsNotSupported

    // Data Conversion Errors
    case credentialToBeConvertedDoesNotExist
    case failedToConvertToInternalFormat

    // Credential Offer Format Errors
    case credentialOfferQueryItemsNotFound
    case credentialOfferParameterNotFound
    case invalidCredentialOffer
}

extension CredentialIssuanceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .loadDataDidNotFinishSuccessfully:
            return NSLocalizedString(
                "Failed to load credential metadata. Please try again.",
                comment: "Error when metadata loading fails")

        case .credentialOfferConfigurationIsEmpty:
            return NSLocalizedString(
                "The credential offer does not contain any credentials.",
                comment: "Error when credential offer is empty")

        case .proofGenerationFailed:
            return NSLocalizedString(
                "Failed to generate cryptographic proof.",
                comment: "Error when proof generation fails")

        case .unsupportedProofType(let supportedTypes):
            let typesString = supportedTypes.joined(separator: ", ")
            return String(
                format: NSLocalizedString(
                    "Unsupported proof type. Supported types: %@",
                    comment: "Error when proof type is not supported"),
                typesString)

        case .transactionIdIsRequired:
            return NSLocalizedString(
                "Transaction ID is required but was not provided.",
                comment: "Error when transaction ID is missing")

        case .deferredIssuanceIsNotSupported:
            return NSLocalizedString(
                "Deferred credential issuance is not yet supported.",
                comment: "Error when deferred issuance is attempted")

        case .credentialToBeConvertedDoesNotExist:
            return NSLocalizedString(
                "The credential to be saved does not exist.",
                comment: "Error when credential is missing")

        case .failedToConvertToInternalFormat:
            return NSLocalizedString(
                "Failed to convert credential to internal storage format.",
                comment: "Error when credential conversion fails")

        case .credentialOfferQueryItemsNotFound:
            return NSLocalizedString(
                "Invalid credential offer URL: query parameters not found.",
                comment: "Error when URL query items are missing")

        case .credentialOfferParameterNotFound:
            return NSLocalizedString(
                "Invalid credential offer URL: required parameter not found.",
                comment: "Error when credential offer parameter is missing")

        case .invalidCredentialOffer:
            return NSLocalizedString(
                "Invalid credential offer format.",
                comment: "Error when credential offer is invalid")
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .loadDataDidNotFinishSuccessfully:
            return NSLocalizedString(
                "Check your network connection and try scanning the QR code again.",
                comment: "Recovery suggestion for metadata loading failure")

        case .credentialOfferConfigurationIsEmpty:
            return NSLocalizedString(
                "Please contact the credential issuer for a valid offer.",
                comment: "Recovery suggestion for empty credential offer")

        case .proofGenerationFailed:
            return NSLocalizedString(
                "Please try again. If the problem persists, restart the app.",
                comment: "Recovery suggestion for proof generation failure")

        case .unsupportedProofType:
            return NSLocalizedString(
                "This credential issuer requires a proof type that is not yet supported. Please contact the app developer.",
                comment: "Recovery suggestion for unsupported proof type")

        case .transactionIdIsRequired:
            return NSLocalizedString(
                "The credential response is incomplete. Please try again.",
                comment: "Recovery suggestion for missing transaction ID")

        case .deferredIssuanceIsNotSupported:
            return NSLocalizedString(
                "This issuer uses deferred issuance which is not yet supported. Please try a different issuer.",
                comment: "Recovery suggestion for deferred issuance")

        case .credentialToBeConvertedDoesNotExist:
            return NSLocalizedString(
                "The credential was not received from the issuer. Please try again.",
                comment: "Recovery suggestion for missing credential")

        case .failedToConvertToInternalFormat:
            return NSLocalizedString(
                "Failed to save the credential. Please try again.",
                comment: "Recovery suggestion for conversion failure")

        case .credentialOfferQueryItemsNotFound,
             .credentialOfferParameterNotFound,
             .invalidCredentialOffer:
            return NSLocalizedString(
                "The QR code format is invalid. Please scan a valid credential offer QR code.",
                comment: "Recovery suggestion for invalid credential offer URL")
        }
    }

    var failureReason: String? {
        switch self {
        case .loadDataDidNotFinishSuccessfully:
            return "Required metadata could not be loaded from the credential issuer."

        case .credentialOfferConfigurationIsEmpty:
            return "The credential_configuration_ids field is empty in the credential offer."

        case .proofGenerationFailed:
            return "Failed to create JWT proof using the binding key."

        case .unsupportedProofType(let supportedTypes):
            return "The issuer requires proof types: \(supportedTypes.joined(separator: ", ")), but only 'jwt' is currently supported."

        case .transactionIdIsRequired:
            return "The credential response contains neither 'credential' nor 'transaction_id'."

        case .deferredIssuanceIsNotSupported:
            return "Deferred issuance flow is not implemented."

        case .credentialToBeConvertedDoesNotExist:
            return "The 'credential' field in the credential response is nil."

        case .failedToConvertToInternalFormat:
            return "JSON encoding of credential metadata failed."

        case .credentialOfferQueryItemsNotFound:
            return "URL does not contain query parameters."

        case .credentialOfferParameterNotFound:
            return "The 'credential_offer' or 'credential_offer_uri' parameter is missing."

        case .invalidCredentialOffer:
            return "The credential offer JSON is malformed or does not conform to the OID4VCI specification."
        }
    }
}
