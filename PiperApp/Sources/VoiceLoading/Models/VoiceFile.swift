// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

struct VoiceFile: Decodable {
    let size_bytes: Int
    /// Content digest of the file in the catalog. Optional so catalog
    /// entries written before digests were served still decode. Kept
    /// out of Equatable and Hashable on purpose: a voice's identity
    /// stays on its original fields (the same rule as `variants` and
    /// the license fields); the digest only feeds update detection.
    let md5Digest: String?

    enum CodingKeys: String, CodingKey {
        case size_bytes
        case md5Digest = "md5_digest"
    }
}

extension VoiceFile: Equatable {
    static func == (lhs: VoiceFile, rhs: VoiceFile) -> Bool {
        lhs.size_bytes == rhs.size_bytes
    }
}

extension VoiceFile: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(size_bytes)
    }
}
