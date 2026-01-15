//
//  CredentialList.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/21.
//

import SwiftUI

struct CredentialList: View {
    @State var viewModel: CredentialListViewModel

    // full screenから開かれたDetailで必要なのでここでは空の配列を固定で持つ
    @State var dummyPath: [ScreensOnFullScreen] = []

    // QRReader → CredentialOffer フロー用
    @State private var showQRReader = false
    @State private var showCredentialOffer = false
    @State private var nextScreen: ScreensOnFullScreen = .root
    @State private var sharedArgs = SharedArgs()

    init(viewModel: CredentialListViewModel = CredentialListViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        NavigationStack(path: $dummyPath) {
            Group {
                if viewModel.dataModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                }
                else if viewModel.dataModel.credentials.isEmpty {
                    GeometryReader { geometry in
                        HStack {
                            Spacer()  // 左側のスペース
                            VStack {
                                Text("no_certificate").modifier(LargeTitleBlack()).padding(
                                    .vertical, 64)
                                Image("tap_to_add")
                                    .resizable()
                                    .aspectRatio(1.6, contentMode: .fit)
                                    .frame(
                                        width: geometry.size.width * 0.85,
                                        height: geometry.size.width * 0.53125
                                    )
                                    .onTapGesture {
                                        showQRReader = true  // QRリーダーを直接起動
                                    }
                            }
                            Spacer()  // 右側のスペース
                        }
                    }
                }
                else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.dataModel.credentials) { credential in
                                VStack(alignment: .leading) {
                                    Text(LocalizedStringKey(credential.credentialType))
                                        .font(.headline)
                                        .padding(.leading, 16)
                                    NavigationLink(
                                        destination: CredentialDetail(
                                            credential: credential,
                                            path: $dummyPath,
                                            deleteAction: {
                                                Task {
                                                    viewModel.deleteCredential(
                                                        credential: credential)
                                                }
                                            }
                                        )
                                    ) {
                                        CredentialRow(credential: credential)
                                            .aspectRatio(1.6, contentMode: .fit)
                                            .frame(maxWidth: .infinity)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 16)
                    }
                    // FloatingActionButtonを追加
                    .overlay(
                        FloatingActionButton(
                            onButtonTap: {
                                showQRReader = true  // QRリーダーを直接起動
                            }
                        ),
                        alignment: .bottomTrailing
                    )
                }
            }
            .navigationBarTitle("Credential List", displayMode: .inline)
            .navigationBarBackButtonHidden(true)
            .fullScreenCover(isPresented: $showQRReader, onDismiss: didDismissQRReader) {
                QRReaderView(nextScreen: $nextScreen)
                    .environment(sharedArgs)
            }
            .fullScreenCover(isPresented: $showCredentialOffer, onDismiss: didDismissCredentialOffer) {
                if let args = sharedArgs.credentialOfferArgs {
                    CredentialOfferView().environment(args)
                }
            }
            .navigationDestination(for: ScreensOnFullScreen.self) { screen in
                switch screen {
                    case .issuerDetail(let credential):
                        IssuerDetail(credential: credential)
                    default:
                        EmptyView()
                }
            }
        }
        .onAppear {
            print("onAppear@CredentialList")
            Task {
                viewModel.loadData()
            }
        }
    }

    func didDismissQRReader() {
        // QRスキャン後、次の画面を開く
        switch nextScreen {
        case .credentialOffer:
            showCredentialOffer = true
            nextScreen = .root
        default:
            break
        }
    }

    func didDismissCredentialOffer() {
        // クレデンシャル発行後、一覧を更新
        viewModel.reloadData()
    }
}

#Preview("Empty") {
    CredentialList()
}

#Preview("Not Empty") {
    CredentialList(viewModel: PreviewModel())
}
