// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

extension String {
    var audioComponentOSType: OSType {
        if self.count != 4 {
            Log.error("Invalid audio component length: \(self)")
            return 0
        }

        var result: OSType = 0
        for char in self.utf8 {
            result = (result << 8) + OSType(char)
        }
        return result
    }

    static func localized(_ key: String.LocalizationValue, comment: StaticString? = nil, arguments: [CVarArg] = []) -> String {

        let format = String(localized: key, comment: comment)

        if LocalizationValue(format) == key {
            if let path = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return String(localized: key, bundle: bundle)
            }
        }

        if arguments.isEmpty {
            return format
        }

        return String(format: format, arguments)
    }

    var localized: String {
        String.localized(String.LocalizationValue(self))
    }

    var localizedLanguageFromCode: String {
        if let name = Locale.current.localizedString(forIdentifier: self) {
            return name
        }
        // Fall back to the language part for invalid identifiers like ja_JA.
        let languageCode = components(separatedBy: CharacterSet(charactersIn: "_-")).first ?? self
        return Locale.current.localizedString(forLanguageCode: languageCode) ?? self
    }
}
