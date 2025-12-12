//
//  ContentView.swift
//  tw2023_wallet
//
//  Created by 若葉良介 on 2023/12/21.
//

import SwiftUI

struct ContentView: View {
    @AppStorage("isNotFirstLaunch") private var isNotFirstLaunch = false

    var body: some View {
        if isNotFirstLaunch {
            Home()
        }
        else {
            WalkThrough1()
        }
    }
}

#Preview {
    ContentView()
}
