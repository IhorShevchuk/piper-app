// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import Combine
import PiperAppUtils
import AVFoundation

class AboutAppHostModel: @unchecked Sendable, ObservableObject {
    @Published var viewModel: AboutAppViewModel
    let piper: PiperManager

    @MainActor
    init(piper: PiperManager) {
        viewModel = AboutAppViewModel(appVersion: Bundle.main.applicationVersion,
                                      connectionStatus: piper.audioUnit.status)
        self.piper = piper
    }

    func connect() {
        Task { [weak self] in
            guard let self else { return }
            await self.piper.audioUnit.connect()
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.viewModel.connectionStatus = self.piper.audioUnit.status
            }
        }
    }
}
