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
/// `Samples` data asset. Resolution order: the voice's exact language
/// code (`es_MX`), a sample keyed by the bare language family (`de`),
/// then any sample in the same language family (`es_MX` -> `es_ES`).
/// A sample recorded for another region still demos the voice in its
/// own language, unlike the English default text.
enum DemoText {
    static let defaultText = "A rainbow is a meteorological phenomenon that is caused by reflection, refraction and dispersion of light in water droplets resulting in a spectrum of light appearing in the sky."

    static func text(for language: PiperAppUtils.Language) -> String? {
        guard let sampleJSONData = NSDataAsset(name: "Samples")?.data else {
            return nil
        }

        do {
            let decoder = JSONDecoder()
            let samples = try decoder.decode([String: String].self, from: sampleJSONData)
            return sampleText(in: samples, for: language)
        } catch {
            Log.error("Failed to decode samples: \(error)")
            return nil
        }
    }

    static func sampleText(in samples: [String: String], for language: PiperAppUtils.Language) -> String? {
        if let exact = samples[language.code] {
            return exact
        }
        if let family = samples[language.family] {
            return family
        }
        // Sorted so the choice is deterministic when a language has
        // samples for several regions (e.g. `pt_BR` before `pt_PT`).
        let regionalKey = samples.keys.sorted().first { family(ofSampleKey: $0) == language.family.lowercased() }
        return regionalKey.flatMap { samples[$0] }
    }

    private static func family(ofSampleKey key: String) -> String {
        key.split(whereSeparator: { $0 == "_" || $0 == "-" })
            .first
            .map { $0.lowercased() } ?? key.lowercased()
    }
}
