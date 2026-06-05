// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

extension Array where Element == URL {
    var model: Element? {
        first(with: Constants.modelExtensiom)
    }

    var json: Element? {
        first(with: Constants.jsonModelExtension)
    }

    private func first(with pathExtension: String) -> Element? {
        first { fileURL in
            fileURL.pathExtension.lowercased() == pathExtension
        }
    }
}

extension Array where Element == String {
    var model: Element? {
        first(with: Constants.modelExtensiom)
    }

    var json: Element? {
        first(with: Constants.jsonModelExtension)
    }

    private func first(with pathExtension: String) -> Element? {
        first { file in
            file.hasSuffix(pathExtension)
        }
    }
}
