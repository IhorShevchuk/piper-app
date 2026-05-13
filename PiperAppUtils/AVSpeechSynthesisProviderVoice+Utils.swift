// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import AVFAudio

extension AVSpeechSynthesisProviderVoice {
    public static var supportedVoices: [AVSpeechSynthesisProviderVoice] {
        
        let installedModels = ModelInfo.installedModels
        if installedModels.isEmpty {
            return []
        }
        
        let result = installedModels.flatMap { installedModel in
            let languageCode = "\(installedModel.language.family)-\(installedModel.language.region)"
            
            if installedModel.numberOfSpeakers <= 1 || installedModel.speakers.isEmpty {
                return [
                    AVSpeechSynthesisProviderVoice(name: installedModel.name.capitalized,
                                                   identifier: installedModel.voiceId,
                                                   primaryLanguages: [languageCode],
                                                   supportedLanguages: [languageCode]
                                                  )
                ]
            }
            
            return installedModel.speakers.map { (name, id) in
                AVSpeechSynthesisProviderVoice(name: name.capitalized,
                                               identifier: "\(installedModel.voiceId)\(Constants.speakerIdSeparator)\(id)",
                                               primaryLanguages: [languageCode],
                                               supportedLanguages: [languageCode]
                )
            }
        }
        
        return result
    }
}
