// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI
import PiperAppUtils

struct VoicesListView: View {

    @StateObject var hostModel: VoicesListHostModel

    @ViewBuilder
    func voicesList(for language: String, title: String) -> some View {
        NavigationStack {
            if let voices = hostModel.languages[language]?.sorted(by: { voice1, voice2 in
                voice1.name < voice2.name
            }).filter({ voice in
                return voice.isSupported
            }),
               !voices.isEmpty {
                List {
                    Text("warning_not_tested_voices")
                        .font(.title2)
                    Section {
                        ForEach(voices, id: \.key) { voice in
                            VoiceItemView(hostModel: VoiceItemHostModel(piper: hostModel.piper,
                                                                        loader: hostModel.loader,
                                                                        voice: voice,
                                                                        delegate: hostModel.delegate))
                        }
                    }
                    Text("warning_big_voice_files")
                        .font(.title2)
                }
                .accessibilityIdentifier("download_languages_list")
            } else {
                Text("no_voices")
            }
        }
        .navigationTitle(title)
    }

    var body: some View {
        NavigationStack {
            if hostModel.viewModel.showLoadingIndicator {
                ProgressView()
            } else {
                List {
                    Section {
                        ForEach(hostModel.viewModel.languages, id: \.self) { language in
                            let title = Locale.current.localizedString(forIdentifier: language) ?? language
                            NavigationLink {
                                voicesList(for: language, title: title)
                            } label: {
                                Text(title)
                                    .font(.title2)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("languages".localized)
    }
}
