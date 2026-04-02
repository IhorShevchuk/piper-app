// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import Combine
import PiperAppUtils

class ImportVoiceHostModel: @unchecked Sendable, ObservableObject {
    @Published var viewModel: ImportVoiceViewModel
    weak var delegate: ModelChangeDelegate?
    let piper: PiperManager
    
    init(piper: PiperManager,
         delegate: ModelChangeDelegate?) {
        self.piper = piper
        viewModel = ImportVoiceViewModel()
        self.delegate = delegate
    }
    
    func select(model: URL?) {
        guard let model else {
            Log.error("Failed to find model file")
            return
        }
        if !model.startAccessingSecurityScopedResource() {
            Log.error("Failed to access model file")
            return
        }
        defer {
            model.stopAccessingSecurityScopedResource()
            modelDidChange()
        }
        
        if FileManager.default.fileExists(atPath: model.path) {
            viewModel.selectedModelURL = model
        }
    }
    
    func select(json: URL?) {
        guard let json else {
            Log.error("Failed to find json file")
            return
        }
        if !json.startAccessingSecurityScopedResource() {
            Log.error("Failed to access json file")
            return
        }
        defer {
            json.stopAccessingSecurityScopedResource()
            modelDidChange()
        }
        
        // TODO: handle and display invalid JSON errors
        
        if FileManager.default.fileExists(atPath: json.path) {
            viewModel.selectedJSONURL = json
        }
    }
    
    func install() {
        guard let paths = FileManager.ModelPaths(model: viewModel.selectedModelURL,
                                                 json: viewModel.selectedJSONURL) else {
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
            self.delegate?.modelDidChange()
            await MainActor.run { [weak self] in
                self?.viewModel.onDismiss?()
            }
        }
    }
    
    func modelDidChange() {
        Task { [weak self] in
            guard let self else { return }
            await MainActor.run { [weak self] in
                guard let self else { return }
                self.objectWillChange.send()
            }
        }
    }
}
