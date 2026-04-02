// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

extension PiperColors.Color {
    static var colorOfText: PiperColors.Color {
#if os(macOS)
        return .textColor
#elseif os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        return .label
#endif
    }
}
