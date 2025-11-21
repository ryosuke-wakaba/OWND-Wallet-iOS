//
//  ProvideAge.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2024/01/12.
//

import SwiftUI

struct ProvideAge: View {
    var clientInfo: ClientInfo
    var dcqlQuery: DcqlQuery

    var body: some View {
        let credentialQuery = dcqlQuery.credentials.first
        if let id = credentialQuery?.id {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text(id).modifier(BodyBlack())
                    // DCQL doesn't have purpose field like PEX, show default message
                    Text(
                        String(
                            format: NSLocalizedString("age_share_description", comment: ""),
                            self.clientInfo.name)
                    ).modifier(SubHeadLineGray())
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)  // 左寄せ
            }
        }
        else {
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("").modifier(BodyBlack())
                    Text(
                        String(
                            format: NSLocalizedString("age_share_description", comment: ""),
                            self.clientInfo.name)
                    )
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)  // 左寄せ
            }
        }
    }
}

#Preview {
    let modelData = ModelData()
    modelData.loadClientInfoList()
    modelData.loadDcqlQueries()
    return ProvideAge(
        clientInfo: modelData.clientInfoList[0],
        dcqlQuery: modelData.dcqlQueries[0])
}
