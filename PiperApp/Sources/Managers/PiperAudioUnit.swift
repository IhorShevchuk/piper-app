// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import AVFAudio
import Combine
import PiperAppUtils

class PiperAudioUnit {
    enum Status {
        case connected
        case disconnected
        case failedToConnect
        
        var string: String {
            switch self {
            case .connected:
                return "audio_unit_status_connected".localized
            case .disconnected:
                return "audio_unit_status_disconnected".localized
            case .failedToConnect:
                return "audio_unit_status_failed".localized
            }
        }
    }
    
    @MainActor @Published private(set) var status: PiperAudioUnit.Status = .disconnected
    
    private func setStatus(_ status: PiperAudioUnit.Status) {
        DispatchQueue.main.async {
            self.status = status
        }
    }
    
    private var audioUnit: AVAudioUnit?
    private let engine = AVAudioEngine()
    private var messageChannel: AUMessageChannel?
    private var cancellables = Set<AnyCancellable>()
    private var healthCheckTimer: Timer?
    private let manager = AVAudioUnitComponentManager.shared()
    
    private func setUpEngineObservers() {
        NotificationCenter.default.publisher(for: .AVAudioEngineConfigurationChange, object: engine)
            .sink { [weak self] _ in
                self?.handleEngineConfigurationChange()
            }
            .store(in: &cancellables)
        #if !os(macOS)
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] note in
                self?.handleInterruption(note)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)
            .sink { [weak self] _ in
                self?.handleRouteChange()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: AVAudioSession.mediaServicesWereResetNotification)
            .sink { [weak self] _ in
                self?.handleMediaServicesReset()
            }
            .store(in: &cancellables)
        #endif
    }

    private func startHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self, let unit = self.audioUnit?.auAudioUnit else { return }
            if !self.engine.isRunning || !unit.renderResourcesAllocated {
                self.setStatus(.disconnected)
                Task { await self.reconnect() }
            }
        }
    }

    private func invalidateHealthCheckTimer() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
    }

    private func handleEngineConfigurationChange() {
        if !engine.isRunning || !(audioUnit?.auAudioUnit.renderResourcesAllocated ?? false) {
            Task { await reconnect() }
        }
    }
#if !os(macOS)
    private func handleInterruption(_ note: Notification) {
        guard let info = note.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }

        switch type {
        case .began:
            setStatus(.disconnected)
        case .ended:
            Task { await reconnect() }
        @unknown default:
            break
        }
    }
