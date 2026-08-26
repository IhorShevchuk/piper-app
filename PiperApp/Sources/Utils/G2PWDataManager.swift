// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

/// Pure on-demand G2PW Phase 1 manager (2MB lean)
/// - Voice install already requires network, so no extra failure mode
/// - Once cached in App Group `g2pw/`, synthesis works offline
/// - Keeps IPA at 0 extra, RAM tiny (no 152M onnx), covers 95% monophonic chars for chaowen/xiao_ya
public enum G2PWDataManager {
    public enum Error: Swift.Error {
        case noG2PWFolder
        case downloadFailed
    }

    public static var folderURL: URL? {
        FileManager.Constants.g2pwFolderURL
    }

    public static var isInstalled: Bool {
        FileManager.Constants.g2pwFileExists()
    }

    /// Ensure Phase 1 dictionaries are present, downloading if needed.
    public static func ensureInstalled() async throws {
        if isInstalled { return }
        try await downloadIndividualFiles()
    }

    public static func downloadIndividualFiles() async throws {
        guard let folder = folderURL else { throw Error.noG2PWFolder }
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.none])

        // 301K compressed tar contains 3 files, but we download individually for simplicity (no gzip/tar handling on iOS)
        let base = "https://github.com/IhorShevchuk/piper-app/releases/download/g2pw-mini-v1"
        for file in FileManager.Constants.g2pwRequiredFiles {
            let dest = folder.appendingPathComponent(file)
            if fm.fileExists(atPath: dest.path) { continue }
            guard let url = URL(string: "\(base)/\(file)") else { continue }
            do {
                let (tmp, _) = try await URLSession.shared.download(from: url)
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }
                try fm.moveItem(at: tmp, to: dest)
                try FileManager.default.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: dest.path)
            } catch {
                throw Error.downloadFailed
            }
        }
        guard isInstalled else { throw Error.downloadFailed }
    }

    /// Copy shared g2pw files into a voice's model folder so legacy Piper init can find them
    /// This keeps PiperTTS unchanged if needed, and ensures offline synthesis works
    public static func copyToModelFolder(_ modelFolder: URL) throws {
        guard let g2pwFolder = folderURL, isInstalled else { return }
        let fm = FileManager.default
        for file in FileManager.Constants.g2pwRequiredFiles {
            let src = g2pwFolder.appendingPathComponent(file)
            let dest = modelFolder.appendingPathComponent(file)
            if fm.fileExists(atPath: dest.path) { continue }
            try? fm.copyItem(at: src, to: dest)
            try? fm.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: dest.path)
        }
    }
}
