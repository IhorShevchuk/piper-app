// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
@testable import PiperAppUtils

final class LanguageAudioTests: XCTestCase {

    func testLanguageDecoding() throws {
        // swiftlint:disable:next non_optional_string_data_conversion
        let json = """
        {"code":"en_US","family":"en","region":"US"}
        """.data(using: .utf8)!
        let lang = try JSONDecoder().decode(Language.self, from: json)
        XCTAssertEqual(lang.code, "en_US")
        XCTAssertEqual(lang.family, "en")
        XCTAssertEqual(lang.region, "US")
    }

    func testLanguageEquatableAndHashable() throws {
        // swiftlint:disable:next non_optional_string_data_conversion
        let json = """
        {"code":"uk_UA","family":"uk","region":"UA"}
        """.data(using: .utf8)!
        // swiftlint:disable:next identifier_name
        let l1 = try JSONDecoder().decode(Language.self, from: json)
        // swiftlint:disable:next identifier_name
        let l2 = try JSONDecoder().decode(Language.self, from: json)
        XCTAssertEqual(l1, l2)
        XCTAssertEqual(l1.hashValue, l2.hashValue)
        var set = Set<Language>()
        set.insert(l1)
        XCTAssertTrue(set.contains(l2))
    }

    func testLanguageCountryAndLanguageFallback() {
        let lang = Language(code: "xx_YY", family: "xx", region: "YY")
        // Locale may not know these codes, fallback to raw code
        XCTAssertFalse(lang.country.isEmpty)
        XCTAssertFalse(lang.language.isEmpty)
    }

    func testAudioDecoding() throws {
        // swiftlint:disable:next non_optional_string_data_conversion
        let json = """
        {"sample_rate":22050,"quality":"high"}
        """.data(using: .utf8)!
        let audio = try JSONDecoder().decode(Audio.self, from: json)
        XCTAssertEqual(audio.sampleRate, 22050)
        XCTAssertEqual(audio.quality, "high")
    }

    func testAudioEquatableHashable() {
        // swiftlint:disable:next identifier_name
        let a1 = Audio(sampleRate: 16000, quality: "medium")
        // swiftlint:disable:next identifier_name
        let a2 = Audio(sampleRate: 16000, quality: "medium")
        // swiftlint:disable:next identifier_name
        let a3 = Audio(sampleRate: 22050, quality: "high")
        XCTAssertEqual(a1, a2)
        XCTAssertNotEqual(a1, a3)
        XCTAssertEqual(a1.hashValue, a2.hashValue)
    }

    // Helpers to construct Language/Audio without public init – use Decodable
}

extension Language {
    init(code: String, family: String, region: String) {
        let dict: [String: String] = ["code": code, "family": family, "region": region]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let decoded = try? JSONDecoder().decode(Language.self, from: data) else {
            fatalError("Failed to decode Language from \(dict)")
        }
        self = decoded
    }
}

extension Audio {
    init(sampleRate: Double, quality: String) {
        let dict: [String: Any] = ["sample_rate": sampleRate, "quality": quality]
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let decoded = try? JSONDecoder().decode(Audio.self, from: data) else {
            fatalError("Failed to decode Audio from \(dict)")
        }
        self = decoded
    }
}
