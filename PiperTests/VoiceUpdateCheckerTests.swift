// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import XCTest
@testable import Piper
import PiperAppUtils
import Foundation

final class VoiceUpdateCheckerTests: XCTestCase {

    private typealias Installed = VoiceUpdateChecker.InstalledFiles

    /// Catalog entry with digests on both files and an INT8 variant,
    /// shaped exactly like the live fp16 catalog.
    private var catalogJSON: Data {
        // swiftlint:disable:next non_optional_string_data_conversion
        """
        {
          "key":"en_US-lessac-medium",
          "name":"lessac",
          "quality":"medium",
          "language":{"code":"en_US","family":"en","region":"US"},
          "files":{
            "en/en_US/lessac/medium/en_US-lessac-medium.onnx":{"size_bytes":1000,"md5_digest":"aaaa"},
            "en/en_US/lessac/medium/en_US-lessac-medium.onnx.json":{"size_bytes":100,"md5_digest":"bbbb"},
            "en/en_US/lessac/medium/MODEL_CARD":{"size_bytes":10,"md5_digest":"cccc"}
          },
          "variants":{
            "int8":{"model":"en/en_US/lessac/medium/en_US-lessac-medium.int8.onnx","size_bytes":600}
          }
        }
        """.data(using: .utf8)!
    }

    private func decodeVoice() throws -> Voice {
        try JSONDecoder().decode(Voice.self, from: catalogJSON)
    }

    func testCatalogDigestsDecoded() throws {
        let voice = try decodeVoice()
        XCTAssertEqual(voice.catalogModelFile?.md5Digest, "aaaa")
        XCTAssertEqual(voice.catalogModelFile?.size_bytes, 1000)
        XCTAssertEqual(voice.catalogJSONFile?.md5Digest, "bbbb")
    }

    func testDigestDoesNotChangeVoiceIdentity() throws {
        // The same production-safety rule as licenses and variants:
        // digests feed update detection only, never equality/hash.
        let voice = try decodeVoice()
        let noDigestJSON = catalogJSON
        var json = try JSONSerialization.jsonObject(with: noDigestJSON) as? [String: Any]
        var files = json?["files"] as? [String: Any]
        for path in files?.keys ?? [] {
            var file = files?[path] as? [String: Any]
            file?["md5_digest"] = "ffff"
            files?[path] = file
        }
        json?["files"] = files
        let otherData = try JSONSerialization.data(withJSONObject: json as Any)
        let other = try JSONDecoder().decode(Voice.self, from: otherData)
        XCTAssertEqual(voice, other)
        XCTAssertEqual(voice.hashValue, other.hashValue)
    }

    func testUpToDateStandardBuild() throws {
        let voice = try decodeVoice()
        let installed = Installed(modelSize: 1000, modelMD5: "aaaa", configMD5: "bbbb")
        XCTAssertEqual(VoiceUpdateChecker.status(voice: voice, installed: installed), .upToDate)
    }

    func testRetrainedModelIsUpdate() throws {
        let voice = try decodeVoice()
        let installed = Installed(modelSize: 1000, modelMD5: "dddd", configMD5: "bbbb")
        XCTAssertEqual(VoiceUpdateChecker.status(voice: voice, installed: installed), .updateAvailable)
    }

    func testConfigOnlyChangeIsUpdate() throws {
        // The 2026-10-03 dataset fixes changed only .onnx.json files.
        let voice = try decodeVoice()
        let installed = Installed(modelSize: 1000, modelMD5: "aaaa", configMD5: "eeee")
        XCTAssertEqual(VoiceUpdateChecker.status(voice: voice, installed: installed), .updateAvailable)
    }

    func testCompactBuildCurrentByVariantSize() throws {
        // Installed model is the INT8 build: its digest cannot match
        // the standard build's, but its size is the variant's size.
        let voice = try decodeVoice()
        let installed = Installed(modelSize: 600, modelMD5: "dddd", configMD5: "bbbb")
        XCTAssertEqual(VoiceUpdateChecker.status(voice: voice, installed: installed), .upToDate)
    }

    func testCompactBuildStaleWhenVariantSizeChanges() throws {
        let voice = try decodeVoice()
        let installed = Installed(modelSize: 590, modelMD5: "dddd", configMD5: "bbbb")
        XCTAssertEqual(VoiceUpdateChecker.status(voice: voice, installed: installed), .updateAvailable)
    }

    func testDigestComparisonIsCaseInsensitive() throws {
        let voice = try decodeVoice()
        let installed = Installed(modelSize: 1000, modelMD5: "AAAA", configMD5: "BBBB")
        XCTAssertEqual(VoiceUpdateChecker.status(voice: voice, installed: installed), .upToDate)
    }

    func testSizeOnlyDifferenceIsUpdate() {
        let status = VoiceUpdateChecker.status(
            catalogModelMD5: nil, catalogModelSize: 1000,
            catalogConfigMD5: nil, variantModelSize: 600,
            installed: Installed(modelSize: 900, modelMD5: nil, configMD5: nil))
        XCTAssertEqual(status, .updateAvailable)
    }

    func testSizeMatchWithoutDigestsIsUnknown() {
        // A rebuilt model can keep its byte size; without digests
        // the checker must not claim the voice is up to date.
        let status = VoiceUpdateChecker.status(
            catalogModelMD5: nil, catalogModelSize: 1000,
            catalogConfigMD5: nil, variantModelSize: nil,
            installed: Installed(modelSize: 1000, modelMD5: nil, configMD5: nil))
        XCTAssertEqual(status, .unknown)
    }

    func testUnreadableInstalledFilesAreUnknown() throws {
        let voice = try decodeVoice()
        let installed = Installed(modelSize: nil, modelMD5: nil, configMD5: nil)
        XCTAssertEqual(VoiceUpdateChecker.status(voice: voice, installed: installed), .unknown)
    }

    func testUpdateAvailableKeys() throws {
        let voice = try decodeVoice()
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        let model = folder.appendingPathComponent("model.onnx")
        let json = folder.appendingPathComponent("model.onnx.json")
        var stale = try XCTUnwrap(FileManager.ModelPaths(model: model, json: json))
        stale.catalogKey = voice.key
        var current = try XCTUnwrap(FileManager.ModelPaths(model: model, json: json))
        current.catalogKey = "other-voice"

        let keys = VoiceUpdateChecker.updateAvailableKeys(
            voices: [voice],
            installed: [stale, current]
        ) { paths in
            paths.catalogKey == voice.key
                ? Installed(modelSize: 1000, modelMD5: "dddd", configMD5: "bbbb")
                : Installed(modelSize: 1000, modelMD5: "aaaa", configMD5: "bbbb")
        }
        XCTAssertEqual(keys, [voice.key])
    }

    func testMD5DigestOfFile() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try Data("abc".utf8).write(to: url)
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        XCTAssertEqual(VoiceUpdateChecker.md5Digest(ofFileAt: url),
                       "900150983cd24fb0d6963f7d28e17f72")
    }

    func testMD5DigestReadsInChunks() throws {
        // Larger than the 1 MB read chunk, so the loop must iterate.
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try Data(repeating: 0x61, count: 1_500_000).write(to: url)
        defer {
            try? FileManager.default.removeItem(at: url)
        }
        XCTAssertEqual(VoiceUpdateChecker.md5Digest(ofFileAt: url),
                       "de903a5a2a7df6cef1817c455d413359")
    }

    func testMD5DigestOfMissingFileIsNil() {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("missing-\(UUID().uuidString)")
        XCTAssertNil(VoiceUpdateChecker.md5Digest(ofFileAt: url))
    }
}
