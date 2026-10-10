// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Demo text spoken when previewing a voice, from the bundled
/// `Samples` data asset, keyed by language code with a fallback to
/// the language family (e.g. `de_DE` -> `de`).
enum DemoText {
    static let defaultText = "A rainbow is a meteorological phenomenon that is caused by reflection, refraction and dispersion of light in water droplets resulting in a spectrum of light appearing in the sky."

    static func text(for language: PiperAppUtils.Language) -> String? {
        guard let sampleJSONData = NSDataAsset(name: "Samples")?.data else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let samples = try decoder.decode([String: String].self, from: sampleJSONData)
            return samples[language.code] ?? samples[language.family]
        } catch {
            Log.error("Failed to decode samples: \(error)")
            return nil
        }
    }
}
