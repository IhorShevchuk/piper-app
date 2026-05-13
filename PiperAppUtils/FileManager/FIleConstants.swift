// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

extension FileManager {
    public enum Constants {
        private static let applicationGroupIdentifier = "group.pipertts.data"
        
        static var sharedFolder: URL? {
            return FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: Constants.applicationGroupIdentifier)
        }
        
        public static var modelURL: URL? {
            return sharedFolder?.appendingPathComponent(PiperAppUtils.Constants.modelFileNameWithExtension)
        }
        
        public static var modelsFolderURL: URL? {
            return sharedFolder?.appendingPathComponent(PiperAppUtils.Constants.modelsFolderName)
        }
        
        public static var modelsJsonURL: URL? {
            return sharedFolder?.appendingPathComponent(PiperAppUtils.Constants.modelsFolderName)
                .appendingPathComponent(PiperAppUtils.Constants.modelsJSONFileName, conformingTo: PiperAppUtils.Constants.jsonUTI)
        }
        
        public static var jsonModelURL: URL? {
            return sharedFolder?.appendingPathComponent(PiperAppUtils.Constants.modelJSONFileNameWithExtension)
        }
    }
}
