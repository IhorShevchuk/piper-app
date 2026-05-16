// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import AVFoundation
import PiperAppUtils

extension AVSpeechSynthesisProviderRequest {
    convenience init?(simpeText: String, piperId: String) {
        let voice = AVSpeechSynthesisProviderVoice.supportedVoices.first(where: { voice in
            return voice.identifier.hasSuffix(piperId)
        }) ?? AVSpeechSynthesisProviderVoice.supportedVoices.first
        
        guard let voice else {
            Log.error("No supported voices. Can't play text.")
            return nil
        }
        
        self.init(
          ssmlRepresentation: "<speak>\(simpeText)</speak>",
          voice: voice
        )
    }
}
