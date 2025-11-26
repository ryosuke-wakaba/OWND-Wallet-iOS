//
//  CredentialDetail.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/21.
//

import SwiftUI

struct CredentialDetail: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(SharingRequestModel.self) var sharingRequestModel: SharingRequestModel?
    var credential: Credential
    var viewModel: CredentialDetailViewModel
    var deleteAction: (() -> Void)?

    @State private var showingQRCodeModal: Bool = false
    @State private var showAlert = false
    @State private var userSelectableClaims: [DisclosureWithOptionality] = []
    @State private var dataLoaded: Bool = false
    @Binding var path: [ScreensOnFullScreen]

    /// VP mode is determined by whether sharingRequestModel has a dcqlQuery
    private var vpMode: Bool {
        sharingRequestModel?.dcqlQuery != nil
    }

    init(
        viewModel: CredentialDetailViewModel = CredentialDetailViewModel(),
        credential: Credential,
        path: Binding<[ScreensOnFullScreen]>,
        deleteAction: (() -> Void)? = nil
    ) {
        print("init")
        self.viewModel = viewModel
        self.credential = credential
        self._path = path
        self.deleteAction = deleteAction
    }

    var body: some View {
        Group {
            if viewModel.dataModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
            else {
                ScrollView {
                    VStack {
                        // ------------------------- card section -------------------------
                        CredentialRow(credential: self.credential)
                            .aspectRatio(1.6, contentMode: .fit)
                            .frame(maxWidth: .infinity)

                        // ------------------------- issuer section -------------------------
                        let issuedByText = String(
                            format: NSLocalizedString("IssuedBy", comment: ""),
                            credential.issuerDisplayName)
                        Text(issuedByText)
                            .underline()
                            .modifier(BodyGray())
                            .onTapGesture {
                                path.append(.issuerDetail(credential))
                            }
                            .padding(.vertical, 8)

                        // ------------------------- QR code section -------------------------
                        if !vpMode {
                            // QR表示画面のリンク
                            if CredentialFormat(formatString: self.credential.format) == .jwtVCJson {
                                Text("display_qr_code")
                                    .underline()
                                    .modifier(BodyGray())
                                    .padding(.vertical, 8)
                                    .onTapGesture {
                                        self.showingQRCodeModal = true
                                    }
                                    .padding(.vertical, 8)
                            }
                        }

                        // ------------------------- claims section -------------------------
                        if !vpMode {
                            Text("Contents of this certificate")
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)  // 左寄せ
                                .modifier(BodyGray())

                            if let disclosureDict = credential.disclosure {
                                ForEach(disclosureDict.sorted(by: { $0.key < $1.key }), id: \.key) {
                                    key, value in
                                    let submitDisclosure = DisclosureWithOptionality(
                                        disclosure: Disclosure(
                                            disclosure: nil,
                                            key: key,
                                            value: value),
                                        isSubmit: false, isUserSelectable: false)
                                    DisclosureRow(submitDisclosure: .constant(submitDisclosure))
                                }
                            }
                        }
                        else if dataLoaded {
                            // required claims
                            Text("Sharing Contents of this certificate")
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .modifier(BodyGray())
                            ForEach(viewModel.requiredClaims, id: \.self.disclosure.id) { it in
                                DisclosureRow(submitDisclosure: .constant(it))
                            }

                            // undisclosed claims
                            Text("Not Sharing Contents of this certificate")
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .modifier(BodyGray())
                            ForEach(viewModel.undisclosedClaims, id: \.self.disclosure.id) { it in
                                DisclosureRow(submitDisclosure: .constant(it))
                            }

                            // Claims that can be disclosed or not at the user's will.
                            Text("optional_to_provide")
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .modifier(BodyGray())
                            ForEach($userSelectableClaims, id: \.self.disclosure.id) { $claim in
                                DisclosureRow(submitDisclosure: $claim)
                            }
                        }

                        // ------------------------- history section -------------------------
                        if !vpMode {
                            Text("History of information provided")
                                .padding(.vertical, 16)
                                .frame(maxWidth: .infinity, alignment: .leading)  // 左寄せ
                                .modifier(BodyGray())
                            LazyVStack(spacing: 16) {
                                ForEach(self.viewModel.dataModel.sharingHistories, id: \.createdAt)
                                { history in
                                    HistoryRow(history: history)
                                        .padding(.vertical, 6)
                                }
                            }
                        }

                        // ------------------------- button section -------------------------
                        if vpMode {
                            ActionButtonBlack(
                                title: "Select This Credential",
                                action: {
                                    let claims = (viewModel.requiredClaims + userSelectableClaims)
                                        .filter { it in
                                            it.isSubmit
                                        }
                                    let submissionCredential = viewModel.createSubmissionCredential(
                                        credential: credential,
                                        discloseClaims: claims
                                    )
                                    sharingRequestModel?.setSelectedCredentials(
                                        data: [submissionCredential],
                                        metadata: credential.metaData
                                    )
                                    path.removeLast(2)
                                }
                            )
                            .padding(.vertical, 16)
                        }
                    }
                    .padding(.horizontal, 16)  // 左右に16dpのパディング
                    .padding(.vertical, 16)
                }
                .navigationTitle(LocalizedStringKey(self.credential.credentialType))
                .navigationBarTitleDisplayMode(.inline)
                .sheet(
                    isPresented: $showingQRCodeModal,
                    content: {
                        DisplayQRCode(credential: credential)
                    }
                )
                .toolbar {
                    if deleteAction != nil {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Menu(
                                content: {
                                    Button(action: {
                                        showAlert = true
                                    }) {
                                        Text("Delete")
                                    }
                                },
                                label: {
                                    Image(systemName: "ellipsis")
                                })
                        }
                    }
                }
                .alert(isPresented: $showAlert) {
                    Alert(
                        title: Text("Confirm To Delete"),
                        message: Text("Are you sure to delete this credential?"),
                        primaryButton: .destructive(Text("Delete")) {
                            if let action = deleteAction {
                                action()
                            }
                            presentationMode.wrappedValue.dismiss()
                        },
                        secondaryButton: .cancel()
                    )
                }
            }
        }
        .task {
            if let query = sharingRequestModel?.dcqlQuery {
                await viewModel.loadData(credential: credential, dcqlQuery: query)
                self.userSelectableClaims = viewModel.userSelectableClaims
            }
            else {
                await viewModel.loadData(credential: credential)
            }
            self.dataLoaded = true
        }
    }
}

