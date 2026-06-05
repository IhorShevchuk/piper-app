// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import AudioToolbox
import PiperAppUtils

protocol PiperMessageChannelDelegate: AnyObject {
    var isSyntehizerRunning: Bool { get }
}

class PiperMessageChannel: AUMessageChannel {
    weak var delegate: PiperMessageChannelDelegate?
    init(delegate: PiperMessageChannelDelegate? = nil) {
        self.delegate = delegate
    }

    func callAudioUnit(_ message: [AnyHashable: Any]) -> [AnyHashable: Any] {
        guard let delegate else {
            return [:]
        }

        if message[MessageChannelKeys.kIsSyntehizerRunning] != nil {
            return [MessageChannelKeys.kIsSyntehizerRunning: delegate.isSyntehizerRunning]
        }

        return [:]
    }

    var callHostBlock: CallHostBlock?
}
