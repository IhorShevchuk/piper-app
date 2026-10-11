// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

class Voice: Decodable {
    let key: String
    let name: String
    let quality: String
    let language: PiperAppUtils.Language
    let files: [String: VoiceFile]
    /// Effective license shown to the user: the most restrictive of the model
    /// license and the training-data license. Optional so catalog entries
    /// written before per-voice licenses were added still decode.
    let license: String?
    let modelLicense: String?
    let trainingData: TrainingData?
    /// Alternative model builds from the catalog's `variants` field,
    /// keyed by format ("int8"). Optional so older catalog entries
    /// still decode, and deliberately excluded from Equatable and
    /// Hashable: a voice's identity stays on the original fields,
    /// whichever build ends up downloaded.
    let variants: [String: VoiceVariant]?

    struct VoiceVariant: Decodable {
        let model: String
        let sizeBytes: Int

        enum CodingKeys: String, CodingKey {
            case model
            case sizeBytes = "size_bytes"
        }
    }

    enum CodingKeys: String, CodingKey {
        case key
        case name
        case quality
        case language
        case files
        case license
        case modelLicense = "model_license"
        case trainingData = "training_data"
        case variants
    }

    /// The INT8 build of this voice, when the catalog offers one.
    var compactVariant: VoiceVariant? {
        variants?["int8"]
    }

    /// Whether downloads and sizes currently follow the Compact
    /// setting for this voice: the setting is on and a variant exists.
    private var compactSelected: Bool {
        ModelFormat.current == .compact && compactVariant != nil
    }

    private var voiceSize: Int {
        let total = files.values.reduce(into: 0) { $0 += $1.size_bytes }
        if compactSelected,
           let variant = compactVariant,
           let modelPath = Array(files.keys).model,
           let modelFile = files[modelPath] {
            return total - modelFile.size_bytes + variant.sizeBytes
        }
        return total
    }
    var voiceSizeString: String {
        ByteCountFormatter.string(fromByteCount: Int64(voiceSize), countStyle: .binary)
    }
    var modelPath: String? {
        if compactSelected, let variant = compactVariant {
            return variant.model
        }
        return Array(files.keys).model
    }
    var jsonPath: String? {
        Array(files.keys).json
    }
}

extension Voice: Equatable {
    static func == (lhs: Voice, rhs: Voice) -> Bool {
        lhs.key == rhs.key &&
        lhs.name == rhs.name &&
        lhs.quality == rhs.quality &&
        lhs.language == rhs.language &&
        lhs.files == rhs.files
    }
}

extension Voice: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(key)
        hasher.combine(name)
        hasher.combine(quality)
        hasher.combine(language)
        hasher.combine(files)
    }
}

extension Voice {
    static var unsupportedVoices: Set<String> = {
        return Set<String>([])
    }()
    var isSupported: Bool {
        return !Voice.unsupportedVoices.contains(name)
    }
}
