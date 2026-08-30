// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI

struct AboutLibView: View {
    let libTitle: String
    let url: String
    let description: String

    var body: some View {
        VStack {
            Link(destination: URL(string: url)!) {
                VStack {
                    Text(libTitle)
                        .bold()
                    PiperAsset.Assets.github.swiftUIImage
                        .resizable()
                        .tint(Color.white)
                        .frame(width: 40, height: 40)
                }
            }
            .buttonStyle(BorderlessButtonStyle())
            .padding(.bottom)
            let attributedString = (try? AttributedString(markdown: description)) ?? AttributedString(description)
            Text(attributedString)
                .multilineTextAlignment(.center)
                .font(.subheadline)
        }
    }
}
