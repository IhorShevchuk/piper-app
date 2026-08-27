// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Ihor Shevchuk

import Foundation
import PiperAppUtils

enum DownloadEvent {
    case progress(Double)
    case finished(FileManager.ModelPaths)
}

protocol VoiceLoadListener: AnyObject {
    func progressUpdated(_ progress: Float)
}

class VoiceLoader: NSObject {
    private enum Error: Swift.Error {
        case nilURL
        case loadingFailed
        case wrongModelInfo
    }
    private enum Constants {
        static let baseURL = "https://huggingface.co/IhorShevchuk/piper1-voices-fp16-quantized/resolve/main"
        static let sampesBaseURL = "https://rhasspy.github.io/piper-samples/samples"

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

    private func load<Item: Decodable>(url: URL?) async throws -> Item {
        guard let url else {
            throw Error.nilURL
        }

        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        return try decoder.decode(Item.self, from: data)
    }

    func loadVoices() async throws -> [Voice] {
        let allVoices: [String: Voice] = try await load(url: Constants.voicesURL)
        return Array(allVoices.values)
    }

    func sampleURL(for voice: Voice, speaker: String = "0") -> URL? {
        let languageCode = voice.language.code
        let languageFamily = languageCode.split(separator: "_").first.map(String.init) ?? languageCode
        let path = "\(languageFamily)/\(languageCode)/\(voice.name)/\(voice.quality)/speaker_\(speaker).mp3"
        return URL(string: "\(Constants.sampesBaseURL)/\(path)")
    }

    func download(voice: Voice) -> AsyncThrowingStream<DownloadEvent, Swift.Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let modelPath = voice.modelPath,
                          let jsonPath = voice.jsonPath else {
                        throw Error.loadingFailed
                    }

                    guard let jsonURL = URL(string: "\(Constants.baseURL)/\(jsonPath)"),
                          let modelURL = URL(string: "\(Constants.baseURL)/\(modelPath)") else {
                        throw Error.nilURL
                    }

                    // JSON is tiny → weight 5%
                    let jsonLocalURL = try await self.downloadFile(
                        from: jsonURL,
                        weight: 0.05,
                        baseProgress: 0.0,
                        continuation: continuation
                    )

                    if (try? ModelInfo.create(from: jsonLocalURL)) == nil {
                        try? FileManager.default.removeItem(at: jsonLocalURL)
                        throw Error.wrongModelInfo
                    }

                    let isPinyinVoice: Bool = {
                        if voice.language.code.lowercased().hasPrefix("zh") { return true }
                        guard let data = try? Data(contentsOf: jsonLocalURL),
                              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let phonemeType = json["phoneme_type"] as? String else { return false }
                        return phonemeType.lowercased() == "pinyin"
                    }()

                    if isPinyinVoice {
                        do {
                            try G2PWDataManager.ensureInstalled()
                        } catch {
                            Log.error("Failed to ensure g2pw data: \(error)")
                        }
                    }

                    // Model is large → weight 95%
                    let modelLocalURL = try await self.downloadFile(
                        from: modelURL,
                        weight: 0.95,
                        baseProgress: 0.05,
                        continuation: continuation
                    )

                    guard let paths = FileManager.ModelPaths(model: modelLocalURL,
                                                             json: jsonLocalURL) else {
                        throw Error.loadingFailed
                    }

                    continuation.yield(.finished(paths))
                    continuation.finish()

                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    private func downloadFile(
        from url: URL,
        weight: Double,
        baseProgress: Double,
        continuation: AsyncThrowingStream<DownloadEvent, Swift.Error>.Continuation
    ) async throws -> URL {

        let task = urlSession.downloadTask(with: url)
        let id = task.taskIdentifier

        let observation = task.progress.observe(\.fractionCompleted) { progress, _ in
            let total = baseProgress + progress.fractionCompleted * weight
            continuation.yield(.progress(total))
        }

        observations[id] = observation

        return try await withCheckedThrowingContinuation { cont in
            continuations[id] = cont
            task.resume()
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
    }
}
