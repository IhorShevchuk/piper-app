// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

public struct ModelInfo: Decodable {
    enum CodingKeys: String, CodingKey {
        case dataset
        case piperVersion = "piper_version"
        case language
        case audio
        case speakersInternal = "speaker_id_map"
        case numberOfSpeakersInternal = "num_speakers"
    }

    public let dataset: String?
    public let piperVersion: String
    public let language: Language
    public let audio: Audio
    private let speakersInternal: [String: Int]?
    public var speakers: [String: Int] {
        speakersInternal ?? [:]
    }
    private let numberOfSpeakersInternal: Int?
    public var numberOfSpeakers: Int {
        numberOfSpeakersInternal ?? 1
    }

    public var name: String {
        return dataset ?? "Unknown"
    }

    public enum Error: Swift.Error {
        case nilFileURL
    }

    public static func create(from fileURL: URL?) throws -> ModelInfo {
        guard let fileURL else {
            throw Error.nilFileURL
        }
        let data = try Data(contentsOf: fileURL, options: .mappedIfSafe)
        let jsonDecoder = JSONDecoder()
        return try jsonDecoder.decode(ModelInfo.self, from: data)
    }

    public static var installed: ModelInfo? {
#if os(Linux)
        return nil
#else
        if FileManager.default.isInstalled {
            let modelInfoJson = FileManager.Constants.jsonModelURL
            return try? create(from: modelInfoJson)
        }
        return nil
#endif
    }

    public static var installedModels: [ModelInfo] {
#if os(Linux)
        return []
#else
        FileManager.ModelPaths.installedModels.compactMap { path in
            path.info
        }
#endif
    }

#if os(Linux)
    public var installedPath: URL? { nil }
#else
    public var installedPath: FileManager.ModelPaths? {
        return FileManager.ModelPaths.installedModels.first { paths in
            (paths.info) == self
        }
    }
#endif

    public static let separator = ">0<"
    public var voiceId: String {
        let components = [
            name,
            audio.quality,
            "\(audio.sampleRate)",
            "\(language.code)",
            "\(numberOfSpeakers)"
        ]
        return components.joined(separator: Self.separator)
    }

    public static func installedModelInfo(for voiceId: String) -> ModelInfo? {
        let components = voiceId.split(separator: Self.separator)
        guard components.count == 5 else {
            return nil
        }

        let name = String(components[0])
        let quality = String(components[1])
        let languageCode = String(components[3])

        let numberOfSpeakersString = String(components[4]).components(separatedBy: Constants.speakerIdSeparator).first
        return installedModels.first { model in
            return model.name == name &&
            model.language.code == languageCode &&
            numberOfSpeakersString == "\(model.numberOfSpeakers)" &&
            quality == model.audio.quality
        }
    }
}

extension ModelInfo: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(name)
        hasher.combine(piperVersion)
        hasher.combine(language)
        hasher.combine(audio)
        hasher.combine(speakers)
        hasher.combine(numberOfSpeakers)
    }
}

extension ModelInfo: Equatable {
    static public func == (lhs: ModelInfo, rhs: ModelInfo) -> Bool {
        lhs.name == rhs.name
        && lhs.piperVersion == rhs.piperVersion
        && lhs.language == rhs.language
        && lhs.audio == rhs.audio
        && lhs.speakers == rhs.speakers
        && lhs.numberOfSpeakers == rhs.numberOfSpeakers
    }
}
