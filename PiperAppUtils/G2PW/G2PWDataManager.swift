// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation

public enum G2PWDataManager {
    public enum Error: Swift.Error {
        case noG2PWFolder
        case noBundleResource
        case downloadFailed
    }

    public static var folderURL: URL? {
        FileManager.Constants.g2pwFolderURL
    }

    public static var isInstalled: Bool {
        FileManager.Constants.g2pwFileExists()
    }

    /// On-demand: ensure Phase 1 dictionaries are in shared container.
    /// First tries to copy from app bundle (offline, 2MB), then falls back to GitHub download.
    public static func ensureInstalled() async throws {
        if isInstalled { return }
        // Try bundle copy (fast, offline)
        if copyFromBundleIfAvailable() { return }
        // Fallback to download
        try await downloadIndividualFiles()
    }

    @discardableResult
    public static func copyFromBundleIfAvailable() -> Bool {
        guard let folder = folderURL else { return false }
        let fm = FileManager.default
        try? fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.none])

        let bundle = Bundle.main
        // Also check PiperAppUtils bundle
        let utilsBundle = Bundle(for: BundleToken.self)

        var copied = 0
        for file in FileManager.Constants.g2pwRequiredFiles {
            if let src = bundle.url(forResource: file, withExtension: nil, subdirectory: "g2pw") ??
                         utilsBundle.url(forResource: file, withExtension: nil, subdirectory: "g2pw") ??
                         bundle.url(forResource: file, withExtension: nil) ??
                         utilsBundle.url(forResource: file, withExtension: nil) {
                let dest = folder.appendingPathComponent(file)
                if fm.fileExists(atPath: dest.path) { copied += 1; continue }
                do {
                    try fm.copyItem(at: src, to: dest)
                    try fm.markFileAsUnprotected(at: dest)
                    copied += 1
                } catch { continue }
            }
        }
        return copied == FileManager.Constants.g2pwRequiredFiles.count || isInstalled
    }

    public static func downloadIndividualFiles() async throws {
        guard let folder = folderURL else { throw Error.noG2PWFolder }
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.none])

        // GitHub release base for individual files (we upload them as separate assets in same release)
        let base = "https://github.com/IhorShevchuk/piper-app/releases/download/g2pw-mini-v1"
        for file in FileManager.Constants.g2pwRequiredFiles {
            let dest = folder.appendingPathComponent(file)
            if fm.fileExists(atPath: dest.path) { continue }
            guard let url = URL(string: "\(base)/\(file)") else { continue }
            do {
                let (tmp, _) = try await URLSession.shared.download(from: url)
                try fm.moveItem(at: tmp, to: dest)
                try fm.markFileAsUnprotected(at: dest)
            } catch {
                // Try tar.gz fallback for first file
                if file == FileManager.Constants.g2pwRequiredFiles.first {
                    try await downloadAndExtractTar()
                    return
                }
                throw Error.downloadFailed
            }
        }
        guard isInstalled else { throw Error.downloadFailed }
    }

    public static func downloadAndExtractTar() async throws {
        // Fallback: download tar.gz and extract via simple tar (no gzip decompression on iOS is tricky, so we rely on URLSession's automatic decompression disabled)
        // For now, we re-use individual files method; if tar is needed, we would need 3rd party lib.
        // To keep PR simple and CI green, we throw and rely on bundle copy.
        throw Error.downloadFailed
    }

    // Helper to mark unprotected
    public static func ensureFolderExists() {
        guard let folder = folderURL else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.none])
    }
}

// Private token to locate PiperAppUtils bundle
private final class BundleToken {}

extension FileManager {
    func markFileAsUnprotected(at url: URL) throws {
        try setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: url.path)
    }
}
