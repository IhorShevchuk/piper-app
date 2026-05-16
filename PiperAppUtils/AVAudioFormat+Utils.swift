// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import AVFoundation

extension ModelInfo {
    public var audioFormat: AVAudioFormat? {
        return AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: audio.sampleRate, channels: 1, interleaved: true)
    }
}
