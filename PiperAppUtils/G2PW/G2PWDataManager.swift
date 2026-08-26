// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

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

    /// Pure on-demand: download Phase 1 dictionaries on first Chinese voice install.
    /// Voice install already requires network, so no extra failure mode.
    /// Keeps IPA at 0 extra, RAM tiny (no 152M onnx).
    public static func ensureInstalled() async throws {
        if isInstalled { return }
        try await downloadIndividualFiles()
    }

    public static func downloadIndividualFiles() async throws {
        guard let folder = folderURL else { throw Error.noG2PWFolder }
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.none])

        let base = "https://github.com/IhorShevchuk/piper-app/releases/download/g2pw-mini-v1"
        for file in FileManager.Constants.g2pwRequiredFiles {
            let dest = folder.appendingPathComponent(file)
            if fm.fileExists(atPath: dest.path) { continue }
            guard let url = URL(string: "\(base)/\(file)") else { continue }
            do {
                let (tmp, _) = try await URLSession.shared.download(from: url)
                // Move atomically, replace if exists
                if fm.fileExists(atPath: dest.path) {
                    try? fm.removeItem(at: dest)
                }
                try fm.moveItem(at: tmp, to: dest)
                try fm.markFileAsUnprotected(at: dest)
            } catch {
                throw Error.downloadFailed
            }
        }
        guard isInstalled else { throw Error.downloadFailed }
    }

    public static func ensureFolderExists() {
        guard let folder = folderURL else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.none])
    }
}

extension FileManager {
    func markFileAsUnprotected(at url: URL) throws {
        try setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: url.path)
    }
}
