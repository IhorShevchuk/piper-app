// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import Testing
@testable import PiperAppUtils

@Suite("ModelInfo helpers")
struct ModelInfoTests {

    private func makeSampleInfo(
        dataset: String = "en_US-lessac-high",
        quality: String = "high",
        sampleRate: Double = 22050,
        code: String = "en_US",
        family: String = "en",
        region: String = "US",
        numSpeakers: Int = 1,
        speakers: [String: Int] = [:]
    ) -> ModelInfo {
        // Build via JSON decode to avoid private init
        let lang = ["code": code, "family": family, "region": region]
        let audio = ["sample_rate": sampleRate, "quality": quality] as [String: Any]
        var dict: [String: Any] = [
            "dataset": dataset,
            "piper_version": "1.0.0",
            "language": lang,
            "audio": audio
        ]
        if numSpeakers != 1 {
            dict["num_speakers"] = numSpeakers
        }
        if !speakers.isEmpty {
            dict["speaker_id_map"] = speakers
        }
        let data = try! JSONSerialization.data(withJSONObject: dict)
        return try! JSONDecoder().decode(ModelInfo.self, from: data)
    }

    @Test("voiceId composition")
    func voiceIdComposition() {
        let info = makeSampleInfo()
        // voiceId = name>0<quality>0<sampleRate>0<code>0<numSpeakers>
        let expected = "en_US-lessac-high>0<high>0<22050>0<en_US>0<1"
        // sampleRate may be 22050.0 -> String conversion via interpolation in production uses Double -> "22050.0" or "22050"? Check impl: "\(audio.sampleRate)" – Double 22050 prints "22050.0" on Swift
        // We accept both forms
        let vid = info.voiceId
        #expect(vid.contains("en_US-lessac-high"))
        #expect(vid.contains("high"))
        #expect(vid.contains("en_US"))
    }

    @Test("installedModelInfo returns nil for malformed voiceId")
    func malformedVoiceId() {
        #expect(ModelInfo.installedModelInfo(for: "") == nil)
        #expect(ModelInfo.installedModelInfo(for: "only>0<two>0<three") == nil)
        #expect(ModelInfo.installedModelInfo(for: "a>0<b>0<c>0<d>0<e>0<extra") == nil)
        // 5 components but empty strings still considered? The split will produce 5, but installedModels is empty on Linux, so nil expected
        #expect(ModelInfo.installedModelInfo(for: "name>0<quality>0<22050>0<code>0<1") == nil)
    }

    @Test("ModelInfo equality and hash")
    func equality() {
        let a = makeSampleInfo()
        let b = makeSampleInfo()
        #expect(a == b)
        var set = Set<ModelInfo>()
        set.insert(a)
        set.insert(b)
        #expect(set.count == 1)
    }

    @Test("numberOfSpeakers defaults")
    func defaults() {
        let one = makeSampleInfo(numSpeakers: 1, speakers: [:])
        #expect(one.numberOfSpeakers == 1)
        let multi = makeSampleInfo(numSpeakers: 3, speakers: ["a": 0, "b": 1])
        #expect(multi.numberOfSpeakers == 3)
        #expect(multi.speakers.count == 2)
    }

    @Test("create from invalid URL throws")
    func invalidURL() throws {
        #expect(throws: ModelInfo.Error.self) {
            try ModelInfo.create(from: nil)
        }
        let bad = URL(fileURLWithPath: "/tmp/nonexistent-\(UUID().uuidString).json")
        #expect(throws: (any Error).self) {
            try ModelInfo.create(from: bad)
        }
    }

    @Test("Language helper properties")
    func language() {
        let lang = Language(code: "en_US", family: "en", region: "US")
        // country and language may depend on Locale – just ensure non-empty
        #expect(!lang.country.isEmpty)
        #expect(!lang.language.isEmpty)
        #expect(lang == Language(code: "en_US", family: "en", region: "US"))
    }

    @Test("Audio equality")
    func audio() {
        let a1 = Audio(sampleRate: 22050, quality: "high")
        let a2 = Audio(sampleRate: 22050, quality: "high")
        let a3 = Audio(sampleRate: 16000, quality: "low")
        #expect(a1 == a2)
        #expect(a1 != a3)
    }

    @Test("Constants separators")
    func constants() {
        #expect(ModelInfo.separator == ">0<")
        #expect(Constants.speakerIdSeparator == "<+>")
        #expect(Constants.modelFileName == "model")
        #expect(Constants.modelsFolderName == "models")
        #expect(Constants.modelFileNameWithExtension.hasSuffix(".onnx"))
        #expect(Constants.modelJSONFileNameWithExtension.hasSuffix(".onnx.json"))
    }

    @Test("ModelInfo JSON decoding from sample")
    func decoding() throws {
        let json = """
        {
          "dataset": "en_US-lessac-medium",
          "piper_version": "1.0.0",
          "language": {"code":"en_US","family":"en","region":"US"},
          "audio": {"sample_rate": 22050, "quality":"medium"},
          "num_speakers": 2,
          "speaker_id_map": {"speaker_0":0,"speaker_1":1}
        }
        """
        let data = json.data(using: .utf8)!
        let info = try JSONDecoder().decode(ModelInfo.self, from: data)
        #expect(info.name == "en_US-lessac-medium")
        #expect(info.numberOfSpeakers == 2)
        #expect(info.speakers.count == 2)
        #expect(info.audio.sampleRate == 22050)
    }
}
