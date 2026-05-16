// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI
import PiperAppUtils

struct VoiceView: View {
    
    @StateObject var hostModel: VoiceHostModel
    @Environment(\.dismiss) private var popView
    
    @ViewBuilder
    private func buttonImageView(systemName: String) -> some View {
        Image(systemName: systemName)
            .imageScale(.large)
            .foregroundColor(.accentColor)
    }
    
    @ViewBuilder
    func playSampleView() -> some View {
        Section {
            HStack {
                Button {
                    hostModel.play()
                } label: {
                    CenteredContent {
                        if hostModel.viewModel.isPlaying {
                            buttonImageView(systemName: "stop")
                            Text("stop")
                        } else {
                            buttonImageView(systemName: "play")
                            Text("play_sample")
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
                .buttonStyle(.bordered)
                
                ShareLink("export_file".localized, item: VoiceFileTransferable(text: hostModel.viewModel.demoText, syntehesizer: hostModel),
                          preview: SharePreview(hostModel.fileName + ".wav",
                                                icon: Image("waveform")
                                               ))
                .tint(.accentColor)
                .buttonStyle(.bordered)
            }

            .alignmentGuide(.listRowSeparatorLeading) { _ in
                return 0
            }
            if let modelInfo = hostModel.viewModel.modelInfo {
                if !modelInfo.speakers.isEmpty {
                    Picker("speaker".localized, selection: $hostModel.viewModel.selectedSpeaker) {
                        ForEach(modelInfo.speakers.keys.sorted(), id: \.self) { speakerKey in
                            Text(speakerKey.capitalized)
                                .tag(modelInfo.speakers[speakerKey]!)
                        }
                    }
                }
            }
            
            TextField("sample_text".localized, text: $hostModel.viewModel.demoText, axis: .vertical)
                .lineLimit(1...10)
                .accessibilityLabel("sample_text: \(hostModel.viewModel.demoText)")
        }
    }
    
    @State var unstallConfirmationShown: Bool = false
    @ViewBuilder
    func uninstall() -> some View {
        Button {
            unstallConfirmationShown.toggle()
        } label: {
            CenteredContent {
                Text("uninstall_voice")
                    .foregroundStyle(.red)
            }
        }
        .alert("uninstall_voice", isPresented: $unstallConfirmationShown) {
            Button("uninstall_button", role: .destructive) {
                hostModel.uninstall()
                popView()
            }
            Button("cancel", role: .cancel) {
                unstallConfirmationShown.toggle()
            }
        }
    }
    
    var body: some View {
        List {
            if let modelInfo = hostModel.viewModel.modelInfo {
                ModelInfoView(info: modelInfo, detailed: true)
            }
            
            playSampleView()
            
            Section {
                uninstall()
            }
        }
        .navigationTitle(hostModel.viewModel.paths.info?.name.capitalized ?? "voice")
    }
}
