// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import Combine
import PiperAppUtils

class VoiceHostModel: @unchecked Sendable, ObservableObject {
    @Published var viewModel: VoiceViewModel
    private var playingCancellable: AnyCancellable?
    let piper: PiperManager
    weak var delegate: ModelChangeDelegate?

    init(piper: PiperManager,
         modelPaths: FileManager.ModelPaths,
         delegate: ModelChangeDelegate?) {
        self.piper = piper
        viewModel = VoiceViewModel(paths: modelPaths,
                                   modelInfo: modelPaths.info)
        self.delegate = delegate
        updateSample()
        playingCancellable = piper.$isPlaying.sink { [weak self] isPlaying in
            guard let self = self else {
                return
            }
            self.viewModel.isPlaying = isPlaying
        }
    }

    deinit {
        let piper = self.piper
        Task {
            await piper.stopPlaying()
        }
    }

    func updateSample() {
        guard let language = viewModel.paths.info?.language,
              let sample = DemoText.text(for: language) else {
            return
        }
        viewModel.demoText = sample
    }

    func uninstall() {
        Task {
            await piper.stopPlaying()
        }
        piper.unstall(paths: viewModel.paths)
        delegate?.modelDidChange()
    }

    func play() {
        guard let modelInfo = viewModel.modelInfo else {
            return
        }
        let demoText = viewModel.demoText
        let piper = self.piper
        let isPlaying = self.viewModel.isPlaying
        let speakerId = self.viewModel.selectedSpeaker
        Task {
            if isPlaying {
                await piper.stopPlaying()
            } else {
                await piper.playSample(demoText: demoText,
                                            speakerId: speakerId,
                                            modelInfo: modelInfo)
            }
        }
    }
}

extension VoiceHostModel: VoiceFileSyntehesizer {

    enum Error: Swift.Error {
        case modelIsNotAvailable
    }

    var fileName: String {
        guard let modelInfo = viewModel.modelInfo else {
           return UUID().uuidString
        }
        return "\(modelInfo.name)_\(Int.random(in: 0...10000))"
    }

    func syntehesize(text: String, to file: String) async throws {
        guard let modelInfo = viewModel.modelInfo else {
            throw Error.modelIsNotAvailable
        }

        try await self.piper.synthesizeToFile(text: viewModel.demoText,
                                              to: file,
                                              speakerId: self.viewModel.selectedSpeaker,
                                              modelInfo: modelInfo)
    }
}
