// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import AVFoundation

import piper_objc
import PiperAppUtils
import Accelerate

public class PiperTTSAudioUnit: AVSpeechSynthesisProviderAudioUnit {
    private var outputBus: AUAudioUnitBus
    private var _outputBusses: AUAudioUnitBusArray!

    private var request: AVSpeechSynthesisProviderRequest?

    private var format: AVAudioFormat

    var piper: Piper?
    var model: ModelInfo?

    private var outputDataLock = os_unfair_lock_s()
    private var outputData: ContiguousArray<Float> = []
    private var outputRecurseCallNumber = 0

    private let outputRecurseCallNumberMax: UInt32 = 200
    private let baseDelayMicroseconds: UInt32 = 500
    private let maxBufferDurationSeconds: Double = 5.0
    private let maxSamplesCount: Int

    @objc override init(componentDescription: AudioComponentDescription, options: AudioComponentInstantiationOptions) throws {

        self.format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 22050.0, channels: 1, interleaved: true)!
        self.maxSamplesCount = Int(self.format.sampleRate * maxBufferDurationSeconds)

        outputBus = try AUAudioUnitBus(format: self.format)
        try super.init(componentDescription: componentDescription, options: options)
        _outputBusses = AUAudioUnitBusArray(audioUnit: self, busType: AUAudioUnitBusType.output, busses: [outputBus])
    }

    public override var outputBusses: AUAudioUnitBusArray {
        return _outputBusses
    }

    public override func allocateRenderResources() throws {
        try super.allocateRenderResources()
        Log.debug("allocateRenderResources")
    }

    public override func deallocateRenderResources() {
        super.deallocateRenderResources()
        piper = nil
        model = nil
    }

	// MARK: - Rendering
	/*
	 NOTE:- It is only safe to use Swift for audio rendering in this case, as Audio Unit Speech Extensions process offline.
	 (Swift is not usually recommended for processing on the realtime audio thread)
	 */
    public override var internalRenderBlock: AUInternalRenderBlock { self.performRender }

    // swiftlint:disable:next function_parameter_count
    private func performRender(
      actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
      timestamp: UnsafePointer<AudioTimeStamp>,
      frameCount: AUAudioFrameCount,
      outputBusNumber: Int,
      outputAudioBufferList: UnsafeMutablePointer<AudioBufferList>,
      renderEvents: UnsafePointer<AURenderEvent>?,
      renderPull: AURenderPullInputBlock?
    ) -> AUAudioUnitStatus {
        return doPerformRender(actionFlags: actionFlags, timestamp: timestamp, frameCount: frameCount, outputBusNumber: outputBusNumber, outputAudioBufferList: outputAudioBufferList, renderEvents: renderEvents, renderPull: renderPull)
    }

    // swiftlint:disable:next function_parameter_count function_body_length
    private func doPerformRender(
      actionFlags: UnsafeMutablePointer<AudioUnitRenderActionFlags>,
      timestamp: UnsafePointer<AudioTimeStamp>,
      frameCount: AUAudioFrameCount,
      outputBusNumber: Int,
      outputAudioBufferList: UnsafeMutablePointer<AudioBufferList>,
      renderEvents: UnsafePointer<AURenderEvent>?,
      renderPull: AURenderPullInputBlock?
    ) -> AUAudioUnitStatus {

        guard let piper = self.piper else {
            Log.error("Piper is nil while request for rendering came.")
            return kAudioComponentErr_InstanceInvalidated
        }

        if request == nil {
            Log.debug(type: .synthesizer, "Request is nil. Cleaning up.")
            actionFlags.pointee = .offlineUnitRenderAction_Complete
            self.cleanUp()
            return noErr
        }

        let intFrameCount = Int(frameCount)
        let availableCount: Int
        os_unfair_lock_lock(&outputDataLock)
        availableCount = outputData.count
        os_unfair_lock_unlock(&outputDataLock)

        let countToCopy = min(availableCount, intFrameCount)

        if countToCopy < intFrameCount {
            let completedRendering = piper.completed()
            if (completedRendering && availableCount == 0) || request == nil {
                Log.debug(type: .synthesizer, "Completed rendering")
                actionFlags.pointee = .offlineUnitRenderAction_Complete
                self.cleanUp()
                return noErr
            }

            outputRecurseCallNumber += 1
            if outputRecurseCallNumber < outputRecurseCallNumberMax && !completedRendering {
                Log.error(type: .synthesizer, "Rendering in progress no data. Trying one more time: \(self.outputRecurseCallNumber)")
                pauseUntil(maxDelayFactor: outputRecurseCallNumberMax) { [weak self] in
                    guard let self else { return true }
                    os_unfair_lock_lock(&self.outputDataLock)
                    let hasEnoughData = self.outputData.count >= intFrameCount
                    let isCancelled = self.request == nil
                    os_unfair_lock_unlock(&self.outputDataLock)
                    return piper.completed() || hasEnoughData || isCancelled
                }
                return doPerformRender(actionFlags: actionFlags, timestamp: timestamp, frameCount: frameCount, outputBusNumber: outputBusNumber, outputAudioBufferList: outputAudioBufferList, renderEvents: renderEvents, renderPull: renderPull)
            }
            Log.error(type: .synthesizer, "Tried \(self.outputRecurseCallNumber), without luck. Returning what have currently")
        }

        outputRecurseCallNumber = 0

        let actualCopied = min(availableCount, intFrameCount)
        outputAudioBufferList.pointee.mNumberBuffers = 1
        var unsafeBuffer = UnsafeMutableAudioBufferListPointer(outputAudioBufferList)[0]
        let frames = unsafeBuffer.mData!.assumingMemoryBound(to: Float32.self)
        frames.update(repeating: 0, count: intFrameCount)
        unsafeBuffer.mNumberChannels = 1
        unsafeBuffer.mDataByteSize = UInt32(actualCopied * MemoryLayout<Float32>.size)

        os_unfair_lock_lock(&outputDataLock)
        if actualCopied > 0 && outputData.count >= actualCopied {
            outputData.withUnsafeBufferPointer { buf in
                frames.update(from: buf.baseAddress!, count: actualCopied)
            }
            outputData.removeFirst(actualCopied)
        }
        os_unfair_lock_unlock(&outputDataLock)

        actionFlags.pointee = .offlineUnitRenderAction_Render
#if DEBUG
        Log.debug(type: .synthesizer, "Rendered: \(actualCopied). Remaining buffer: \(availableCount - actualCopied)")
#endif
        return noErr
    }

    public override func synthesizeSpeechRequest(_ speechRequest: AVSpeechSynthesisProviderRequest) {
        Log.debug("synthesizeSpeechRequest \(speechRequest.ssmlRepresentation)")
        removeRequestAndCleanOutputData()
        os_unfair_lock_lock(&outputDataLock)
        self.request = speechRequest
        os_unfair_lock_unlock(&outputDataLock)
        createPiperIfNeeded(voiceIdentifier: speechRequest.voice.identifier)
        piper?.synthesizeSSML(speechRequest.ssmlRepresentation,
                              speakerId: speechRequest.voice.identifier.speakerId)
    }

    public override func cancelSpeechRequest() {
        Log.debug("cancelSpeechRequest")
        cleanUp()
    }

    func cleanUp() {
        Log.debug("cleanUp request:\(self.request?.ssmlRepresentation ?? "nil")")
        removeRequestAndCleanOutputData()
    }

    private func removeRequestAndCleanOutputData() {
        os_unfair_lock_lock(&outputDataLock)
        request = nil
        outputData = []
        os_unfair_lock_unlock(&outputDataLock)
        piper?.cancel()
    }

    private func pauseUntil(maxDelayFactor: UInt32, or condition: @escaping () -> Bool) {
        let maxDelaySeconds = Double(baseDelayMicroseconds * maxDelayFactor) / 1_000_000
        let checkIntervalSeconds = maxDelaySeconds / 5.0

        let startTime = Date()

        while !condition() && Date().timeIntervalSince(startTime) < maxDelaySeconds {
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(checkIntervalSeconds))
        }
    }

    private func createPiperIfNeeded(voiceIdentifier: String) {
        guard let model = ModelInfo.installedModelInfo(for: voiceIdentifier),
        let paths = model.installedPath else {
            return
        }

        if model == self.model && piper != nil {
            return
        }
        piper = Piper(modelPath: paths.model.path(percentEncoded: false),
                      andConfigPath: paths.json.path(percentEncoded: false))
        
        Log.debug("Piper Created")
#if os(iOS)
        let availableMemory = Int64(Double(os_proc_available_memory()) * 0.9)
        if availableMemory > 0 {
            Log.debug("Setting memoryThresholdBytes:\(ByteCountFormatter.string(fromByteCount: availableMemory, countStyle: .binary))")
            piper?.memoryThresholdBytes = UInt64(availableMemory)
        }
#endif
        piper?.delegate = self
        self.model = model
    }

    public override var speechVoices: [AVSpeechSynthesisProviderVoice] {
        get {
            return AVSpeechSynthesisProviderVoice.supportedVoices
        }
        set { }
    }

    public override func messageChannel(for channelName: String) -> AUMessageChannel {
        Log.debug("Creating message channel for \(channelName)")
        return PiperMessageChannel(delegate: self)
    }
}

