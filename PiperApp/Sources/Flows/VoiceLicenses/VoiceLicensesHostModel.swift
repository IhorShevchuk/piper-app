// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import Combine
import PiperAppUtils

class VoiceLicensesHostModel: @unchecked Sendable, ObservableObject {
    @Published var viewModel: VoiceLicensesViewModel
    let loader: VoiceLoader

    init(loader: VoiceLoader = AppManager.shared.loader) {
        viewModel = VoiceLicensesViewModel()
        self.loader = loader
        loadVoices()
    }

    /// Loads the catalog only when this screen is opened. A failure is
    /// reported through `showError` and leaves the screen in its empty
    /// state - it never propagates to the About screen that links here.
    func loadVoices() {
        Task {
            await MainActor.run {
                self.viewModel.showLoadingIndicator = true
                self.viewModel.showError = false
            }

            do {
                let voices = try await loader.loadVoices()
                let sortedVoices = voices.sorted { lhs, rhs in
                    if lhs.name != rhs.name {
                        return lhs.name < rhs.name
                    }
                    if lhs.quality != rhs.quality {
                        return lhs.quality < rhs.quality
                    }
                    return lhs.key < rhs.key
                }
                await MainActor.run {
                    self.viewModel.voices = sortedVoices
                }
            } catch {
                Log.error("Failed to load voices for licenses: \(error)")
                await MainActor.run {
                    self.viewModel.showError = true
                }
            }

            await MainActor.run {
                self.viewModel.showLoadingIndicator = false
            }
        }
    }
}
