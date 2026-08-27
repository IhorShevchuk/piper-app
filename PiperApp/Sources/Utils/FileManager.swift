// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

extension FileManager {
    enum InstallError: Swift.Error {
        case invalidSourceFiles
        case invalidDestinationURLs
        case cantParseModelInfo
    }

    func install(paths: ModelPaths?) throws {
        guard let paths else {
            throw InstallError.invalidSourceFiles
        }

        guard let destination = ModelPaths.installNew else {
            throw InstallError.invalidDestinationURLs
        }

        do {
            if let installedPath = paths.info?.installedPath {
                try uninstall(paths: installedPath)
            }
        } catch {
            Log.debug("Error happened while uninstalling. Error: \(error)")
        }

        let fileManager = FileManager.default
        try fileManager.createModelPathsFolder(paths: destination)
        try fileManager.copyItem(at: paths.json, to: destination.json)
        try fileManager.markFileAsUnprotected(at: destination.json)
        try fileManager.copyItem(at: paths.model, to: destination.model)
        try fileManager.markFileAsUnprotected(at: destination.model)

        // For Chinese pinyin voices, also copy shared g2pw Phase 1 dicts into voice folder
        // so Piper can find them via dataDir/g2pwModelDir (offline synthesis)
        if let info = paths.info, info.language.code.lowercased().hasPrefix("zh") {
            if let g2pwFolder = FileManager.Constants.g2pwFolderURL,
               FileManager.Constants.g2pwFileExists(),
               let modelFolder = destination.modelFolder {
                for file in FileManager.Constants.g2pwRequiredFiles {
                    let src = g2pwFolder.appendingPathComponent(file)
                    let dest = modelFolder.appendingPathComponent(file)
                    if fileManager.fileExists(atPath: dest.path) { continue }
                    try? fileManager.copyItem(at: src, to: dest)
                    try? fileManager.markFileAsUnprotected(at: dest)
                }
            }
        }
        var installedModels = FileManager.ModelPaths.installedModels
        installedModels.append(destination)
        FileManager.ModelPaths.installedModels = installedModels
    }

    func uninstall(paths: ModelPaths?) throws {

        guard let installed = paths else {
            throw InstallError.invalidDestinationURLs
        }

        var installedModels = FileManager.ModelPaths.installedModels
        installedModels.removeAll(where: { path in
            path == paths
        })
        FileManager.ModelPaths.installedModels = installedModels
        let fileManager = FileManager.default
        try fileManager.removeItem(at: installed.model)
        try fileManager.removeItem(at: installed.json)

        if let modelFolder = installed.modelFolder {
            try fileManager.removeItem(at: modelFolder)
        }
    }

    enum Error: Swift.Error {
        case nilTemporaryDirectory
    }

    static var tempFolderInDocumentDirectory: URL? {
        let temporaryDirectoryURL = URL(filePath: NSTemporaryDirectory())
        return temporaryDirectoryURL.appending(component: "temporary_folder")
    }

    func createTemporaryDirectoryIfNeeded() throws {
        guard let temporaryDirectoryURL = FileManager.tempFolderInDocumentDirectory else {
            throw Error.nilTemporaryDirectory
        }
        if !FileManager.default.fileExists(atPath: temporaryDirectoryURL.path) {
            try FileManager.default.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true, attributes:
                                                        [.protectionKey: FileProtectionType.none]
            )
        }
    }

    func cleanTemporaryDirectory() throws {
        guard let temporaryDirectoryURL = FileManager.tempFolderInDocumentDirectory else {
            throw Error.nilTemporaryDirectory
        }
        let fileManager = FileManager.default
        try fileManager.removeItem(at: temporaryDirectoryURL)
    }

    func moveToTemporaryDirectory(fileURL: URL) throws -> URL {
        guard let temporaryDirectoryURL = FileManager.tempFolderInDocumentDirectory else {
            throw Error.nilTemporaryDirectory
        }
        try createTemporaryDirectoryIfNeeded()
        let movedFileURL = temporaryDirectoryURL.appendingPathComponent(UUID().uuidString)
        try self.copyItem(at: fileURL, to: movedFileURL)
        return movedFileURL
    }

    private func markFileAsUnprotected(at url: URL) throws {
        try setAttributes(
            [.protectionKey: FileProtectionType.none],
            ofItemAtPath: url.path
        )
    }

    func markModelsFolderAsUnprotected() {
        guard let modelsFolderURL = FileManager.Constants.modelsFolderURL else {
            return
        }

        do {
            try markFileAsUnprotected(at: modelsFolderURL)
        } catch {
            Log.error("Failed to mark models folder as unprotected: \(error)")
        }

        guard let enumerator = FileManager.default.enumerator(
            at: modelsFolderURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return
        }

        for case let fileURL as URL in enumerator {
            do {
                try markFileAsUnprotected(at: fileURL)
            } catch {
                Log.error("Failed to make file unprotected: \(error)")
            }
        }
    }
}

extension FileManager.ModelPaths {
    var modelTitle: String {
        guard let modelInfo = info else {
            return "Unknown"
        }

        return "\(modelInfo.name.capitalized) \(modelInfo.language.code.localizedLanguageFromCode)"
    }
}
