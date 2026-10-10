// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import Combine
import PiperAppUtils

enum DownloadEvent {
    case progress(Double)
    case finished(FileManager.ModelPaths)
}

protocol VoiceLoadListener: AnyObject {
    func progressUpdated(_ progress: Float)
}

class VoiceLoader: NSObject {
    /// In-flight downloads by catalog voice key, shared by every row:
    /// a voice downloads once and progress survives row rebuilds.
    @Published private(set) var downloadProgress: [String: Double] = [:]

    @MainActor
    func beginDownload(for key: String) -> Bool {
        guard downloadProgress[key] == nil else { return false }
        downloadProgress[key] = 0
        return true
    }

    @MainActor
    func updateDownloadProgress(_ progress: Double, for key: String) {
        guard downloadProgress[key] != nil else { return }
        downloadProgress[key] = progress
    }

    @MainActor
    func endDownload(for key: String) {
        downloadProgress[key] = nil
    }

    /// The URLSession task currently fetching a file for each voice
    /// download, so a download can be cancelled from any row.
    private var activeDownloadTasks: [String: URLSessionDownloadTask] = [:]
    private var downloadTaskKeys: [Int: String] = [:]
    /// Voices whose download was cancelled; checked when the next
    /// file's task starts, so a cancel tapped between the two files
    /// of a voice (config, then model) is not lost.
    private var cancelledDownloads: Set<String> = []

    /// Cancels the in-flight download of a voice, if any: the
    /// registry entry goes away (rows return to the download state)
    /// and the download stream throws URLError.cancelled.
    @MainActor
    func cancelDownload(for key: String) {
        cancelledDownloads.insert(key)
        endDownload(for: key)
        activeDownloadTasks[key]?.cancel()
    }

    private enum Error: Swift.Error {
        case nilURL
        case loadingFailed
        case wrongModelInfo
    }
    private enum Constants {
        static let baseURL = "https://huggingface.co/IhorShevchuk/piper1-voices-fp16-quantized/resolve/main"
        static let communitySamplesBaseURL = "https://rhasspy.github.io/piper-samples/samples"

        static var voicesURL: URL? {
            return URL(string: "\(Constants.baseURL)/voices.json")
        }
    }

    private var continuations: [Int: CheckedContinuation<URL, Swift.Error>] = [:]
    private var observations: [Int: NSKeyValueObservation] = [:]

    private lazy var operationQueue: OperationQueue = {
        OperationQueue()
    }()

    private lazy var urlSession: URLSession = {
        URLSession(configuration: .default,
                   delegate: self,
                   delegateQueue: operationQueue)
    }()

