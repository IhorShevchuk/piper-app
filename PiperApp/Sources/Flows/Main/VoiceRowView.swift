// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI
import PiperAppUtils

/// One catalog voice row of the unified voice list. An installed
/// voice's row navigates to its detail screen; any other row is
/// the plain item (play/download controls only).
struct VoiceRowView: View {

    @ObservedObject var hostModel: MainHostModel
    let voice: Voice
    var showsLanguage = false

    var body: some View {
        let item = VoiceItemView(hostModel: VoiceItemHostModel(piper: hostModel.piper,
                                                               loader: hostModel.loader,
                                                               voice: voice,
                                                               delegate: hostModel),
                                 showsLanguage: showsLanguage)
        if let paths = hostModel.installedPaths(for: voice) {
            NavigationLink {
                VoiceView(hostModel: VoiceHostModel(piper: hostModel.piper,
                                                    modelPaths: paths,
                                                    delegate: hostModel))
            } label: {
                item
            }
            .buttonStyle(.plain)
        } else {
            item
        }
    }
}
