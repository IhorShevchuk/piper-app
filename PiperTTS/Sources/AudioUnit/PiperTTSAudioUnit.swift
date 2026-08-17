// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import AVFoundation
import piper_objc
#if canImport(piper_utils)
import piper_utils
#endif
import PiperAppUtils
import PiperTTSLogic
import Accelerate

public class PiperTTSAudioUnit: AVSpeechSynthesisProviderAudioUnit {
    private var outputBus: AUAudioUnitBus
    private var _outputBusses: AUAudioUnitBusArray!

    private var request: AVSpeechSynthesisProviderRequest?

    private var format: AVAudioFormat

    var piper: Piper?
    var model: ModelInfo?

    private var outputDataLock = os_unfair_lock_s()
    internal var outputData = FloatRingBuffer()
    private var outputRecurseCallNumber = 0

    // MARK: - Alignment (phoneme timing) – auxiliary storage
    // Tiny vs 250 MB iOS limit: ~500 groups for 5 sec audio (< few KB, each group tens of bytes)
    // vs 110k Float samples (~440 KB) and 250 MB guard. Bounded with sliding window to avoid
    // unbounded growth across long SSML; cleared on cancel/dealloc.
    // Reuses outputDataLock for protection – callback runs on OperationQueue maxConcurrent 1 (same as samples),
    // render thread only reads outputData, so brief lock is safe. No AVFoundation block called inside lock.
    private var lastAlignmentGroups: [PiperAlignmentParser.PhonemeGroup] = []
    private let maxAlignmentGroups = 5000 // defensive cap; 5 sec ≈ 500 groups, never reached
    private let alignmentSlidingWindowKeep = 500

    private let outputRecurseCallNumberMax: UInt32 = 200
    private let baseDelayMicroseconds: UInt32 = 500
    internal let maxBufferDurationSeconds: Double = 5.0
    internal let maxSamplesCount: Int

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
        os_unfair_lock_lock(&outputDataLock)
        outputData.clear()
        lastAlignmentGroups.removeAll(keepingCapacity: false)
        os_unfair_lock_unlock(&outputDataLock)
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

    // Made internal for unit testing – previously private
    // swiftlint:disable:next function_parameter_count function_body_length
    internal func doPerformRender(
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
        // Zero-fill only when we have less data than requested – otherwise we will overwrite entire buffer
        if actualCopied < intFrameCount {
            frames.update(repeating: 0, count: intFrameCount)
        }
        unsafeBuffer.mNumberChannels = 1
        unsafeBuffer.mDataByteSize = UInt32(actualCopied * MemoryLayout<Float32>.size)

        os_unfair_lock_lock(&outputDataLock)
        if actualCopied > 0 {
            outputData.withUnsafeBufferPointer { src in
                if let base = src.baseAddress {
                    frames.update(from: base, count: actualCopied)
                }
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
        outputData.clear()
        lastAlignmentGroups.removeAll(keepingCapacity: false)
        os_unfair_lock_unlock(&outputDataLock)
        piper?.cancel()
    }

    internal func pauseUntil(maxDelayFactor: UInt32, or condition: @escaping () -> Bool) {
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
            let resampled = AudioResampler.resampleBuffer(buf, inputRate: modelFormat.sampleRate, outputRate: format.sampleRate)
            os_unfair_lock_lock(&outputDataLock)
            outputData.appendAndEnforceMax(contentsOf: resampled, maxCount: maxSamplesCount)
            os_unfair_lock_unlock(&outputDataLock)
        } else {
            os_unfair_lock_lock(&outputDataLock)
            outputData.appendAndEnforceMax(contentsOf: buf, maxCount: maxSamplesCount)
            os_unfair_lock_unlock(&outputDataLock)
        }
    }

    // MARK: - Alignment delegate (optional Swift method)
    // piper-objc now supplies precise phoneme alignment in PiperAlignmentParser.PhonemeGroup:
    //   phoneme UInt32, codepoints [UInt32], ids [Int32], alignments [Int] (samples already scaled by hop_length),
    //   sampleCount Int, cumulativeOffsetBefore Int, isSpecial Bool (ids 0…2 BOS/PAD/EOS), cumulativeOffsetAfter computed.
    // Groups are delivered incrementally per chunk on OperationQueue maxConcurrent 1 (same queue as samples),
    // so storing here is thread-safe with brief lock – render thread never reads alignment, only outputData.
    // Markers are already alignment-derived in piper-objc (generateMarkersWithAlignment), so we don't retime here.
    // This storage is auxiliary (< few KB, ~500 groups for 5 sec) vs 250 MB iOS limit, bounded with sliding window.
    public func piperDidReceiveAlignment(groups: [PiperAlignmentParser.PhonemeGroup]) {
        guard !groups.isEmpty else { return }

        // Quick stats for DEBUG without holding lock during logging
        let totalSamples = groups.reduce(0) { $0 + $1.sampleCount }
        let specialCount = groups.reduce(0) { $0 + ($1.isSpecial ? 1 : 0) }

        os_unfair_lock_lock(&outputDataLock)
        // Append – we get per-chunk groups, not full sentence, so accumulation preserves sentence context.
        // Reset on new synthesis via removeRequestAndCleanOutputData / deallocateRenderResources.
        lastAlignmentGroups.append(contentsOf: groups)
        if lastAlignmentGroups.count > maxAlignmentGroups {
            // Hard cap impossible for 5 sec, but truncate defensively
            lastAlignmentGroups.removeFirst(lastAlignmentGroups.count - alignmentSlidingWindowKeep)
        } else if lastAlignmentGroups.count > 1000 {
            // Soft sliding window to keep memory tiny while preserving recent context for long SSML
            lastAlignmentGroups.removeFirst(lastAlignmentGroups.count - alignmentSlidingWindowKeep)
        }
        let storedCount = lastAlignmentGroups.count
        os_unfair_lock_unlock(&outputDataLock)

#if DEBUG
        Log.debug(type: .synthesizer, "Alignment groups: \(groups.count) (specials: \(specialCount)), samples: \(totalSamples), stored total: \(storedCount)")
#endif
        // NOTE: groups unused beyond storage; marker timing already correct from piper-objc.
        _ = specialCount
        _ = totalSamples
        _ = storedCount
    }

    public func piperDidGenerateMarkers(_ markers: [PiperSpeechMarker]) {
        // piper-objc now prefers generateMarkersWithAlignment when alignment groups non-empty:
        //   totalSamples = sum alignments, realGroups = filter !isSpecial,
        //   punctuationTrimSet = "‘’'\".,;:!?()[]{}—–" trimming for #31,
        //   coreWords proportional distribution, byteOffset = start + cumulative*4 (Float size), monotonic.
        // This AU just forwards those improved markers via AVFoundation metadata block.
        // Example: hello=0, world=880 = 220*4 (220 samples * Float32 size). Legacy fallback still exists for file synthesis path.
        // Thread-safe pattern: copy metadataBlock/request out of lock, then callback outside lock.

        // Copy metadata block and request out of lock to avoid holding lock during callback
        os_unfair_lock_lock(&outputDataLock)
        let metadataBlock = self.speechSynthesisOutputMetadataBlock
        let request = self.request
        os_unfair_lock_unlock(&outputDataLock)

        guard let metadataBlock = metadataBlock,
              let request = request else {
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
