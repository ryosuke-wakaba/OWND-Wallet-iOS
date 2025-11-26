//
//  CredentialDetail.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/21.
//

import SwiftUI

struct CredentialDetail: View {
    @Environment(\.presentationMode) var presentationMode
    var credential: Credential
    var viewModel: CredentialDetailViewModel
    var deleteAction: (() -> Void)?

    @State private var showingQRCodeModal: Bool = false
    @State private var showAlert = false
    @Binding var path: [ScreensOnFullScreen]

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

                        // ------------------------- claims section -------------------------
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

                        // ------------------------- history section -------------------------
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
            await viewModel.loadData(credential: credential)
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
