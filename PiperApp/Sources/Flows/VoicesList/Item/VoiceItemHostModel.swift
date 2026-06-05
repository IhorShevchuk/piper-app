// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import Combine
import PiperAppUtils
import AVFoundation

class VoiceItemHostModel: @unchecked Sendable, ObservableObject {
    @Published var viewModel: VoiceItemViewModel
    let piper: PiperManager
    let loader: VoiceLoader
    var languages: [String: [Voice]] = [:]
    weak var delegate: ModelChangeDelegate?
    private var avPlayerRateObserver: NSKeyValueObservation!
    private var avItemStateObserver: NSKeyValueObservation!

    private var audioPlayer: AVPlayer?
    init(piper: PiperManager,
         loader: VoiceLoader,
         voice: Voice,
         delegate: ModelChangeDelegate?) {
        viewModel = VoiceItemViewModel(voice: voice)
        self.piper = piper
        self.loader = loader
        self.delegate = delegate
        activatePlaybackMode()
    }

    deinit {
        stopPlaying()
    }

    func download(voice: Voice) {
        Task { [weak self] in
            guard let self else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.viewModel.isDownloading = true
            }
            do {
                for try await event in loader.download(voice: voice) {

                    switch event {

                    case .progress(let value):
                        await MainActor.run { [weak self] in
                            guard let self else { return }
                            self.viewModel.downloadProgress = value
                        }

                    case .finished(let modelPath):
                        await self.piper.install(paths: modelPath)
                        try? FileManager.default.removeItem(at: modelPath.json)
                        try? FileManager.default.removeItem(at: modelPath.model)
                        self.delegate?.modelDidChange()
                    }
                }
            } catch {
                Log.error("Failed to download voices: \(error)")
            }

            await MainActor.run {
                self.viewModel.downloadProgress = 0.0
                self.viewModel.isDownloading = false
            }
        }
    }

    func remove(voice: Voice) {
        guard let installed = installed(voice) else {
            return
        }
        piper.unstall(paths: installed)
        delegate?.modelDidChange()
    }

    func isInstalled(_ voice: Voice) -> Bool {
        return installed(voice) != nil
    }

    private func installed(_ voice: Voice) -> FileManager.ModelPaths? {
        self.piper.installedVoices.first { modelPath in
            guard let modelInfo = modelPath.info else {
                return false
            }
            return modelInfo.dataset == voice.name && modelInfo.audio.quality == voice.quality
        }
    }

    func stopPlaying() {
        NotificationCenter.default.removeObserver(self, name: AVPlayerItem.didPlayToEndTimeNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name: AVPlayerItem.failedToPlayToEndTimeNotification, object: nil)
        audioPlayer?.pause()
        audioPlayer = nil
        avPlayerRateObserver = nil
        avItemStateObserver = nil
        viewModel.isPlaying = false
        viewModel.isSampleLoading = false
        setAudioSession(active: false)
    }

    func playSample(voice: Voice) {
        guard let sampleURL = loader.sampleURL(for: voice) else {
            return
        }

        setAudioSession(active: true)
        viewModel.isSampleLoading = true

        let item = AVPlayerItem(url: sampleURL)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerItemDidPlayToEndTime(notification:)),
                                               name: AVPlayerItem.didPlayToEndTimeNotification,
                                               object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(self.playerItemDidPlayToEndTime(notification:)),
                                               name: AVPlayerItem.failedToPlayToEndTimeNotification,
                                               object: nil)
        audioPlayer = AVPlayer(playerItem: item)
        self.avPlayerRateObserver = audioPlayer?.observe(\.rate, options: [.new]) { [weak self] player, _ in
            self?.viewModel.isPlaying = player.rate == 1.0
        }

        self.avItemStateObserver = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            self?.viewModel.isSampleLoading = item.status != .readyToPlay && item.status != .failed
            if item.status == .failed {
                self?.stopPlaying()
            }
        }
        audioPlayer?.volume = 1.0
        audioPlayer?.play()
    }

    @objc func playerItemDidPlayToEndTime(notification: NSNotification) {
        stopPlaying()
    }

    func activatePlaybackMode() {
#if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        } catch let error {
            Log.error("Error happened during activating playback. Error:\(error)")
        }
#endif
    }

    func setAudioSession(active: Bool) {
#if !os(macOS)
        do {
            try AVAudioSession.sharedInstance().setActive(active)
        } catch let error {
            Log.error("Error happened during setting audio session active status:\(active)  Error:\(error)")
        }
#endif
    }
}
