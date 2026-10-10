// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

struct VoiceViewModel {
    var paths: FileManager.ModelPaths
    var modelInfo: ModelInfo?
    var isPlaying: Bool = false
    var selectedSpeaker: Int = 0
    var demoText: String = DemoText.defaultText
}
