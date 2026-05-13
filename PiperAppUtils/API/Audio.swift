// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

public struct Audio: Decodable {
    enum CodingKeys: String, CodingKey {
        case sampleRate = "sample_rate"
        case quality
    }
    public let sampleRate: Double
    public let quality: String
}

extension Audio: Equatable {
    static public func == (lhs: Self, rhs: Self) -> Bool {
        lhs.sampleRate == rhs.sampleRate && lhs.quality == rhs.quality
    }
}

extension Audio: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(sampleRate)
        hasher.combine(quality)
    }
}
