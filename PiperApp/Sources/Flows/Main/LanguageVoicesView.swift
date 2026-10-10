// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI
import PiperAppUtils

/// The voices of one language, pushed both from the "Languages"
/// list and from the "Installed languages" section of the main
/// screen - the same list either way.
struct LanguageVoicesView: View {

    @ObservedObject var hostModel: MainHostModel
    let languageCode: String

    var body: some View {
        List {
            ForEach(hostModel.voices(for: languageCode), id: \.key) { voice in
                VoiceRowView(hostModel: hostModel, voice: voice)
            }
        }
        .navigationTitle(languageCode.localizedLanguageFromCode)
    }
}
