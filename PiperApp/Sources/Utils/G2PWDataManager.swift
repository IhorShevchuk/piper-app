// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils
#if canImport(UIKit)
import UIKit
#endif

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

    public static func ensureInstalled() throws {
        if isInstalled { return }
        guard copyFromAssetCatalog() else {
            throw Error.copyFailed
        }
    }

    @discardableResult
    public static func copyFromAssetCatalog() -> Bool {
        guard let folder = folderURL else { return false }
        let fileManager = FileManager.default
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.none])
        } catch {
            return false
        }

        var allCopied = true
        for file in FileManager.Constants.g2pwRequiredFiles {
            let assetName = (file as NSString).deletingPathExtension
            let dest = folder.appendingPathComponent(file)
            if fileManager.fileExists(atPath: dest.path) { continue }

            guard let dataAsset = NSDataAsset(name: assetName, bundle: Bundle.main) else {
                if let fallback = NSDataAsset(name: assetName) {
                    do {
                        try fallback.data.write(to: dest, options: .atomic)
                        try fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: dest.path)
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
                try fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: dest.path)
            } catch {
                allCopied = false
            }
        }

        return allCopied && isInstalled
    }

    public static func copyToModelFolder(_ modelFolder: URL) throws {
        guard let g2pwFolder = folderURL, isInstalled else { return }
        let fm = FileManager.default
        for file in FileManager.Constants.g2pwRequiredFiles {
            let src = g2pwFolder.appendingPathComponent(file)
            let dest = modelFolder.appendingPathComponent(file)
            if fileManager.fileExists(atPath: dest.path) { continue }
            try? fileManager.copyItem(at: src, to: dest)
            try? fileManager.setAttributes([.protectionKey: FileProtectionType.none], ofItemAtPath: dest.path)
        }
    }
}
