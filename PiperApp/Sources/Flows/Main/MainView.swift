// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI
import PiperAppUtils

struct MainView: View {
    
    @StateObject var hostModel: MainHostModel

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
    func downloadVoice() -> some View {
        NavigationLink {
            VoicesListView(hostModel: VoicesListHostModel(piper: hostModel.piper, delegate: hostModel))
        } label: {
            Text("download_voice_model")
                .font(.title2)
                .accessibilityIdentifier("download_voice_model")
        }
    }
    
    func selectFromFiles() -> some View {
        NavigationLink {
            ImportVoiceHostModelView(hostModel: ImportVoiceHostModel(piper: hostModel.piper, delegate: hostModel))
        } label: {
            Text("update_model_in_app")
                .font(.title2)
                .accessibilityIdentifier("update_model_in_app")
        }
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
    
    var body: some View {
        NavigationStack {
            List {
                if !hostModel.viewModel.installedModels.isEmpty {
                    Section("installed_voices") {
                        ForEach(hostModel.viewModel.installedModels, id: \.info?.voiceId) { model in
                            NavigationLink {
                                VoiceView(hostModel: VoiceHostModel(piper: hostModel.piper, modelPaths: model, delegate: hostModel))
                            } label: {
                                Text(model.modelTitle)
                                    .font(.title2)
                            }
                        }
                    }
                } else {
                    if hostModel.viewModel.installedModels.isEmpty {
                        helpItem(text: String(localized: "no_voices_message"),
                                 icon: "square.and.arrow.down")
                    }
                }
                Section {
                    downloadVoice()
                    selectFromFiles()
                }
            }
            .navigationTitle("piper_app_name")
            .toolbar {
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