#Preview("1. format: sd-jwt, card: image") {
    CredentialDetail(
        viewModel: DetailPreviewModel(),
        credential: PreviewSampleData.sampleSdJwtCredentialWithImage(),
        path: .constant([])
    )
}

#Preview("2. format: sd-jwt, card: bg-color") {
    CredentialDetail(
        viewModel: DetailPreviewModel(),
        credential: PreviewSampleData.sampleSdJwtCredentialWithColor(),
        path: .constant([])
    )
}

#Preview("3. format: jwt-vc-json") {
    CredentialDetail(
        viewModel: DetailPreviewModel(),
        credential: PreviewSampleData.sampleJwtVcJsonCredential(),
        path: .constant([])
    )
}

#Preview("4. mode: vp-sharing") {
    let viewModel = DetailVPModePreviewModel()
    let query = viewModel.dummyDcqlQuery1()
    return CredentialDetail(
        viewModel: viewModel,
        credential: PreviewSampleData.sampleJwtVcJsonCredential(),
        path: .constant([])
    ).environment(SharingRequestModel(dcqlQuery: query))
}

#Preview("5. mode: vp-sharing with optional field") {
    let viewModel = DetailVPModePreviewModel()
    let query = viewModel.dummyDcqlQuery2()
    return CredentialDetail(
        viewModel: viewModel,
        credential: PreviewSampleData.sampleJwtVcJsonCredential(),
        path: .constant([])
    ).environment(SharingRequestModel(dcqlQuery: query))
}
