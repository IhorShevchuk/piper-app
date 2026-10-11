// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import CryptoKit
import Foundation
import PiperAppUtils

/// Whether the catalog's build of an installed voice differs from
/// the files on disk.
enum VoiceUpdateStatus: Equatable {
    case upToDate
    case updateAvailable
    /// Not enough evidence either way (unreadable files, a catalog
    /// without digests): the UI stays as it is today, no indicator.
    case unknown
}

/// Update detection compares the catalog's per-file MD5 digests
/// with the installed files' actual contents. The catalog carries
/// no version number, and none is needed: a retrained model changes
/// the model digest, a config-only fix changes the config digest.
/// Existing installs need no migration, because nothing about the
/// installed voice is stored - its files are hashed as they are.
enum VoiceUpdateChecker {

    /// Digests and size of one installed voice's files, gathered by
    /// the caller so the comparison itself stays pure and testable.
    struct InstalledFiles: Equatable {
        var modelSize: Int?
        var modelMD5: String?
        var configMD5: String?
    }

    static func status(voice: Voice, installed: InstalledFiles) -> VoiceUpdateStatus {
        status(catalogModelMD5: voice.catalogModelFile?.md5Digest,
               catalogModelSize: voice.catalogModelFile?.size_bytes,
               catalogConfigMD5: voice.catalogJSONFile?.md5Digest,
               variantModelSize: voice.compactVariant?.sizeBytes,
               installed: installed)
    }

    static func status(catalogModelMD5: String?,
                       catalogModelSize: Int?,
                       catalogConfigMD5: String?,
                       variantModelSize: Int?,
                       installed: InstalledFiles) -> VoiceUpdateStatus {
        // A changed config alone (e.g. a dataset fix) is an update.
        if digestsDiffer(catalogConfigMD5, installed.configMD5) {
            return .updateAvailable
        }
        // The installed model is exactly the catalog's standard build.
        if digestsMatch(catalogModelMD5, installed.modelMD5) {
            return .upToDate
        }
        // The installed model is not the standard build but has
        // exactly the current Compact build's size: it is that build
        // (the catalog serves no digest for variants to check more).
        if digestsDiffer(catalogModelMD5, installed.modelMD5),
           let variantModelSize, installed.modelSize == variantModelSize {
            return .upToDate
        }
        // The model digest is known on both sides and differs.
        if digestsDiffer(catalogModelMD5, installed.modelMD5) {
            return .updateAvailable
        }
        // Without usable digests, sizes can only prove a difference:
        // matching sizes might still hide rebuilt weights.
        if let catalogModelSize, let modelSize = installed.modelSize,
           modelSize != catalogModelSize, modelSize != variantModelSize {
            return .updateAvailable
        }
        return .unknown
    }

    /// Keys of the catalog voices whose installed copy is stale.
    static func updateAvailableKeys(
        voices: [Voice],
        installed: [FileManager.ModelPaths],
        filesProvider: (FileManager.ModelPaths) -> InstalledFiles
    ) -> Set<String> {
        var result = Set<String>()
        for voice in voices {
            guard let paths = VoiceItemHostModel.installedPaths(for: voice, in: installed) else {
                continue
            }
            if status(voice: voice, installed: filesProvider(paths)) == .updateAvailable {
                result.insert(voice.key)
            }
        }
        return result
    }

    private static func digestsMatch(_ catalog: String?, _ installed: String?) -> Bool {
        guard let catalog, let installed else {
            return false
        }
        return catalog.caseInsensitiveCompare(installed) == .orderedSame
    }

    private static func digestsDiffer(_ catalog: String?, _ installed: String?) -> Bool {
        guard let catalog, let installed else {
            return false
        }
        return catalog.caseInsensitiveCompare(installed) != .orderedSame
    }

    /// MD5 of a file's contents as lowercase hex (the catalog's
    /// digest format), read in chunks so large models never load
    /// into memory at once. Nil when the file cannot be read.
    static func md5Digest(ofFileAt url: URL) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer {
            try? handle.close()
        }
        var hasher = Insecure.MD5()
        do {
            while let chunk = try handle.read(upToCount: 1 << 20), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
        } catch {
            return nil
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
