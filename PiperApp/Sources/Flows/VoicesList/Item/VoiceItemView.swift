// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI
import PiperAppUtils

struct VoiceItemView: View {

    @StateObject var hostModel: VoiceItemHostModel
    /// Search results are a flat list without language sections, so
    /// their rows name the voice's language explicitly.
    var showsLanguage: Bool = false
    var voice: Voice {
        hostModel.viewModel.voice
    }

    @ViewBuilder
    private func imageView(systemName: String) -> some View {
        let buttonSize = 50.0
        Image(systemName: systemName)
            .imageScale(.large)
            .frame(width: buttonSize, height: buttonSize)
            .foregroundColor(.accentColor)
            .accessibilityAddTraits(.isButton)
    }

    @ViewBuilder
    private func playDemo() -> some View {

        if hostModel.viewModel.isPlaying {
            Button {
                hostModel.stopPlaying()
            } label: {
                imageView(systemName: "stop")
                    .accessibilityLabel("stop_playing")
                    .accessibilityHint("stop_playing_hint")
            }
            .buttonStyle(.borderless)
        } else if hostModel.viewModel.isSampleLoading {
            let size = 50.0
            ProgressView()
                .progressViewStyle(.circular)
                .frame(width: size, height: size)
                .accessibilityLabel("loading_sample")
        } else {
            Button {
                hostModel.playSample(voice: hostModel.viewModel.voice)
            } label: {
                imageView(systemName: "play")
                    .accessibilityLabel("play_sample")
                    .accessibilityHint("play_sample_hint")
            }
            .buttonStyle(.borderless)
        }
    }

    @State var unstallConfirmationShown: Bool = false
    @ViewBuilder
    private func download() -> some View {
        let size = 50.0
        HStack {
            if hostModel.isInstalled(voice) {
                Button {
                    unstallConfirmationShown.toggle()
                } label: {
                    imageView(systemName: "trash")
                        .accessibilityLabel("uninstall_voice")
                        .accessibilityHint("uninstall_voice_hint")
                }
                .buttonStyle(.borderless)
                .alert("uninstall_voice", isPresented: $unstallConfirmationShown) {
                    Button("uninstall_button", role: .destructive) {
                        hostModel.remove(voice: voice)
                    }
                    Button("cancel", role: .cancel) {
                        unstallConfirmationShown.toggle()
                    }
                }
            } else if hostModel.viewModel.isDownloading {
                Button {
                    hostModel.cancelDownload(voice: voice)
                } label: {
                    ZStack {
                        CircularProgressView(progress: hostModel.viewModel.downloadProgress)
                            .frame(width: size, height: size)
                        Image(systemName: "stop.fill")
                            .imageScale(.small)
                            .foregroundColor(.accentColor)
                    }
                    .frame(width: size, height: size)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("cancel_download")
                .accessibilityValue("\(Int(hostModel.viewModel.downloadProgress * 100))%")
            } else {
                Button {
                    hostModel.download(voice: voice)
                } label: {
                    imageView(systemName: "square.and.arrow.down")
                        .accessibilityLabel("download_voice")
                        .accessibilityHint("download_voice_hint")
                }
                .buttonStyle(.borderless)
            }
        }

    }

    var body: some View {
        let voiceTitle = voice.name.capitalized + " " + voice.quality + " "
        let languageName = voice.language.code.localizedLanguageFromCode
        HStack {
            Spacer()
                .frame(width: 10)
            VStack {
                HStack {
                    Text(voiceTitle)
                        .font(.title)
                    Spacer()
                }
                HStack {
                    if showsLanguage {
                        Text(languageName + " · " + voice.voiceSizeString)
                            .font(.body)
                    } else {
                        Text(voice.voiceSizeString)
                            .font(.body)
                    }
                    Spacer()
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(showsLanguage ? voiceTitle + languageName : voiceTitle)
            .accessibilityHint("voice_item_hint")
            Spacer()
            playDemo()
            download()
        }
        .accessibilityElement(children: .contain)
    }
}
