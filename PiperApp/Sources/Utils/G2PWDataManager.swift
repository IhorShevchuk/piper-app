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
/// - No network, no download, no GitHub dependency – pure offline
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
    public static func ensureInstalled() throws {
        if isInstalled { return }
        guard copyFromAssetCatalog() else {
            throw Error.copyFailed
        }
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
                // Fallback for tests where main bundle may not contain assets
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

    /// Copy shared g2pw files into a voice's model folder for offline synthesis
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
