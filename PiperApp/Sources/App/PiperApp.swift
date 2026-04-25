// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import SwiftUI

@main
struct PiperApp: App {
    
#if os(iOS)
    @UIApplicationDelegateAdaptor private var appDelegate: ApplicationDelegate
#elseif os(macOS)
    @NSApplicationDelegateAdaptor private var appDelegate: ApplicationDelegate
#endif
    
    @ViewBuilder
    var mainContent: some View {
        MainView(hostModel: mainModel)
    }
    
    let mainModel = MainHostModel(piper: AppManager.shared.piper)
    var body: some Scene {
        #if os(macOS)
        Window("piper_app_name".localized, id: "main") {
            mainContent
                .frame(minWidth: 400, minHeight: 300)
                .frame(idealWidth: 400, idealHeight: 300)
                .frame(maxWidth: 800, maxHeight: 800)
        }
        .windowResizability(.contentSize)
        #elseif os(iOS)
        WindowGroup {
            mainContent
        }
        #endif
    }
}
