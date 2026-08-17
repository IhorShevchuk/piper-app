// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI
import PiperAppUtils

struct VoiceItemView: View {

    @StateObject var hostModel: VoiceItemHostModel
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
    }

    @ViewBuilder
    private func playDemo() -> some View {

        if hostModel.viewModel.isPlaying {
            Button {
                hostModel.stopPlaying()
            } label: {
                imageView(systemName: "stop")
                    .accessibilityLabel("stop_playing")
            }
            .buttonStyle(PlainButtonStyle())
        } else if hostModel.viewModel.isSampleLoading {
            let size = 50.0
            ProgressView()
                .progressViewStyle(.circular)
                .frame(width: size, height: size)
        } else {
            Button {
                hostModel.playSample(voice: hostModel.viewModel.voice)
            } label: {
                imageView(systemName: "play")
                    .accessibilityLabel("play_sample")
            }
            .buttonStyle(PlainButtonStyle())
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
                }
                .buttonStyle(PlainButtonStyle())
                .alert("uninstall_voice", isPresented: $unstallConfirmationShown) {
                    Button("uninstall_button", role: .destructive) {
                        hostModel.remove(voice: voice)
                    }
                    Button("cancel", role: .cancel) {
                        unstallConfirmationShown.toggle()
                    }
                }
            } else if hostModel.viewModel.isDownloading {
                CircularProgressView(progress: hostModel.viewModel.downloadProgress)
                    .frame(width: size, height: size)
                    .accessibilityElement()
                    .accessibilityLabel("downloading")
                    .accessibilityValue(String(localized: "voice_loading_progress_\(hostModel.viewModel.downloadProgress * 100)"))
            } else {
                Button {
                    hostModel.download(voice: voice)
                } label: {
                    imageView(systemName: "square.and.arrow.down")
                        .accessibilityLabel("download_voice")
                }
                .buttonStyle(PlainButtonStyle())
            }
        }

    }

    var body: some View {
        let voiceTitle = voice.name.capitalized + " " + voice.quality + " "
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
                    Text(voice.voiceSizeString)
                        .font(.body)
                    Spacer()
                }
            }
            .accessibilityElement(children: .combine)
            Spacer()
            playDemo()
            download()
        }
    }
}
