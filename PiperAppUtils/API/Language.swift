// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

public struct Language: Decodable {
    enum CodingKeys: String, CodingKey {
        case code
        case family
        case region
        case nameEnglish = "name_english"
        case nameNative = "name_native"
        case countryEnglish = "country_english"
    }
    public let code: String
    public let family: String
    public let region: String
    public let nameEnglish: String?
    public let nameNative: String?
    public let countryEnglish: String?

    /// Community-trained configs sometimes ship a stripped language block
    /// (e.g. `"language": {"code": "en-gb-x-rp"}` with no family/region).
    /// Derive the missing parts from the code so such voices stay
    /// downloadable instead of failing model validation.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        code = try container.decode(String.self, forKey: .code)
        let components = code.split(whereSeparator: { $0 == "_" || $0 == "-" }).map(String.init)
        family = try container.decodeIfPresent(String.self, forKey: .family)
            ?? components.first?.lowercased()
            ?? code
        region = try container.decodeIfPresent(String.self, forKey: .region)
            ?? components.dropFirst().first?.uppercased()
            ?? ""
        nameEnglish = try container.decodeIfPresent(String.self, forKey: .nameEnglish)
        nameNative = try container.decodeIfPresent(String.self, forKey: .nameNative)
        countryEnglish = try container.decodeIfPresent(String.self, forKey: .countryEnglish)
    }

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
