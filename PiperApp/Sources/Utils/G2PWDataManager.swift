// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils
#if canImport(UIKit)
import UIKit
#endif

/// Option 5: xcassets compressed data assets (300K IPA, lazy-loaded, offline, no server)
/// - Files are stored as NSDataAsset in PiperApp/Resources/G2PW.xcassets
/// - IPA hit is ~300K compressed (vs 1.9M raw), RAM stays lean (loaded only on first zh voice)
/// - Once copied to App Group `g2pw/`, all zh voices share one cache and synthesis works offline
/// - No network, no download failures, no GitHub dependency
public enum G2PWDataManager {
    public enum Error: Swift.Error {
        case noG2PWFolder
        case noBundleAsset
        case copyFailed
    }

    public static var folderURL: URL? {
        FileManager.Constants.g2pwFolderURL
    }

    public static var isInstalled: Bool {
        FileManager.Constants.g2pwFileExists()
    }

    /// Ensure Phase 1 dictionaries are present, copying from xcassets if needed.
    public static func ensureInstalled() async throws {
        if isInstalled { return }
        // Primary: copy from xcassets (offline, 300K compressed, no network)
        if copyFromAssetCatalog() { return }
        // Fallback: try GitHub download (should rarely happen, kept for safety)
        try await downloadIndividualFiles()
    }

    /// Copy from xcassets NSDataAsset to shared App Group folder
    @discardableResult
    public static func copyFromAssetCatalog() -> Bool {
        guard let folder = folderURL else { return false }
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.none])
        } catch {
            return false
        }

        var allCopied = true
        for file in FileManager.Constants.g2pwRequiredFiles {
            let assetName = (file as NSString).deletingPathExtension // "MONOPHONIC_CHARS"
            let dest = folder.appendingPathComponent(file)
            if fm.fileExists(atPath: dest.path) { continue }

            // NSDataAsset loads compressed data from xcassets, decompresses lazily on first access
            guard let dataAsset = NSDataAsset(name: assetName, bundle: Bundle.main) else {
                // Try without bundle (main bundle fallback for tests)
                if let fallback = NSDataAsset(name: assetName) {
                    do {
                        try fallback.data.write(to: dest, options: .atomic)
                        try fm.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: dest.path)
                        continue
                    } catch {
                        allCopied = false
                        continue
                    }
                }
                allCopied = false
                continue
            }

            do {
                try dataAsset.data.write(to: dest, options: .atomic)
                try fm.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: dest.path)
            } catch {
                allCopied = false
            }
        }

        return allCopied && isInstalled
    }

    public static func downloadIndividualFiles() async throws {
        guard let folder = folderURL else { throw Error.noG2PWFolder }
        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.none])

        // Fallback to GitHub release if xcassets not available (e.g., tests)
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
                throw Error.copyFailed
            }
        }
        guard isInstalled else { throw Error.copyFailed }
    }

    /// Copy shared g2pw files into a voice's model folder so legacy Piper init can find them
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