    private var cacheURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("voices-catalog.json")
    }

    func loadVoices() async throws -> [Voice] {
        guard let url = Constants.voicesURL else {
            throw Error.nilURL
        }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let allVoices = try JSONDecoder().decode([String: Voice].self, from: data)
            if let cacheURL {
                try? data.write(to: cacheURL, options: .atomic)
            }
            return Array(allVoices.values)
        } catch {
            // Offline or a broken response: use the last good catalog.
            guard let cacheURL,
                  let data = try? Data(contentsOf: cacheURL),
                  let cached = try? JSONDecoder().decode([String: Voice].self, from: data) else {
                throw error
            }
            return Array(cached.values)
        }
    }

    func sampleURL(for voice: Voice) -> URL? {
        guard let modelPath = voice.modelPath else { return nil }
        let directory = (modelPath as NSString).deletingLastPathComponent
        return URL(string: "\(Constants.baseURL)/\(directory)/sample.mp3")
    }

    /// Community sample, used when our hosted sample is missing.
    func fallbackSampleURL(for voice: Voice) -> URL? {
        let languageCode = voice.language.code
        let languageFamily = languageCode.split(separator: "_").first.map(String.init) ?? languageCode
        let path = "\(languageFamily)/\(languageCode)/\(voice.name)/\(voice.quality)/speaker_0.mp3"
        return URL(string: "\(Constants.communitySamplesBaseURL)/\(path)")
    }

    private func isPinyinVoice(_ voice: Voice, configURL: URL) -> Bool {
        if voice.language.code.lowercased().hasPrefix("zh") { return true }
        guard let data = try? Data(contentsOf: configURL) else { return false }
        guard let config = try? JSONDecoder().decode(VoiceConfig.self, from: data) else { return false }
        return config.phonemeType?.lowercased() == "pinyin"
    }

    func download(voice: Voice) -> AsyncThrowingStream<DownloadEvent, Swift.Error> {
        AsyncThrowingStream { continuation in
            Task {
                await self.performDownload(voice: voice, continuation: continuation)
            }
        }
    }

    private func performDownload(voice: Voice,
                                 continuation: AsyncThrowingStream<DownloadEvent, Swift.Error>.Continuation) async {
        var downloadedFiles: [URL] = []
        do {
            guard let modelPath = voice.modelPath else {
                throw Error.loadingFailed
            }
            guard let modelURL = URL(string: "\(Constants.baseURL)/\(modelPath)") else {
                throw Error.nilURL
            }

            let jsonLocalURL = try await downloadVoiceConfig(voice: voice, continuation: continuation)
            downloadedFiles.append(jsonLocalURL)

            // Model is large → weight 95%
            let modelLocalURL = try await self.downloadFile(
                from: modelURL,
                key: voice.key,
                weight: 0.95,
                baseProgress: 0.05,
                continuation: continuation
            )
            downloadedFiles.append(modelLocalURL)

            guard let paths = FileManager.ModelPaths(model: modelLocalURL,
                                                     json: jsonLocalURL) else {
                throw Error.loadingFailed
            }

            continuation.yield(.finished(paths))
            continuation.finish()

        } catch {
            // A failed or cancelled download must not leave
            // partial temp files behind.
            for fileURL in downloadedFiles {
                try? FileManager.default.removeItem(at: fileURL)
            }
            continuation.finish(throwing: error)
        }
        cancelledDownloads.remove(voice.key)
        activeDownloadTasks[voice.key] = nil
    }

    /// Downloads and validates a voice's config file (the small JSON),
    /// preparing extra data for voices that need it (Chinese G2PW).
    private func downloadVoiceConfig(voice: Voice,
                                     continuation: AsyncThrowingStream<DownloadEvent, Swift.Error>.Continuation) async throws -> URL {
        guard let jsonPath = voice.jsonPath else {
            throw Error.loadingFailed
        }
        guard let jsonURL = URL(string: "\(Constants.baseURL)/\(jsonPath)") else {
            throw Error.nilURL
        }

        // JSON is tiny → weight 5%
        let jsonLocalURL = try await downloadFile(
            from: jsonURL,
            key: voice.key,
            weight: 0.05,
            baseProgress: 0.0,
            continuation: continuation
        )

        if (try? ModelInfo.create(from: jsonLocalURL)) == nil {
            try? FileManager.default.removeItem(at: jsonLocalURL)
            throw Error.wrongModelInfo
        }

        if isPinyinVoice(voice, configURL: jsonLocalURL) {
            do {
                try G2PWDataManager.ensureInstalled()
            } catch {
                Log.error("Failed to ensure g2pw data: \(error)")
            }
        }

        return jsonLocalURL
    }

    private func downloadFile(
        from url: URL,
        key: String,
        weight: Double,
        baseProgress: Double,
        continuation: AsyncThrowingStream<DownloadEvent, Swift.Error>.Continuation
    ) async throws -> URL {

        let task = urlSession.downloadTask(with: url)
        let id = task.taskIdentifier
        activeDownloadTasks[key] = task
        downloadTaskKeys[id] = key

        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            let total = baseProgress + progress.fractionCompleted * weight
            continuation.yield(.progress(total))
        }

        observations[id] = observation

        return try await withCheckedThrowingContinuation { cont in
            continuations[id] = cont
            task.resume()
            if cancelledDownloads.contains(key) {
                task.cancel()
            }
        }
    }
}

extension VoiceLoader: URLSessionDownloadDelegate {

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let id = downloadTask.taskIdentifier

        do {
            let tempLocation = try FileManager.default.moveToTemporaryDirectory(fileURL: location)
            continuations[id]?.resume(returning: tempLocation)
        } catch {
            Log.error("Failed to move file to temporary location: \(error)")
            continuations[id]?.resume(throwing: error)
        }

        continuations[id] = nil
        observations[id]?.invalidate()
        observations[id] = nil
        clearDownloadTask(id: id)
    }

    private func clearDownloadTask(id: Int) {
        if let key = downloadTaskKeys[id],
           activeDownloadTasks[key]?.taskIdentifier == id {
            activeDownloadTasks[key] = nil
        }
        downloadTaskKeys[id] = nil
    }

    private func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        let id = task.taskIdentifier
        continuations[id]?.resume(throwing: error ?? URLError(.unknown))
        continuations[id] = nil
        observations[id]?.invalidate()
        observations[id] = nil
        clearDownloadTask(id: id)
    }
}
