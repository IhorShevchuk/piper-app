// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI

struct HelpView: View {
    @ViewBuilder
    func helpItem(text: String,
                  icon: String) -> some View {
        HStack(alignment: .top) {
            let attributedText = (try? AttributedString(markdown: text)) ?? AttributedString(text)
            Image(systemName: icon)
                .accessibilityHidden(true)
            Text(attributedText)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    helpItem(text: String(localized: "app_help_line_1"),
                             icon: "square.and.arrow.down")
#if os(iOS)
                    helpItem(text: String(localized: "app_help_line_2_ios"),
                             icon: "gearshape")
                    helpItem(text: String(localized: "app_help_line_3_ios"),
                             icon: "globe")
#elseif os(macOS)
                    helpItem(text: String(localized: "app_help_line_2_macos"),
                             icon: "gearshape")
                    helpItem(text: String(localized: "app_help_line_3_macos"),
                             icon: "globe")
#else
#error("Unsupported platform")
#endif
                    helpItem(text: String(localized: "app_help_line_4"),
                             icon: "magnifyingglass")
                    Divider()
                    helpItem(text: String(localized: "app_help_line_5"),
                             icon: "square.and.arrow.down")
                }
                .padding()
                .font(.title2)
                .imageScale(.large)
                .navigationTitle("app_help_title")
            }
        }
    }
}
