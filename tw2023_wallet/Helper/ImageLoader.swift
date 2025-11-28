//
//  ImageLoader.swift
//  tw2023_wallet
//
//  Created by SadamuMatsuoka on 2023/12/30.
//

import SDWebImageSwiftUI
import SwiftUI

enum ImageLoader {
    static func loadImage(from urlString: String?) -> AnyView? {
        if let urlString = urlString, let url = URL(string: urlString) {
            return AnyView(
                WebImage(url: url) { image in
                    image.resizable()
                } placeholder: {
                    EmptyView()
                }
            )
        }
        else {
            return nil
        }
    }
}
