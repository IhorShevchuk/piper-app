// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

/// The voice model format used for new downloads, chosen in Settings
/// and persisted in UserDefaults. Downloads read `current` when
/// they start; installed voices keep the format they came with.
enum ModelFormat: String, CaseIterable {
    case standard
    case compact

    static let userDefaultsKey = "model_format"

    static var current: ModelFormat {
        let rawValue = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        return ModelFormat(rawValue: rawValue) ?? .standard
    }
}
