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
    private var voiceSize: Int {
        return files.values.reduce(into: 0) { $0 += $1.size_bytes }
    }
    var voiceSizeString: String {
        ByteCountFormatter.string(fromByteCount: Int64(voiceSize), countStyle: .binary)
    }
    var modelPath: String? {
        Array(files.keys).model
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
