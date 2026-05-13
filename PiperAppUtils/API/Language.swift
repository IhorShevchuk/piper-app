// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

public struct Language: Decodable {
    enum CodingKeys: String, CodingKey {
        case code
        case family
        case region
    }
    public let code: String
    public let family: String
    public let region: String
    
    public var country: String {
        Locale.current.localizedString(forRegionCode: region) ?? region
    }
    
    public var language: String {
        Locale.current.localizedString(forLanguageCode: family) ?? family
    }
}

extension Language: Equatable {
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.code == rhs.code
        && lhs.family == rhs.family
        && lhs.region == rhs.region
    }
}

extension Language: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
        hasher.combine(family)
        hasher.combine(region)
    }
}
