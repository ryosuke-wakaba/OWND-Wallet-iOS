//
//  WalkThrough4.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2024/01/07.
//

import SwiftUI

struct WalkThrough4: View {
    @Environment(\.presentationMode) var presentationMode
    @AppStorage("isNotFirstLaunch") private var isNotFirstLaunch = false
    @State private var navigateToRestore = false
    @State private var showPrivacyPolicy = false
    @State private var showTermsOfUse = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Image("step4")
                        .frame(width: geometry.size.width * 0.6)
                        // 画面上下左右中央
                        .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    Image("walkthrough4")
                        .imageScale(.large)
                        .foregroundStyle(.tint)
                        .frame(width: geometry.size.width * 0.6)
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.45)
                    VStack {
                        HStack {
                            Button(action: {
                                self.showPrivacyPolicy = true
                            }) {
                                Text("privacy_policy")
                                    .modifier(BodyBlack())
                                    .underline()
                                    .sheet(
                                        isPresented: $showPrivacyPolicy,
                                        content: {
                                            SafariView(
                                                url: URL(
                                                    string:
                                                        "https://www.ownd-project.com/wallet/privacy/index.html"
                                                )!)
                                        })
                            }

                            Button(action: {
                                self.showTermsOfUse = true
                            }) {
                                Text("terms_of_use")
                                    .modifier(BodyBlack())
                                    .underline()
                                    .sheet(
                                        isPresented: $showTermsOfUse,
                                        content: {
                                            SafariView(
                                                url: URL(
                                                    string:
                                                        "https://www.ownd-project.com/wallet/tos/index.html"
                                                )!)
                                        })
                            }
                        }
                        .modifier(BodyBlack())
                        .underline()
                        .padding(.vertical, 8)

                        Text("walkthrough_4_3")
                            .modifier(SubHeadLineBlack())
                    }
                    .position(x: geometry.size.width / 2, y: geometry.size.height * 0.68)
                }
                VStack {
                    VStack(spacing: 16) {
                        Text("walkthrough_4_1")
                            .modifier(TitleBlack())
                        Text("walkthrough_4_2")
                            .modifier(TitleBlack())
                    }
                    .padding(.top, 24)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    Spacer()  // 下部の余白
                    HStack {
                        Button(action: {
                            self.presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.backward")
                                .modifier(Title3Gray())
                        }
                        Spacer()
                    }
                    ActionButtonBlack(
                        title: "begin_anew",
                        action: {
                            isNotFirstLaunch = true  // ContentViewが自動的に再評価されHome()を表示
                        }
                    )
                    .padding(.vertical, 16)
                    Button(action: {
                        self.navigateToRestore = true
                    }) {
                        Text("start_from_backup")
                            .modifier(BodyBlack())
                            .underline()
                    }
                    .navigationDestination(isPresented: $navigateToRestore) {
                        Restore()
                    }
                    .padding(.bottom, 24)
                }
            }
            .padding(.horizontal, 32)
        }
        .navigationBarBackButtonHidden(true)
    }
}

#Preview("Default") {
    WalkThrough4()
}

#Preview("iPhone SE") {
    WalkThrough4()
        .previewDevice(PreviewDevice(rawValue: "iPhone SE (3rd generation)"))
}
