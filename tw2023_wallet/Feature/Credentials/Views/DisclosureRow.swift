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
                    if submitDisclosure.isUserSelectable {
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
    DisclosureRow(
        submitDisclosure:
            .constant(
                DisclosureWithOptionality(
                    disclosure: Disclosure(
                        disclosure: nil,
                        key: "name",
                        value: "Yamada Taro"
                    ),
                    isSubmit: true,
                    isUserSelectable: false
                )))
}

#Preview("2. optional off") {
    DisclosureRow(
        submitDisclosure:
            .constant(
                DisclosureWithOptionality(
                    disclosure: Disclosure(
                        disclosure: nil,
                        key: "birth_of_date",
                        value: "2000-10-20"
                    ),
                    isSubmit: false,
                    isUserSelectable: true
                ))
    )
}

#Preview("2. optional on") {
    DisclosureRow(
        submitDisclosure:
            .constant(
                DisclosureWithOptionality(
                    disclosure: Disclosure(
                        disclosure: nil,
                        key: "is_older_than_18",
                        value: "True"
                    ),
                    isSubmit: true,
                    isUserSelectable: true
                ))
    )
}
