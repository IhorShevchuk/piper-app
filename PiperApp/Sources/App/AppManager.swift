// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

class AppManager {
    static let shared = AppManager()
    let piper = PiperManager()
    lazy var loader = VoiceLoader()
    init() {
        try? FileManager.default.cleanTemporaryDirectory()
    }

    deinit {
        try? FileManager.default.cleanTemporaryDirectory()
    }
}
