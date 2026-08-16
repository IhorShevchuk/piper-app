// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
@testable import PiperAppUtils
import Foundation

final class ModelInfoTests: XCTestCase {

    private var sampleJSON: Data {
        """
        {
          "dataset":"en_US-lessac-high",
          "piper_version":"1.2.3",
          "language":{"code":"en_US","family":"en","region":"US"},
          "audio":{"sample_rate":22050,"quality":"high"},
          "speaker_id_map":{"0":0,"1":1},
          "num_speakers":2
        }
        """.data(using: .utf8)!
    }

    private var sampleJSONNoSpeakers: Data {
        """
        {
          "dataset":"uk_UA-ukrainian-high",
          "piper_version":"1.0.0",
          "language":{"code":"uk_UA","family":"uk","region":"UA"},
          "audio":{"sample_rate":16000,"quality":"medium"}
        }
        """.data(using: .utf8)!
    }

    func testDecodingWithSpeakers() throws {
        let info = try JSONDecoder().decode(ModelInfo.self, from: sampleJSON)
        XCTAssertEqual(info.dataset, "en_US-lessac-high")
        XCTAssertEqual(info.piperVersion, "1.2.3")
        XCTAssertEqual(info.language.code, "en_US")
        XCTAssertEqual(info.audio.sampleRate, 22050)
        XCTAssertEqual(info.numberOfSpeakers, 2)
        XCTAssertEqual(info.speakers.count, 2)
    }

    func testDecodingDefaults() throws {
        let info = try JSONDecoder().decode(ModelInfo.self, from: sampleJSONNoSpeakers)
        XCTAssertEqual(info.speakers, [:])
        XCTAssertEqual(info.numberOfSpeakers, 1)
        XCTAssertEqual(info.name, "uk_UA-ukrainian-high")
    }

    func testNameFallback() throws {
        // name is dataset ?? "Unknown"
        let info = try JSONDecoder().decode(ModelInfo.self, from: sampleJSONNoSpeakers)
        XCTAssertFalse(info.name.isEmpty)
    }

    func testVoiceIdComponents() throws {
        let info = try JSONDecoder().decode(ModelInfo.self, from: sampleJSON)
        let voiceId = info.voiceId
        let parts = voiceId.components(separatedBy: ModelInfo.separator)
        XCTAssertEqual(parts.count, 5)
        XCTAssertEqual(parts[0], info.name)
        XCTAssertEqual(parts[1], info.audio.quality)
        XCTAssertEqual(parts[2], "\(info.audio.sampleRate)")
        XCTAssertEqual(parts[3], info.language.code)
        // 5th contains numberOfSpeakers possibly with speaker separator suffix
        XCTAssertTrue(parts[4].hasPrefix("\(info.numberOfSpeakers)"))
    }

    func testEqualityAndHash() throws {
        let firstInfo = try JSONDecoder().decode(ModelInfo.self, from: sampleJSON)
        let secondInfo = try JSONDecoder().decode(ModelInfo.self, from: sampleJSON)
        XCTAssertEqual(firstInfo, secondInfo)
        XCTAssertEqual(firstInfo.hashValue, secondInfo.hashValue)
    }

    func testCreateFromNilThrows() {
        XCTAssertThrowsError(try ModelInfo.create(from: nil)) { error in
            guard let modelError = error as? ModelInfo.Error else {
                XCTFail("wrong error type \(error)"); return
            }
            if case .nilFileURL = modelError { } else { XCTFail("expected nilFileURL") }
        }
    }

    func testCreateFromTempFile() throws {
        let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
        try sampleJSON.write(to: tmp)
        defer { try? FileManager.default.removeItem(at: tmp) }
        let info = try ModelInfo.create(from: tmp)
        XCTAssertEqual(info.piperVersion, "1.2.3")
    }

    func testInstalledModelInfoForMalformed() {
        XCTAssertNil(ModelInfo.installedModelInfo(for: "bad-id"))
        XCTAssertNil(ModelInfo.installedModelInfo(for: "a>0<b>0<c"))
        XCTAssertNil(ModelInfo.installedModelInfo(for: ""))
    }

    func testInstalledEmptyWhenNoFiles() {
        // In test env app group container is nil, so installedModels should be empty
        // This test just ensures it doesn't crash and returns array
        let models = ModelInfo.installedModels
        XCTAssertNotNil(models)
    }
}
