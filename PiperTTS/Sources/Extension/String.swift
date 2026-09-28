// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

extension String {
    /// Speaker ID parsed from a full voice identifier, or nil when the
    /// identifier is malformed. Never silently falls back to 0.
    var speakerId: Int32? {
        try? ModelInfo.speakerId(from: self)
    }
}
