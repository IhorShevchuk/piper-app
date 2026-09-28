// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
@testable import PiperAppUtils
import Foundation

/// Speaker ID must never silently fall back to 0: an unparseable identifier
/// is a malformed voice, and callers must fail loudly instead of speaking
/// with the wrong voice.
final class ModelInfoSpeakerIdTests: XCTestCase {

    private var twoSpeakerInfo: ModelInfo {
        get throws {
            let json = """
            {
              "dataset":"en_US-lessac-high",
              "piper_version":"1.2.3",
              "language":{"code":"en_US","family":"en","region":"US"},
              "audio":{"sample_rate":22050,"quality":"high"},
              "speaker_id_map":{"0":0,"1":1},
              "num_speakers":2
            }
            """
            return try JSONDecoder().decode(ModelInfo.self, from: Data(json.utf8))
        }
    }

    func testSpeakerIdParsesValidIdentifier() throws {
        let info = try twoSpeakerInfo
        XCTAssertEqual(try ModelInfo.speakerId(from: "\(info.voiceId)\(Constants.speakerIdSeparator)1"), 1)
    }

    func testSpeakerIdParsesZero() throws {
        let info = try twoSpeakerInfo
        XCTAssertEqual(try ModelInfo.speakerId(from: "\(info.voiceId)\(Constants.speakerIdSeparator)0"), 0)
    }

    func testSpeakerIdParsesBareVoiceIdWithNumericTail() throws {
        // Single-speaker voices carry no "<+>" suffix; the trailing component
        // (num_speakers) keeps parsing as before so playback keeps working.
        let info = try twoSpeakerInfo
        XCTAssertEqual(try ModelInfo.speakerId(from: info.voiceId), 2)
    }

    func testSpeakerIdThrowsWhenTrailingComponentNotNumeric() throws {
        let identifier = "en_US-lessac-high>0<high>0<22050>0<en_US>0<two"
        XCTAssertThrowsError(try ModelInfo.speakerId(from: identifier)) { error in
            assertInvalidSpeakerId(error, identifier: identifier)
        }
    }

    func testSpeakerIdThrowsWhenNotNumeric() throws {
        let info = try twoSpeakerInfo
        let identifier = "\(info.voiceId)\(Constants.speakerIdSeparator)abc"
        XCTAssertThrowsError(try ModelInfo.speakerId(from: identifier)) { error in
            assertInvalidSpeakerId(error, identifier: identifier)
        }
    }

    func testSpeakerIdThrowsWhenEmpty() {
        XCTAssertThrowsError(try ModelInfo.speakerId(from: "")) { error in
            assertInvalidSpeakerId(error, identifier: "")
        }
    }

    func testSpeakerIdThrowsWhenTrailingSeparator() throws {
        let info = try twoSpeakerInfo
        let identifier = "\(info.voiceId)\(Constants.speakerIdSeparator)"
        XCTAssertThrowsError(try ModelInfo.speakerId(from: identifier)) { error in
            assertInvalidSpeakerId(error, identifier: identifier)
        }
    }

    func testSpeakerIdThrowsForPlainString() {
        let identifier = "just-a-name"
        XCTAssertThrowsError(try ModelInfo.speakerId(from: identifier)) { error in
            assertInvalidSpeakerId(error, identifier: identifier)
        }
    }

    // MARK: - Helpers

    private func assertInvalidSpeakerId(
        _ error: Error,
        identifier: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case ModelInfo.Error.invalidSpeakerId(let value) = error else {
            XCTFail("Expected ModelInfo.Error.invalidSpeakerId, got \(error)", file: file, line: line)
            return
        }
        XCTAssertEqual(value, identifier, file: file, line: line)
    }
}
