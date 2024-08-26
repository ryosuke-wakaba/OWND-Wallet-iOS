//
//  DisclosureLow.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2023/12/26.
//

import SwiftUI

struct DisclosureRow: View {
    @Binding var submitDisclosure: DisclosureWithOptionality  //(key: String, value: String)

    var body: some View {
        if let key = submitDisclosure.disclosure.key,
            let value = submitDisclosure.disclosure.value
        {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey(key))
                            .padding(.bottom, 2)
                            .modifier(SubHeadLineGray())

                        Text(value)
                            .padding(.bottom, 2)
                            .modifier(BodyBlack())
                    }
                    if submitDisclosure.optional {
                        Spacer()
                        Toggle("", isOn: $submitDisclosure.isSubmit).labelsHidden()
                    }
                }
            }
            .padding(.vertical, 6)  // 上下のpaddingに対応
            .frame(maxWidth: .infinity, alignment: .leading)
        }

    }
}

#Preview("1 required") {
    let modelData = ModelData()
    modelData.loadCredentials()
    let disclosure = modelData.credentials.first?.disclosure?.first
    return DisclosureRow(
        submitDisclosure:
            .constant(
                DisclosureWithOptionality(
                    disclosure: Disclosure(
                        disclosure: nil,
                        key: disclosure?.key,
                        value: disclosure?.value
                    ),
                    isSubmit: true,
                    optional: false
                )))
}

#Preview("2. optional off") {
    let modelData = ModelData()
    modelData.loadCredentials()
    let disclosure = modelData.credentials.first?.disclosure?.first
    return DisclosureRow(
        submitDisclosure:
            .constant(
                DisclosureWithOptionality(
                    disclosure: Disclosure(
                        disclosure: nil, key: disclosure?.key, value: disclosure?.value),
                    isSubmit: false,
                    optional: true
                ))
    )
}

#Preview("2. optional on") {
    let modelData = ModelData()
    modelData.loadCredentials()
    let disclosure = modelData.credentials.first?.disclosure?.first
    return DisclosureRow(
        submitDisclosure:
            .constant(
                DisclosureWithOptionality(
                    disclosure: Disclosure(
                        disclosure: nil, key: disclosure?.key, value: disclosure?.value),
                    isSubmit: true,
                    optional: true
                ))
    )
}
