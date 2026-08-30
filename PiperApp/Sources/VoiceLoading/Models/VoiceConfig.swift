// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

struct VoiceConfig: Decodable {
    let phonemeType: String?

    enum CodingKeys: String, CodingKey {
        case phonemeType = "phoneme_type"
    }
}
