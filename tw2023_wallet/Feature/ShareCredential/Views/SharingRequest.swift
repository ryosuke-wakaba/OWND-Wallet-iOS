//
//  SharingRequest.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/22.
//

import SwiftUI

struct SharingRequest: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(SharingRequestModel.self) var sharingRequestModel
    @State var viewModel: SharingRequestViewModel = SharingRequestViewModel()
    var args: SharingCredentialArgs

    @State var authenticated = false
    @State var showAlert = false
    @State var alertTitle = ""
    @State var alertMessage = ""

    @State var proofBy = ""

    // Credential picker sheet
    @State private var showCredentialPicker = false
    @State private var displayCredential: Credential?
    @State private var claimsLoaded = false

    var body: some View {
        NavigationStack {
            GeometryReader { _ in
                Group {
                    if viewModel.isLoading {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                ProgressView().progressViewStyle(CircularProgressViewStyle())
                                Spacer()
                            }
                            Spacer()
                        }
                    }
                    else {
                        if let clientInfo = viewModel.clientInfo {
                            ScrollView {
                                VStack {
                                    HStack {
                                        Button("Cancel") {
                                            presentationMode.wrappedValue.dismiss()
                                        }
                                        .padding(.vertical, 16)
                                        Spacer()
                                    }
                                    // ------------ title section ------------
                                    // Use recipient display name (organization from cert or client name)
                                    let recipientName = clientInfo.certificateInfo?.organization ?? clientInfo.name
                                    let displayName = recipientName.isEmpty ? NSLocalizedString("unknown_recipient", comment: "") : recipientName
                                    let titleKey = "provide_the_information_required_to_register"
                                    let title = String(
                                        format: NSLocalizedString(titleKey, comment: ""),
                                        displayName)
                                    Text(title)
                                        .modifier(Title3Black())
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    Divider()
                                        .padding(.vertical, 8)

                                    // ------------ logo to logo section ------------
                                    if let logoView = clientInfo.logoImage {
                                        HStack {
                                            Image("logo_ownd")
                                                .padding(.trailing, 8)
                                            Image(systemName: "arrow.forward")
                                                .modifier(TitleGray())
                                                .fontWeight(.black)
                                                .padding(.horizontal, 8)
                                            logoView
                                                .frame(width: 70, height: 70)
                                                .padding(.horizontal, 8)
                                        }
                                        .padding(.vertical, 16)
                                    }

                                    Divider()
                                        .padding(.vertical, 8)

                                    // ------------ sharing data info section ------------
                                    Text(
                                        String(
                                            format: NSLocalizedString(
                                                "information_provided_to", comment: ""),
                                            displayName)
                                    )
                                    .modifier(BodyGray())
                                    .frame(maxWidth: .infinity, alignment: .leading)  // 左寄せ
                                    .padding(.top, 16)

                                    if viewModel.dcqlQuery != nil
                                    {
                                        if viewModel.selectedCredential {
                                            // ------------ selected credential info ------------
                                            StatusBox(displayText: $proofBy, status: .success)
                                            Text("change_credential")
                                                .modifier(BodyBlack())
                                                .underline()
                                                .padding(.vertical, 8)
                                                .onTapGesture {
                                                    viewModel.selectedCredential = false
                                                    sharingRequestModel.data = nil
                                                    displayCredential = nil
                                                    claimsLoaded = false
                                                    viewModel.loadFilteredCredentials()
                                                    showCredentialPicker = true
                                                }

                                            // ------------ claims display section ------------
                                            if claimsLoaded {
                                                // required claims
                                                Text("Sharing Contents of this certificate")
                                                    .padding(.vertical, 16)
                                                    .frame(maxWidth: .infinity, alignment: .leading)
                                                    .modifier(BodyGray())
                                                ForEach(viewModel.requiredClaims, id: \.self.disclosure.id) { it in
                                                    DisclosureRow(submitDisclosure: .constant(it))
                                                }

                                                // undisclosed claims
                                                if !viewModel.undisclosedClaims.isEmpty {
                                                    Text("Not Sharing Contents of this certificate")
                                                        .padding(.vertical, 16)
                                                        .frame(maxWidth: .infinity, alignment: .leading)
                                                        .modifier(BodyGray())
                                                    ForEach(viewModel.undisclosedClaims, id: \.self.disclosure.id) { it in
                                                        DisclosureRow(submitDisclosure: .constant(it))
                                                    }
                                                }
                                            }
                                        }
                                        else {
                                            StatusBox(
                                                displayText: .constant("no_certificate_selected"),
                                                status: .warning)
                                            ActionButtonWhite(
                                                title: "select_a_certificate",
                                                action: {
                                                    viewModel.loadFilteredCredentials()
                                                    showCredentialPicker = true
                                                })
                                        }
                                    }
                                    else {
                                        ProvideID(clientInfo: clientInfo)
                                    }

                                    Divider()
                                        .padding(.vertical, 8)

                                    // ------------ recipient org info section ------------
                                    VStack(alignment: .leading, spacing: 0) {
                                        Text("recipient _organization_information")
                                            .modifier(BodyGray())
                                        RecipientOrgInfo(clientInfo: clientInfo)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)  // 左寄せ
                                    .padding(.vertical, 16)

                                    Divider()
                                        .padding(.vertical, 8)

                                    // ------------ sharing button section ------------
                                    if viewModel.dcqlQuery == nil
                                        || viewModel.selectedCredential
                                    {
                                        ActionButtonBlack(
                                            title: "provide_information",
                                            action: {
                                                Task {
                                                    let result = await viewModel.shareToken(
                                                        credentials: sharingRequestModel.data)
                                                    switch result {
                                                        case .success(let postResult):
                                                            print("Token sharing succeeded.")
                                                            if postResult.location != nil {
                                                                sharingRequestModel.postResult =
                                                                    postResult
                                                            }
                                                            showAlert = true
                                                            alertTitle =
                                                                "Token sharing succeeded."
                                                        case .failure(let error):
                                                            print(
                                                                "Token sharing failed with error: \(error)"
                                                            )
                                                            showAlert = true
                                                    }
                                                }
                                            }
                                        )
                                        .padding(.vertical, 16)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
            .onChange(of: sharingRequestModel.data) {
                if sharingRequestModel.data != nil {
                    viewModel.selectedCredential = true
                    if let submission = sharingRequestModel.data,
                        let metadata = sharingRequestModel.metadata,
                        let firstSubmission = submission.first  // Workaround until multiple credentials are possible on the UI.
                    {
                        if let credentialSupported = VCIMetadataUtil.findMatchingCredentials(
                            format: firstSubmission.format,
                            types: firstSubmission.types,
                            metadata: metadata
                        ) {
                            if let display = credentialSupported.display {
                                proofBy = String(
                                    format: NSLocalizedString("proof_by", comment: ""),
                                    display[0].name)
                            }
                        }
                    }
                }
            }
            .onChange(of: viewModel.clientInfo) {
                if let clientInfo = viewModel.clientInfo {
                    print("client info changed: \(clientInfo)")
                }
            }
            .onAppear {
                Task {
                    print("accessPairwiseAccountManager")
                    if !authenticated {
                        let b = await viewModel.accessPairwiseAccountManager()
                        if b {
                            authenticated = true
                            if let url = args.url {
                                await viewModel.loadData(url)
                                if viewModel.dcqlQuery != nil {
                                    sharingRequestModel.dcqlQuery =
                                        viewModel.dcqlQuery
                                }
                                showAlert = viewModel.showAlert
                                alertTitle = viewModel.alertTitle
                                alertMessage = viewModel.alertMessage
                            }
                        }
                        else {
                            print("showAuthenticationFailedAlert")
                            alertTitle = "Authentication Failed"
                            alertMessage = "Unable to authenticate. Please try again."
                            showAlert = true
                        }
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text(alertTitle),
                    message: Text(alertMessage),
                    dismissButton: .default(Text("OK")) {
                        presentationMode.wrappedValue.dismiss()
                    }
                )
            }
            .sheet(isPresented: $showCredentialPicker, onDismiss: nil) {
                CredentialPickerSheet(
                    credentials: viewModel.filteredCredentials,
                    onSelect: { credential in
                        selectCredential(credential)
                    }
                )
            }
        }
    }

    private func selectCredential(_ credential: Credential) {
        displayCredential = credential

        // Classify claims using viewModel
        viewModel.classifyClaims(credential: credential)

        // Create submission credential
        if let submissionCredential = viewModel.createSubmissionCredential(
            credential: credential,
            discloseClaims: viewModel.requiredClaims
        ) {
            sharingRequestModel.setSelectedCredentials(
                data: [submissionCredential],
                metadata: credential.metaData
            )
        }

        // Update UI state
        viewModel.selectedCredential = true
        if let credentialSupported = VCIMetadataUtil.findMatchingCredentials(
            format: credential.format,
            types: try! VCIMetadataUtil.extractTypes(format: credential.format, credential: credential.payload),
            metadata: credential.metaData
        ) {
            if let display = credentialSupported.display {
                proofBy = String(
                    format: NSLocalizedString("proof_by", comment: ""),
                    display[0].name)
            }
        }
        claimsLoaded = true
    }
}

// MARK: - Credential Picker Sheet

struct CredentialPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    var credentials: [Credential]
    var onSelect: (Credential) -> Void

    var body: some View {
        NavigationStack {
            Group {
                if credentials.isEmpty {
                    VStack {
                        Spacer()
                        Text("no_certificate")
                            .modifier(BodyGray())
                        Spacer()
                    }
                }
                else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(credentials) { credential in
                                VStack(alignment: .leading) {
                                    Text(LocalizedStringKey(credential.credentialType))
                                        .font(.headline)
                                        .padding(.leading, 16)
                                    CredentialRow(credential: credential)
                                        .aspectRatio(1.6, contentMode: .fit)
                                        .frame(maxWidth: .infinity)
                                        .onTapGesture {
                                            onSelect(credential)
                                            dismiss()
                                        }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                }
            }
            .navigationTitle("select_a_certificate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - Previews

#Preview("ID Token Sharing") {
    let args = SharingCredentialArgs()
    args.url = "openid://xxx"
    let viewModel = SharingRequestPreviewModel()
    return SharingRequest(viewModel: viewModel, args: args)
        .environment(SharingRequestModel())
    // return SharingRequest(viewModel: viewModel).environment(args)
}

#Preview("VP Sharing before credential is selected") {
    let args = SharingCredentialArgs()
    args.url = "openid://xxx"
    let viewModel = SharingRequestVPPreviewModel()
    return SharingRequest(viewModel: viewModel, args: args)
        .environment(SharingRequestModel())
    // return SharingRequest(viewModel: viewModel).environment(args)
}

#Preview("VP Sharing") {
    let args = SharingCredentialArgs()
    args.url = "openid://xxx"
    let viewModel = SharingRequestVPPreviewModel()
    viewModel.selectedCredential = true
    return SharingRequest(viewModel: viewModel, args: args)
        .environment(SharingRequestModel())
    // return SharingRequest(viewModel: viewModel).environment(args)
}

#Preview("Biometric Error") {
    let args = SharingCredentialArgs()
    args.url = "openid://xxx"
    let viewModel = SharingRequestBiometricErrorPreviewModel()
    return SharingRequest(viewModel: viewModel, args: args)
        .environment(SharingRequestModel())
    // return SharingRequest(viewModel: viewModel).environment(args)
}

#Preview("Sharing Error") {
    let args = SharingCredentialArgs()
    args.url = "openid://xxx"
    let viewModel = SharingRequestLoadDataErrorPreviewModel()
    return SharingRequest(viewModel: viewModel, args: args)
        .environment(SharingRequestModel())
}
