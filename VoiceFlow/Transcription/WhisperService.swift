import Foundation

enum ModelState: Equatable {
    case idle
    case downloading(progress: Double)
    case loading
    case ready(WhisperModel)
    case failed(String)

    var isReady: Bool {
        if case .ready = self { return true }
        return false
    }
}

struct TranscriptionResult {
    let text: String?
    let durationSeconds: Double
    let processingSeconds: Double
}

/// Owns the whisper.cpp context: downloads the model, keeps it loaded, runs transcription.
final class WhisperService: NSObject {

    /// Reports model download/load state on the main queue.
    var onStateChange: ((ModelState) -> Void)?

    private(set) var state: ModelState = .idle {
        didSet {
            let value = state
            DispatchQueue.main.async { [weak self] in self?.onStateChange?(value) }
        }
    }

    private var context: WhisperCtx?
    private var loadedModel: WhisperModel?
    private let contextLock = NSLock()
    private var downloadContinuation: CheckedContinuation<URL?, Never>?
    private var downloadDestination: URL?

    var isModelLoaded: Bool {
        contextLock.lock(); defer { contextLock.unlock() }
        return context != nil
    }

    var modelDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("VoiceFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func localURL(for model: WhisperModel) -> URL {
        modelDirectory.appendingPathComponent(model.fileName)
    }

    func isDownloaded(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: localURL(for: model).path)
    }

    /// Makes `model` the active one, downloading it first if necessary.
    func prepare(model: WhisperModel) async {
        if loadedModel == model, isModelLoaded {
            state = .ready(model)
            return
        }

        if !isDownloaded(model) {
            state = .downloading(progress: 0)
            let downloaded = await download(model)
            guard downloaded else {
                // Fall back to any model that is already on disk so dictation still works.
                if let fallback = WhisperModel.allCases.first(where: { isDownloaded($0) }) {
                    NSLog("[Whisper] Falling back to already downloaded \(fallback.rawValue) model")
                    await loadContext(fallback)
                } else {
                    state = .failed("Modell konnte nicht geladen werden. Internetverbindung prüfen.")
                }
                return
            }
        }

        await loadContext(model)
    }

    private func loadContext(_ model: WhisperModel) async {
        state = .loading
        let path = localURL(for: model).path

        let newContext: WhisperCtx? = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: whisperc_init(path))
            }
        }

        guard let newContext = newContext else {
            state = .failed("Modell „\(model.rawValue)“ ist beschädigt. Bitte erneut laden.")
            // A truncated download would fail forever otherwise.
            try? FileManager.default.removeItem(at: localURL(for: model))
            return
        }

        contextLock.lock()
        let old = context
        context = newContext
        contextLock.unlock()
        if let old = old { whisperc_free(old) }

        loadedModel = model
        state = .ready(model)
        NSLog("[Whisper] Model \(model.rawValue) loaded")
    }

    // MARK: - Download

    private lazy var downloadSession: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    private func download(_ model: WhisperModel) async -> Bool {
        NSLog("[Whisper] Downloading \(model.rawValue) …")
        downloadDestination = localURL(for: model)

        let tempURL: URL? = await withCheckedContinuation { continuation in
            downloadContinuation = continuation
            let task = downloadSession.downloadTask(with: model.downloadURL)
            task.resume()
        }

        guard let tempURL = tempURL else {
            NSLog("[Whisper] Download of \(model.rawValue) failed")
            return false
        }

        let destination = localURL(for: model)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: tempURL, to: destination)
            NSLog("[Whisper] Saved \(model.rawValue) to \(destination.path)")
            return true
        } catch {
            NSLog("[Whisper] Could not store model: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Transcription

    func transcribe(samples: [Float], language: String) async -> TranscriptionResult {
        let durationSeconds = Double(samples.count) / 16_000

        contextLock.lock()
        let ctx = context
        contextLock.unlock()

        guard let ctx = ctx else {
            NSLog("[Whisper] No model loaded")
            return TranscriptionResult(text: nil, durationSeconds: durationSeconds, processingSeconds: 0)
        }

        // Below ~0.4 s whisper has nothing to work with and returns noise.
        guard samples.count > 6_400 else {
            NSLog("[Whisper] Too short: \(String(format: "%.2f", durationSeconds)) s")
            return TranscriptionResult(text: nil, durationSeconds: durationSeconds, processingSeconds: 0)
        }

        let threads = Int32(max(2, min(8, ProcessInfo.processInfo.activeProcessorCount - 2)))

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let start = CFAbsoluteTimeGetCurrent()
                let maxLen: Int32 = 1 << 16
                let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLen))
                buffer.initialize(repeating: 0, count: Int(maxLen))
                defer { buffer.deallocate() }

                let ok = samples.withUnsafeBufferPointer { input -> Bool in
                    guard let base = input.baseAddress else { return false }
                    return language.withCString { lang in
                        whisperc_transcribe(ctx, base, Int32(input.count), lang, threads, buffer, maxLen)
                    }
                }

                let elapsed = CFAbsoluteTimeGetCurrent() - start
                guard ok else {
                    NSLog("[Whisper] Transcription failed")
                    continuation.resume(returning: TranscriptionResult(text: nil,
                                                                       durationSeconds: durationSeconds,
                                                                       processingSeconds: elapsed))
                    return
                }

                let raw = String(cString: buffer)
                let text = Self.clean(raw)
                NSLog("[Whisper] \(String(format: "%.2f", elapsed)) s → \"\(text ?? "")\"")
                continuation.resume(returning: TranscriptionResult(text: text,
                                                                   durationSeconds: durationSeconds,
                                                                   processingSeconds: elapsed))
            }
        }
    }

    /// whisper emits placeholders like `[BLANK_AUDIO]` or `(Musik)` for non-speech.
    private static func clean(_ raw: String) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.replacingOccurrences(of: "\\s*[\\[\\(][^\\]\\)]*[\\]\\)]\\s*",
                                         with: " ",
                                         options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    deinit {
        if let context = context { whisperc_free(context) }
    }
}

extension WhisperService: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        state = .downloading(progress: progress)
    }

    func urlSession(_ session: URLSession,
                    downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        // `location` is removed as soon as this method returns, so stash a copy.
        let staged = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceflow-\(UUID().uuidString).bin")
        do {
            try FileManager.default.moveItem(at: location, to: staged)
            downloadContinuation?.resume(returning: staged)
        } catch {
            NSLog("[Whisper] Could not stage download: \(error.localizedDescription)")
            downloadContinuation?.resume(returning: nil)
        }
        downloadContinuation = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        NSLog("[Whisper] Download error: \(error.localizedDescription)")
        downloadContinuation?.resume(returning: nil)
        downloadContinuation = nil
    }
}
