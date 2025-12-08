//
//  RecipientOrgInfo.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2024/01/11.
//

import SwiftUI

struct RecipientOrgInfo: View {
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false

    var clientInfo: ClientInfo

    // MARK: - Validation Helpers

    /// Check if a string looks like a valid domain name (contains a dot and no spaces)
    private func isValidDomain(_ value: String?) -> Bool {
        guard let value = value, !value.isEmpty else { return false }
        // Domain should contain at least one dot and no spaces
        return value.contains(".") && !value.contains(" ")
    }

    /// Check if a string is a valid URL
    private func isValidUrl(_ value: String?) -> Bool {
        guard let value = value, !value.isEmpty else { return false }
        return URL(string: value) != nil && (value.hasPrefix("http://") || value.hasPrefix("https://"))
    }

    /// Check if country code appears valid (2-letter ISO code or known country name)
    private func isValidCountry(_ value: String?) -> Bool {
        guard let value = value, !value.isEmpty else { return false }
        // Accept 2-letter country codes or longer country names
        return value.count >= 2
    }

    /// Check if there is any recipient information to display
    private var hasRecipientInfo: Bool {
        // Has certificate info with organization
        if let cert = clientInfo.certificateInfo {
            if cert.organization != nil && !(cert.organization?.isEmpty ?? true) {
                return true
            }
        }
        // Has client name from metadata
        if !clientInfo.name.isEmpty {
            return true
        }
        return false
    }

    /// Display name for the recipient (organization from cert or client name)
    private var recipientDisplayName: String {
        if let org = clientInfo.certificateInfo?.organization, !org.isEmpty {
            return org
        }
        return clientInfo.name.isEmpty ? "Unknown" : clientInfo.name
    }

    /// Check if location info is available
    private var hasLocationInfo: Bool {
        guard let cert = clientInfo.certificateInfo else { return false }
        let state = cert.state ?? ""
        let locality = cert.locality ?? ""
        return !state.isEmpty || !locality.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Only show recipient info section if we have meaningful data
            if hasRecipientInfo {
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Group {
                            if let logoView = clientInfo.logoImage {
                                logoView
                            }
                            else {
                                Color.clear
                            }
                        }
                        .frame(width: 70, height: 70)
                        Text(recipientDisplayName).modifier(TitleBlack())
                    }
                    // Only show "verified by" if issuer organization is valid
                    if clientInfo.verified,
                       let issuer = clientInfo.certificateInfo?.issuer,
                       let issuerOrg = issuer.organization,
                       !issuerOrg.isEmpty {
                        HStack {
                            Image("verifier_mark")
                            Text("verified by").modifier(SubHeadLineGray())
                            Text(issuerOrg).modifier(SubHeadLineGray())
                        }
                    }
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let certificateInfo = clientInfo.certificateInfo {
                // Domain - only show if it looks like a valid domain
                if isValidDomain(certificateInfo.domain) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("domain")
                            .modifier(SubHeadLineGray())
                        Text(certificateInfo.domain!)
                            .modifier(BodyBlack())
                    }
                    .padding(.vertical, 16)
                }

                // Location - only show if we have state or locality
                if hasLocationInfo {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("cert_location")
                            .modifier(SubHeadLineGray())
                        HStack {
                            if let state = certificateInfo.state, !state.isEmpty {
                                Text(state)
                            }
                            if let locality = certificateInfo.locality, !locality.isEmpty {
                                Text(locality)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }

                // Country - only show if we have a valid country
                if isValidCountry(certificateInfo.country) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("cert_country")
                            .modifier(SubHeadLineGray())
                        Text(certificateInfo.country!)
                            .modifier(BodyBlack())
                    }
                    .padding(.vertical, 16)
                }

                // Contact - only show if we have a valid domain or email
                if isValidDomain(certificateInfo.domain) || (certificateInfo.email != nil && !certificateInfo.email!.isEmpty) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("contact")
                            .modifier(SubHeadLineGray())
                        if let email = certificateInfo.email, !email.isEmpty {
                            Text(email)
                                .modifier(BodyBlack())
                        } else if let domain = certificateInfo.domain {
                            Text(domain)
                                .modifier(BodyBlack())
                        }
                    }
                    .padding(.vertical, 16)
                }
            }

            // Terms of Use - only show if we have a valid URL
            if isValidUrl(clientInfo.tosUrl) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("terms_of_use")
                        .modifier(SubHeadLineGray())
                    Button(action: {
                        self.showTermsOfUse = true
                    }) {
                        Text(clientInfo.tosUrl)
                            .modifier(BodyBlack())
                            .underline()
                            .sheet(
                                isPresented: $showTermsOfUse,
                                content: {
                                    SafariView(url: URL(string: clientInfo.tosUrl)!)
                                })
                    }
                }
                .padding(.vertical, 16)
            }

            // Privacy Policy - only show if we have a valid URL
            if isValidUrl(clientInfo.policyUrl) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("privacy_policy")
                        .modifier(SubHeadLineGray())
                    Button(action: {
                        self.showPrivacyPolicy = true
                    }) {
                        Text(clientInfo.policyUrl)
                            .modifier(BodyBlack())
                            .underline()
                            .sheet(
                                isPresented: $showPrivacyPolicy,
                                content: {
                                    SafariView(url: URL(string: clientInfo.policyUrl)!)
                                })
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 16)
            }
        }
    }
}

#Preview {
    let modelData = ModelData()
    modelData.loadClientInfoList()
    return RecipientOrgInfo(clientInfo: modelData.clientInfoList[0])
}
