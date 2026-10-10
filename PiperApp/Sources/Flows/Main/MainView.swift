// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI
import PiperAppUtils

struct MainView: View {

    @StateObject var hostModel: MainHostModel
    @State private var searchText = ""

    @ViewBuilder
    func toolBarButtonView(imageName: String,
                           accessibilityLabel: String,
                           @ViewBuilder destination: () -> some View) -> some View {
        NavigationLink(destination: {
            destination()
        }, label: {
            Image(systemName: imageName)
        })
        .accessibilityLabel(Text(accessibilityLabel))
        .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    func aboutButtonView() -> some View {
        toolBarButtonView(imageName: "info.circle",
                          accessibilityLabel: String(localized: "about_app"),
                          destination: {
            AboutAppView(hostModel: AboutAppHostModel(piper: self.hostModel.piper))
        })
    }

    @ViewBuilder
    func helpButtonView() -> some View {
        toolBarButtonView(imageName: "questionmark.circle",
                          accessibilityLabel: String(localized: "app_help_title"),
                          destination: {
            HelpView()
        })
    }

    @ViewBuilder
    func importButtonView() -> some View {
        toolBarButtonView(imageName: "square.and.arrow.down.on.square",
                          accessibilityLabel: String(localized: "update_model_in_app"),
                          destination: {
            ImportVoiceHostModelView(hostModel: ImportVoiceHostModel(piper: hostModel.piper, delegate: hostModel))
        })
    }

    @ViewBuilder
    func helpItem(text: String,
                  icon: String) -> some View {
        HStack(alignment: .top) {
            let attributedText = (try? AttributedString(markdown: text)) ?? AttributedString(text)
            Image(systemName: icon)
                .accessibilityHidden(true)
            Text(attributedText)
                .font(.title2)
        }
    }

    @ViewBuilder
    private func voiceRow(_ voice: Voice, showsLanguage: Bool = false) -> some View {
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

    @ViewBuilder
    private var installedContent: some View {
        if !hostModel.viewModel.installedModels.isEmpty {
            Section("installed_languages") {
                ForEach(hostModel.viewModel.installedByLanguage, id: \.code) { group in
                    NavigationLink {
                        InstalledVoicesView(hostModel: hostModel, languageCode: group.code)
                    } label: {
                        HStack {
                            Text(group.code.localizedLanguageFromCode)
                                .font(.title2)
                            Spacer()
                            Text(String.localized("installed_count_format", arguments: [group.models.count]))
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                ForEach(hostModel.viewModel.ungroupedInstalled, id: \.info?.voiceId) { model in
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
        } else {
            helpItem(text: String(localized: "no_voices_message"),
                     icon: "square.and.arrow.down")
        }
    }

    @ViewBuilder
    private var catalogContent: some View {
        switch hostModel.viewModel.catalogState {
        case .loading:
            Section {
                HStack {
                    ProgressView()
                    Text("loading_voices")
                        .font(.title2)
                }
            }
        case .failed:
            Section {
                Text("catalog_load_failed")
                    .font(.title2)
                Button("retry") {
                    hostModel.loadVoices()
                }
            }
        case .loaded:
            Section {
                Text("warning_not_tested_voices")
                    .font(.title2)
                    .accessibilityHidden(false)
            }
            ForEach(hostModel.viewModel.languageCodes, id: \.self) { code in
                Section(code.localizedLanguageFromCode) {
                    ForEach(hostModel.voices(for: code), id: \.key) { voice in
                        voiceRow(voice)
                    }
                }
            }
            Section {
                Text("warning_big_voice_files")
                    .font(.title2)
                    .accessibilityHidden(false)
            }
        }
    }

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    @ViewBuilder
    private var searchContent: some View {
        let results = hostModel.searchResults(for: searchText)
        if results.isEmpty {
            Section {
                Text("no_voices")
                    .font(.title2)
            }
        } else {
            Section {
                ForEach(results, id: \.key) { voice in
                    voiceRow(voice, showsLanguage: true)
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if isSearching {
                    searchContent
                } else {
                    installedContent
                    catalogContent
                }
            }
            .navigationTitle("piper_app_name")
            .searchable(text: $searchText, prompt: Text("search_voices"))
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    importButtonView()
                }
                ToolbarItem(placement: .primaryAction) {
                    helpButtonView()
                }
                ToolbarItem(placement: .primaryAction) {
                    aboutButtonView()
                }
            }
        }
    }
}
