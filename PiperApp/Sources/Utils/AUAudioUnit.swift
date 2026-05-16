// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import AudioToolbox
import AVFAudio

extension AUAudioUnit {
    enum Error: Swift.Error {
        case cantHandleSpeechRequest
    }
    func allocateRenderResourcesIfNeeded() throws {
        if !renderResourcesAllocated {
            try allocateRenderResources()
        }
    }
    
    func handleSpeechRequest(_ request: AVSpeechSynthesisProviderRequest?) throws {
        if responds(to: #selector(AVSpeechSynthesisProviderAudioUnit.synthesizeSpeechRequest(_:))) {
            perform(#selector(AVSpeechSynthesisProviderAudioUnit.synthesizeSpeechRequest(_:)), with: request)
        } else {
            throw Error.cantHandleSpeechRequest
        }
    }
}