extension PiperTTSAudioUnit: PiperDelegate {
    public func piperDidReceiveSamples(_ samples: UnsafePointer<Float>, withSize size: Int) {
        let buf = UnsafeBufferPointer(start: samples, count: size)
        if size == 0 { return }

        if let modelFormat = model?.audioFormat,
           modelFormat.sampleRate != format.sampleRate {
            let inputCount = size
            let inputSampleRate = modelFormat.sampleRate
            let outputSampleRate = format.sampleRate
            let upsampleRatio = outputSampleRate / inputSampleRate
            let outputCount = Int(round(Double(inputCount) * upsampleRatio))

            var output = [Float](repeating: 0, count: outputCount)

            var rampStart: Float = 0
            var positions = [Float](repeating: 0, count: outputCount)
            var rampStep: Float = (inputCount > 1 && outputCount > 1) ? Float(inputCount - 1) / Float(outputCount - 1) : 0
            vDSP_vramp(&rampStart, &rampStep, &positions, 1, vDSP_Length(outputCount))

            output.withUnsafeMutableBufferPointer { outPtr in
                positions.withUnsafeBufferPointer { posPtr in
                    buf.baseAddress!.withMemoryRebound(to: Float.self, capacity: inputCount) { inPtr in
                        vDSP_vlint(
                            inPtr,                     // input samples
                            posPtr.baseAddress!,       // positions
                            1,                         // stride of positions
                            outPtr.baseAddress!,       // output buffer
                            1,                         // stride of output
                            vDSP_Length(outputCount),  // number of output samples
                            vDSP_Length(inputCount)    // number of input samples
                        )
                    }
                }
            }

            os_unfair_lock_lock(&outputDataLock)
            outputData.append(contentsOf: output)
            os_unfair_lock_unlock(&outputDataLock)

        } else {
            // No resampling needed
            os_unfair_lock_lock(&outputDataLock)
            outputData.append(contentsOf: buf)
            os_unfair_lock_unlock(&outputDataLock)
        }
    }

