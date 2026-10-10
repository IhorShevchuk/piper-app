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

    /// Sighted users see just the number on an installed-language row;
    /// VoiceOver keeps the full localized "Installed voices: N".
    private func installedAccessibilityLabel(for group: MainViewModel.InstalledLanguage) -> String {
        let count = String.localized("installed_count_format", arguments: [group.models.count])
        return "\(group.code.localizedLanguageFromCode), \(count)"
    }

    @ViewBuilder
    private var installedContent: some View {
        if !hostModel.viewModel.installedModels.isEmpty {
            Section("installed_languages") {
                ForEach(hostModel.viewModel.installedByLanguage, id: \.code) { group in
                    NavigationLink {
                        LanguageVoicesView(hostModel: hostModel,
                                           languageCode: hostModel.resolvedLanguageCode(for: group.code))
                    } label: {
                        HStack {
                            Text(group.code.localizedLanguageFromCode)
                                .font(.title2)
                            Spacer()
                            Text("\(group.models.count)")
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text(installedAccessibilityLabel(for: group)))
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
            Section("languages") {
                ForEach(hostModel.viewModel.languageCodes, id: \.self) { code in
                    NavigationLink {
                        LanguageVoicesView(hostModel: hostModel, languageCode: code)
                    } label: {
                        Text(code.localizedLanguageFromCode)
                            .font(.title2)
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
                    VoiceRowView(hostModel: hostModel, voice: voice, showsLanguage: true)
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
