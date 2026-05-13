// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import AVFoundation

extension AVAudioFormat {
    public static var defaultFormat: AVAudioFormat? {
        return AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 22050.0, channels: 1, interleaved: true)
    }
}

extension ModelInfo {
    public var audioFormat: AVAudioFormat? {
        return AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: audio.sampleRate, channels: 1, interleaved: true)
    }
}
