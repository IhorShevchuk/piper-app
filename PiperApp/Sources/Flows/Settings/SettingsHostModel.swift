// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import Combine
import PiperAppUtils
import AVFoundation

class SettingsHostModel: @unchecked Sendable, ObservableObject {
    @Published var viewModel: SettingsViewModel
    let piper: PiperManager
    /// Notified when a voice is imported from Settings, so the main
    /// list behind it refreshes its installed voices.
    weak var modelChangeDelegate: ModelChangeDelegate?

    @MainActor
    init(piper: PiperManager,
         modelChangeDelegate: ModelChangeDelegate? = nil) {
        viewModel = SettingsViewModel(appVersion: Bundle.main.applicationVersion,
                                      connectionStatus: piper.audioUnit.status)
        self.piper = piper
        self.modelChangeDelegate = modelChangeDelegate
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
