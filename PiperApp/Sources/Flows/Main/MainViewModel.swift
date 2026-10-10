// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

struct MainViewModel {
    var installedModels: [FileManager.ModelPaths] = []
    var installedByLanguage: [InstalledLanguage] = []
    var ungroupedInstalled: [FileManager.ModelPaths] = []
    var languageCodes: [String] = []
    var catalogState: CatalogState = .loading

    struct InstalledLanguage {
        let code: String
        let models: [FileManager.ModelPaths]
    }

    enum CatalogState {
        case loading
        case loaded
        case failed
    }
}
