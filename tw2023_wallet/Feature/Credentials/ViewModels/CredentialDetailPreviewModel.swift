//
//  CredentialDetailPreviewModel.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2023/12/27.
//

import Foundation

class DetailPreviewModel: CredentialDetailViewModel {
    override func loadData(credential: Credential) async {
        // mock data for preview (without bundle access)
        dataModel.isLoading = true
        print("load dummy data..")
        // Use empty history for preview to avoid bundle access
        self.dataModel.sharingHistories = []
        print("done")
        dataModel.isLoading = false
        dataModel.hasLoadedData = true
    }
}

// MARK: - Preview Sample Data

/// Helper to create sample credentials for SwiftUI previews without bundle access
enum PreviewSampleData {
    private static let sampleMetadataJson = """
    {
        "credential_issuer": "https://example.com",
        "credential_endpoint": "https://example.com/credentials",
        "credential_configurations_supported": {
            "IdentityCredential": {
                "format": "dc+sd-jwt",
                "vct": "IdentityCredential",
                "display": [
                    {
                        "name": "Identity Credential",
                        "locale": "en-US",
                        "background_color": "#12107c",
                        "text_color": "#FFFFFF"
                    }
                ]
            }
        },
        "display": [
            {
                "name": "Sample Issuer",
                "locale": "en-US"
            }
        ]
    }
    """

    static func sampleMetadata() -> CredentialIssuerMetadata {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let data = sampleMetadataJson.data(using: .utf8)!
        return try! decoder.decode(CredentialIssuerMetadata.self, from: data)
    }

    /// Sample SD-JWT credential with background image
    static func sampleSdJwtCredentialWithImage() -> Credential {
        Credential(
            id: "001",
            format: "vc+sd-jwt",
            payload: "QmFzZTY0RW5jb2RlZENvbnRlbnQ=",
            issuer: "https://example.com",
            issuerDisplayName: "Sample Issuer",
            issuedAt: "2024-01-01T12:00:00Z",
            logoUrl: nil,
            backgroundColor: nil,
            backgroundImageUrl: "https://example.com/image.png",
            textColor: nil,
            credentialType: "IdentityCredential",
            disclosure: [
                "name": "Yamada Taro",
                "birth_of_date": "2000-10-20",
                "is_older_than_18": "True"
            ],
            certificates: nil,
            qrDisplay: "",
            metaData: sampleMetadata()
        )
    }

    /// Sample SD-JWT credential with background color
    static func sampleSdJwtCredentialWithColor() -> Credential {
        Credential(
            id: "002",
            format: "vc+sd-jwt",
            payload: "U29tZU90aGVyQmFzZTY0RW5jb2RlZENvbnRlbnQ=",
            issuer: "https://example.com",
            issuerDisplayName: "Sample Corp",
            issuedAt: "2024-01-01T12:00:00Z",
            logoUrl: nil,
            backgroundColor: "#FF5733",
            backgroundImageUrl: nil,
            textColor: "#000000",
            credentialType: "EmployeeCredential",
            disclosure: [
                "employeeNo": "12345",
                "division": "Engineering"
            ],
            certificates: nil,
            qrDisplay: "",
            metaData: sampleMetadata()
        )
    }

    /// Sample JWT-VC-JSON credential
    static func sampleJwtVcJsonCredential() -> Credential {
        Credential(
            id: "003",
            format: "jwt_vc_json",
            payload: "eyJhbGciOiJFUzI1NiJ9.eyJ0ZXN0IjoidmFsdWUifQ.signature",
            issuer: "https://example.com",
            issuerDisplayName: "Event Organizer",
            issuedAt: "2024-01-01T12:00:00Z",
            logoUrl: nil,
            backgroundColor: "#33ffd3",
            backgroundImageUrl: nil,
            textColor: "#ff0000",
            credentialType: "ParticipationCertificate",
            disclosure: nil,
            certificates: nil,
            qrDisplay: "",
            metaData: sampleMetadata()
        )
    }
}
