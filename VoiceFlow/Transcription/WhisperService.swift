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

    var realtimeFactor: Double {
        guard durationSeconds > 0 else { return 0 }
        return processingSeconds / durationSeconds
    }
}

/// Owns the whisper.cpp context: downloads the model, keeps it loaded and serialises inference.
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

    /// whisper.cpp contexts are not thread-safe. A single high-priority queue prevents model
    /// replacement from racing an active transcription and keeps hot context memory reusable.
    private let inferenceQueue = DispatchQueue(label: "com.voiceflow.whisper.inference",
                                               qos: .userInitiated)

    private var downloadContinuation: CheckedContinuation<URL?, Never>?

    var isModelLoaded: Bool {
        withContextLock { context != nil }
    }

    var modelDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("VoiceFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    func localURL(for model: WhisperModel) -> URL {
        modelDirectory.appendingPathComponent(model.fileName)
    }

    func isDownloaded(_ model: WhisperModel) -> Bool {
        FileManager.default.fileExists(atPath: localURL(for: model).path)
    }

    /// Makes `model` the active one, downloading it first if necessary.
    func prepare(model: WhisperModel) async {
        let alreadyLoaded = withContextLock {
            loadedModel == model && context != nil
        }

        if alreadyLoaded {
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

        let loaded: Bool = await withCheckedContinuation { continuation in
            inferenceQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: false)
                    return
                }

                guard let newContext = whisperc_init(path) else {
                    continuation.resume(returning: false)
                    return
                }

                let oldContext = self.withContextLock { () -> WhisperCtx? in
                    let previous = self.context
                    self.context = newContext
                    self.loadedModel = model
                    return previous
                }

                if let oldContext { whisperc_free(oldContext) }
                continuation.resume(returning: true)
            }
        }

        guard loaded else {
            state = .failed("Modell „\(model.rawValue)“ ist beschädigt. Bitte erneut laden.")
            // A truncated download would fail forever otherwise.
            try? FileManager.default.removeItem(at: localURL(for: model))
            return
        }

        state = .ready(model)
        NSLog("[Whisper] Model \(model.rawValue) loaded with GPU acceleration")
    }

    // MARK: - Download

    private lazy var downloadSession: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.waitsForConnectivity = true
        configuration.timeoutIntervalForResource = 60 * 30
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private func download(_ model: WhisperModel) async -> Bool {
        NSLog("[Whisper] Downloading \(model.rawValue) …")

        let temporaryURL: URL? = await withCheckedContinuation { continuation in
            downloadContinuation = continuation
            downloadSession.downloadTask(with: model.downloadURL).resume()
        }

        guard let temporaryURL else {
            NSLog("[Whisper] Download of \(model.rawValue) failed")
            return false
        }

        let destination = localURL(for: model)
        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destination)
            NSLog("[Whisper] Saved \(model.rawValue) to \(destination.path)")
            return true
        } catch {
            NSLog("[Whisper] Could not store model: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Transcription

    func transcribe(samples: [Float],
                    language: String,
                    mode: RecognitionMode,
                    customVocabulary: String,
                    smartFormatting: Bool) async -> TranscriptionResult {
        let durationSeconds = Double(samples.count) / 16_000

        guard samples.count > 6_400 else {
            NSLog("[Whisper] Too short: \(String(format: "%.2f", durationSeconds)) s")
            return TranscriptionResult(text: nil,
                                       durationSeconds: durationSeconds,
                                       processingSeconds: 0)
        }

        let resolvedLanguage = SpeechLanguage.resolvedCode(for: language)
        let prompt = Self.prompt(from: customVocabulary)
        let threads = Self.threadCount

        return await withCheckedContinuation {
            (continuation: CheckedContinuation<TranscriptionResult, Never>) in
            inferenceQueue.async { [weak self] in
                guard let self else {
                    continuation.resume(returning: TranscriptionResult(text: nil,
                                                                       durationSeconds: durationSeconds,
                                                                       processingSeconds: 0))
                    return
                }

                let currentContext = self.withContextLock { self.context }
                guard let currentContext else {
                    NSLog("[Whisper] No model loaded")
                    continuation.resume(returning: TranscriptionResult(text: nil,
                                                                       durationSeconds: durationSeconds,
                                                                       processingSeconds: 0))
                    return
                }

                let start = CFAbsoluteTimeGetCurrent()
                let maxLength: Int32 = 1 << 16
                let buffer = UnsafeMutablePointer<CChar>.allocate(capacity: Int(maxLength))
                buffer.initialize(repeating: 0, count: Int(maxLength))
                defer { buffer.deallocate() }

                let durationMilliseconds = Int32(
                    min(Double(Int32.max), durationSeconds * 1_000)
                )

                let succeeded = samples.withUnsafeBufferPointer { input -> Bool in
                    guard let baseAddress = input.baseAddress else { return false }
                    return resolvedLanguage.withCString { languageCString in
                        prompt.withCString { promptCString in
                            whisperc_transcribe(currentContext,
                                                baseAddress,
                                                Int32(input.count),
                                                languageCString,
                                                threads,
                                                mode.decoderCode,
                                                durationMilliseconds,
                                                promptCString,
                                                buffer,
                                                maxLength)
                        }
                    }
                }

                let elapsed = CFAbsoluteTimeGetCurrent() - start
                guard succeeded else {
                    NSLog("[Whisper] Transcription failed")
                    continuation.resume(returning: TranscriptionResult(text: nil,
                                                                       durationSeconds: durationSeconds,
                                                                       processingSeconds: elapsed))
                    return
                }

                let raw = String(cString: buffer)
                let text = Self.clean(raw, smartFormatting: smartFormatting)
                let factor = durationSeconds > 0 ? elapsed / durationSeconds : 0
                NSLog("[Whisper] \(String(format: "%.2f", elapsed)) s (\(String(format: "%.2f", factor))× realtime) → \"\(text ?? "")\"")
                continuation.resume(returning: TranscriptionResult(text: text,
                                                                   durationSeconds: durationSeconds,
                                                                   processingSeconds: elapsed))
            }
        }
    }

    private static var threadCount: Int32 {
        let available = ProcessInfo.processInfo.activeProcessorCount
        // 6–8 threads is typically the useful range on Apple Silicon; leaving two cores free
        // keeps the UI and target application responsive while Whisper is decoding.
        return Int32(max(2, min(8, available - 2)))
    }

    private static func prompt(from vocabulary: String) -> String {
        let terms = vocabulary
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !terms.isEmpty else { return "" }
        return String(terms.joined(separator: ", ").prefix(320))
    }

    /// Removes Whisper control placeholders and applies conservative text formatting.
    private static func clean(_ raw: String, smartFormatting: Bool) -> String? {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        let placeholders = [
            "\\[(?:BLANK_AUDIO|SILENCE|MUSIC|APPLAUSE|INAUDIBLE)\\]",
            "\\((?:Musik|Stille|Applaus|unverständlich)\\)"
        ]
        for pattern in placeholders {
            text = text.replacingOccurrences(of: pattern,
                                             with: " ",
                                             options: [.regularExpression, .caseInsensitive])
        }

        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)

        guard smartFormatting, !text.isEmpty else {
            return text.isEmpty ? nil : text
        }

        text = text.replacingOccurrences(of: "\\s+([,.;:!?])",
                                         with: "$1",
                                         options: .regularExpression)
        text = text.replacingOccurrences(of: "([,.;:!?])(?=\\p{L})",
                                         with: "$1 ",
                                         options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

        if let firstLetter = text.firstIndex(where: { $0.isLetter }) {
            let uppercased = String(text[firstLetter]).uppercased()
            text.replaceSubrange(firstLetter...firstLetter, with: uppercased)
        }

        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    private func withContextLock<Value>(_ operation: () -> Value) -> Value {
        contextLock.lock()
        defer { contextLock.unlock() }
        return operation()
    }

    deinit {
        let currentContext = withContextLock { () -> WhisperCtx? in
            let current = context
            context = nil
            loadedModel = nil
            return current
        }
        if let currentContext { whisperc_free(currentContext) }
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

    func urlSession(_ session: URLSession,
                    task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        guard let error else { return }
        NSLog("[Whisper] Download error: \(error.localizedDescription)")
        downloadContinuation?.resume(returning: nil)
        downloadContinuation = nil
    }
}