    public func piperDidGenerateMarkers(_ markers: [PiperSpeechMarker]) {
        os_unfair_lock_lock(&outputDataLock)
        defer { os_unfair_lock_unlock(&outputDataLock) }

        guard let metadataBlock = self.speechSynthesisOutputMetadataBlock,
        let request = self.request else {
            return
        }

        for marker in markers {
            guard let appleMarker = marker.avMarker else {
                continue
            }
#if DEBUG
            let requestText = request.ssmlRepresentation
            let swiftRange = Range(appleMarker.textRange, in: requestText)
            let text = if let swiftRange {
                String(requestText[swiftRange])
            } else {
                "<no valid range>"
            }

            Log.debug("DidGenerateMarker [type:\(appleMarker.mark)] offset:\(appleMarker.byteSampleOffset), text:'\(text)'")
#endif
            metadataBlock([appleMarker], request)
        }
    }
}

extension PiperTTSAudioUnit: PiperMessageChannelDelegate {
    var isSyntehizerRunning: Bool {
        os_unfair_lock_lock(&outputDataLock)
        let result = request != nil
        os_unfair_lock_unlock(&outputDataLock)
        return result
    }
}

extension PiperSpeechMarker {
    var avMarker: AVSpeechSynthesisMarker? {
        let avType =
        switch type {
        case .sentence:
            AVSpeechSynthesisMarker.Mark.sentence
        case .word:
            AVSpeechSynthesisMarker.Mark.word
        }
        return AVSpeechSynthesisMarker(markerType: avType, forTextRange: range, atByteSampleOffset: byteOffset)
    }
}
