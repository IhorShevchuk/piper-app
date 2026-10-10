// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

/// Training-data provenance of a catalog voice, from its MODEL_CARD.
///
/// Deliberately named `training_data`, not `dataset`: the `dataset` field of a
/// model's .onnx.json is the voice name (`ModelInfo.name`) used for
/// installed-voice matching, and must not be overloaded.
/// Every field is optional, so a partially-filled `training_data` object in a
/// future catalog can never fail decoding of the whole voice.
struct TrainingData: Decodable {
    let url: String?
    let license: String?
    let licenseRaw: String?

    enum CodingKeys: String, CodingKey {
        case url
        case license
        case licenseRaw = "license_raw"
    }
}

extension TrainingData: Equatable {
    static func == (lhs: TrainingData, rhs: TrainingData) -> Bool {
        lhs.url == rhs.url &&
        lhs.license == rhs.license &&
        lhs.licenseRaw == rhs.licenseRaw
    }
}

extension TrainingData: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(license)
        hasher.combine(licenseRaw)
    }
}
