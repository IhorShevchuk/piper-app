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

        // MARK: - g2pw (Chinese pinyin Phase 1)

        public static var g2pwFolderName: String { "g2pw" }

        public static var g2pwFolderURL: URL? {
            return sharedFolder?.appendingPathComponent(g2pwFolderName)
        }

        public static var g2pwMiniTarURL: URL? {
            // 301K compressed, ~1.9M uncompressed – Phase 1 minimal dictionaries
            URL(string: "https://github.com/IhorShevchuk/piper-app/releases/download/g2pw-mini-v1/g2pw-mini.tar.gz")
        }

        public static var g2pwRequiredFiles: [String] {
            [
                "MONOPHONIC_CHARS.txt",
                "char_bopomofo_dict.json",
                "bopomofo_to_pinyin_wo_tune_dict.json"
            ]
        }

        public static func g2pwFileExists() -> Bool {
            guard let folder = g2pwFolderURL else { return false }
            let fm = FileManager.default
            return g2pwRequiredFiles.allSatisfy { fm.fileExists(atPath: folder.appendingPathComponent($0).path) }
        }
    }
}
