// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import Combine
import PiperAppUtils

class MainHostModel: @unchecked Sendable, ObservableObject {
    @Published var viewModel: MainViewModel
    let piper: PiperManager

    init(piper: PiperManager) {
        self.piper = piper
        viewModel = MainViewModel(installedModels: piper.installedVoices.sorted(by: { model1, model2 in
            return model1.modelTitle < model2.modelTitle
        }))
        connect()
    }

    func connect() {
        Task {
#if DEBUG
            do {
                try await Task.sleep(for: .seconds(2))
            } catch {
                Log.error("Error happened during waiting: \(error)")
            }
#endif
            await self.piper.audioUnit.connect()
        }
    }

    func selected(files: [URL]) {
        if files.count != 2 {
            Log.error("Wrong number of files selected: \(files.count)")
            return
        }

        let model = files.model
        let modelJSON = files.json

        guard let paths = FileManager.ModelPaths(model: model, json: modelJSON) else {
            Log.error("Failed to find model or model JSON file")
            return
        }

        Task { [weak self] in
            defer {
                paths.model.stopAccessingSecurityScopedResource()
                paths.json.stopAccessingSecurityScopedResource()
            }

            if paths.model.startAccessingSecurityScopedResource() != true {
                Log.error("Failed to access model")
                return
            }

            if paths.json.startAccessingSecurityScopedResource() != true {
                Log.error("Failed to access JSON")
                return
            }

            if (try? ModelInfo.create(from: paths.json)) == nil {
                Log.error("Failed to create ModelInfo from modelJSON")
                return
            }

            guard let self else {
                return
            }

            await self.piper.install(paths: paths)
            self.modelDidChange()
        }
    }
}

extension MainHostModel: ModelChangeDelegate {
    func modelDidChange() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.viewModel = MainViewModel(installedModels: piper.installedVoices.sorted(by: { model1, model2 in
                return model1.modelTitle < model2.modelTitle
            }))
        }
    }
}
