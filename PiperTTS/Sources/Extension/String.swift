// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

extension String {
    var speakerId: Int32 {
        guard let voiceId = components(separatedBy: ModelInfo.separator).last else {
            return 0
        }
        guard let speakerId = voiceId.components(separatedBy: Constants.speakerIdSeparator).last,
              let result = Int32(speakerId) else {
            return 0
        }
        return result
    }
}
