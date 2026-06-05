// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils
import CoreTransferable
import UniformTypeIdentifiers

protocol VoiceFileSyntehesizer {
    func syntehesize(text: String, to file: String) async throws
    var fileName: String { get }
}

class VoiceFileTransferable {
    private let text: String
    private let syntehesizer: VoiceFileSyntehesizer
    private let filePath: String
    init(text: String, syntehesizer: VoiceFileSyntehesizer) {
        self.text = text
        self.syntehesizer = syntehesizer
        self.filePath = VoiceFileTransferable.createFilePath(fileName: syntehesizer.fileName)
    }

    func syntehesize() async throws {
        try await syntehesizer.syntehesize(text: text, to: self.filePath)
    }

    private static func createFilePath(fileName: String) -> String {
        do {
            try FileManager.default.createTemporaryDirectoryIfNeeded()
            if let temporaryDirectory = FileManager.tempFolderInDocumentDirectory {
                let path = temporaryDirectory.appendingPathComponent(fileName).path
                return "\(path).wav"
            }
        } catch {
            Log.error("Can't create file path for voice file")
        }
        return "\(NSTemporaryDirectory())\(fileName).wav"
    }
}

extension VoiceFileTransferable: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .wav) { voiceFile in
            if !FileManager.default.fileExists(atPath: voiceFile.filePath) {
                try await voiceFile.syntehesize()
            }
            return SentTransferredFile(URL(filePath: voiceFile.filePath))
        }
    }

    public static func exportedContentTypes(visibility: TransferRepresentationVisibility = .all) -> [UTType] {
        return [.wav]
    }

    var suggestedFilename: String? {
        return syntehesizer.fileName
    }
}
