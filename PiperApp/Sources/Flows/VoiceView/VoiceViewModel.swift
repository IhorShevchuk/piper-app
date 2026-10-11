// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

struct VoiceViewModel {
    var paths: FileManager.ModelPaths
    var modelInfo: ModelInfo?
    /// A newer catalog build of this voice exists.
    var updateAvailable: Bool = false
    var isUpdating: Bool = false
    var updateProgress: Double = 0.0
    var isPlaying: Bool = false
    var selectedSpeaker: Int = 0
    var demoText: String = DemoText.defaultText
}
