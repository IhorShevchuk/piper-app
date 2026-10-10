// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI
import PiperAppUtils

/// The installed voices of one language, pushed from the
/// "Installed languages" section of the unified voice list.
struct InstalledVoicesView: View {

    @ObservedObject var hostModel: MainHostModel
    let languageCode: String

    private var models: [FileManager.ModelPaths] {
        hostModel.viewModel.installedByLanguage
            .first { group in
                return group.code == languageCode
            }?.models ?? []
    }

    var body: some View {
        List {
            ForEach(models, id: \.info?.voiceId) { model in
                NavigationLink {
                    VoiceView(hostModel: VoiceHostModel(piper: hostModel.piper,
                                                        modelPaths: model,
                                                        delegate: hostModel))
                } label: {
                    Text(model.modelTitle)
                        .font(.title2)
                }
            }
        }
        .navigationTitle(languageCode.localizedLanguageFromCode)
    }
}