#endif

    private func handleRouteChange() {
        Task { await reconnect() }
    }

    private func handleMediaServicesReset() {
        Task { await reconnect() }
    }
    
    func loadAudioUnit(with description: AudioComponentDescription) async throws -> AVAudioUnit {
        let components = manager.components(matching: description)
        var internalError: Error = NSError(domain: NSOSStatusErrorDomain, code: Int(kAudioUnitErr_ExtensionNotFound), userInfo: [:])
        for component in components {
            do {
                return try await AVAudioUnit.instantiate(with: component.audioComponentDescription, options: [.loadOutOfProcess])
            } catch {
                internalError = error
            }
        }
        throw internalError
    }
    
    func connect() async {
        Log.debug("Connecting audio unit...")
        let componentDescription = AudioComponentDescription(componentType: kAudioUnitType_SpeechSynthesizer,
                                                             componentSubType: "pipr".audioComponentOSType,
                                                             componentManufacturer: "pipr".audioComponentOSType,
                                                             componentFlags: AudioComponentFlags([.sandboxSafe, .isV3AudioUnit]).rawValue,
                                                             componentFlagsMask: AudioComponentFlags([.sandboxSafe, .isV3AudioUnit]).rawValue
                                                             )
        do {
            guard let format = AVAudioFormat.defaultFormat else {
                setStatus(.failedToConnect)
                return
            }
            let audioUnit = try await loadAudioUnit(with: componentDescription)
            
            if engine.isRunning {
                engine.stop()
            }
            self.engine.attach(audioUnit)
            self.engine.connect(audioUnit, to: engine.outputNode, format: format)
            self.engine.prepare()
            self.engine.isAutoShutdownEnabled = true
            
            self.messageChannel = audioUnit.auAudioUnit.messageChannel(for: "\(Self.Type.self)")
            self.audioUnit = audioUnit

            let unit = audioUnit.auAudioUnit
            if !unit.renderResourcesAllocated {
                try? unit.allocateRenderResources()
            }
            do {
                try self.engine.start()
            } catch {
                Log.error("Failed to start audio engine: \(error)")
                await self.reconnect()
                return
            }

            if self.engine.isRunning && unit.renderResourcesAllocated {
                setStatus(.connected)
            } else {
                setStatus(.failedToConnect)
            }

            self.setUpEngineObservers()
            self.startHealthCheckTimer()
            Log.debug("Connected audio unit successfully.")
        } catch {
            Log.error("Failed to connect audio unit: \(error)")
            setStatus(.failedToConnect)
        }
    }
    
    func disconnect() async {
        Log.debug("Disconnecting audio unit...")
        invalidateHealthCheckTimer()
        cancellables.removeAll()
        if engine.isRunning {
            engine.stop()
        }
        self.audioUnit?.reset()
        self.audioUnit = nil
        setStatus(.disconnected)
        Log.debug("Disconnected audio unit successfully.")
    }
    
    func reconnect() async {
        await disconnect()
        try? await Task.sleep(for: .seconds(2.0))
        await connect()
    }
    
    func play(text: String,
              piperVoiceId: String) async {
        
        guard let audioUnit else {
            Log.error("Audio unit is nil. Can't play text.")
            return
        }
        
        let voice = AVSpeechSynthesisProviderVoice.supportedVoices.first(where: { voice in
            return voice.identifier.hasSuffix(piperVoiceId)
        }) ?? AVSpeechSynthesisProviderVoice.supportedVoices.first
        
        guard let voice else {
            Log.error("No supported voices. Can't play text.")
            return
        }
        
        let auAudioUnit = audioUnit.auAudioUnit
        if !auAudioUnit.renderResourcesAllocated {
            try? auAudioUnit.allocateRenderResources()
        }
        
        do {
            try self.engine.start()
        } catch {
            Log.error("Failed to start audio engine: \(error)")
            await reconnect()
        }
       
        let request = AVSpeechSynthesisProviderRequest(
          ssmlRepresentation: "<speak>\(text)</speak>",
          voice: voice
        )
        
        if auAudioUnit.responds(to: #selector(AVSpeechSynthesisProviderAudioUnit.synthesizeSpeechRequest(_:))) {
            auAudioUnit.perform(#selector(AVSpeechSynthesisProviderAudioUnit.synthesizeSpeechRequest(_:)), with: request)
        }
        await withCheckedContinuation { [weak self] continuation in
            guard let self else {
                return
            }
            Task { [weak self] in
                guard let self else {
                    return
                }
                while self.isSynthesizing {
                    try? await Task.sleep(for: .seconds(1.0))
                }
                continuation.resume()
            }
        }
    }
    
    func stop() {
        audioUnit?.engine?.stop()
        if let auAudioUnit = audioUnit?.auAudioUnit {
            if auAudioUnit.responds(to: #selector(AVSpeechSynthesisProviderAudioUnit.cancelSpeechRequest)) {
                auAudioUnit.perform(#selector(AVSpeechSynthesisProviderAudioUnit.cancelSpeechRequest), with: nil)
            }
        }
    }
    
    var isSynthesizing: Bool {
        guard let messageChannel else {
            return false
        }
        guard let responseObject = messageChannel.callAudioUnit?([MessageChannelKeys.kIsSyntehizerRunning: false]) else {
            return false
        }
        
        return responseObject[MessageChannelKeys.kIsSyntehizerRunning] as? Bool ?? false
    }
}
