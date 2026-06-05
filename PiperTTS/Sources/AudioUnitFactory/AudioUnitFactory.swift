// SPDX-License-Identifier: GPL-3.0-only
// Copyright (c) 2026 Ihor Shevchuk

import CoreAudioKit
import os

public class AudioUnitFactory: NSObject, AUAudioUnitFactory {
    var auAudioUnit: AUAudioUnit?
    public func beginRequest(with context: NSExtensionContext) {

    }

    @objc
    public func createAudioUnit(with componentDescription: AudioComponentDescription) throws -> AUAudioUnit {
        auAudioUnit = try PiperTTSAudioUnit(componentDescription: componentDescription, options: [])

        guard let audioUnit = auAudioUnit as? PiperTTSAudioUnit else {
            fatalError("Failed to create pipertts")
        }

        return audioUnit
    }

}
