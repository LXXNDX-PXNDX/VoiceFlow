import AppKit
import AVFoundation
import Combine
import SwiftUI

/// Single source of truth for the recording pipeline and everything the UI shows.
@MainActor
final class AppState: ObservableObject {

    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
        case inserted(words: Int)
        case error(String)
    }

    static let shared = AppState()

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var modelState: ModelState = .idle
    @Published private(set) var levels: [Float] = Array(repeating: 0, count: AppState.waveformBars)
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var micGranted = false
    @Published private(set) var accessibilityGranted = false
    @Published private(set) var lastProcessingSeconds: Double?
    @Published private(set) var lastRealtimeFactor: Double?

    static let waveformBars = 36
    static let maxRecordingSeconds: TimeInterval = 120

    let settings = AppSettings.shared
    let history = HistoryStore.shared
    let stats = StatsManager.shared

    private let audioRecorder = AudioRecorder()
    private let whisper = WhisperService()
    private let textInserter = TextInserter()
    private let permissions = PermissionsManager()
    private let hotkeys = HotkeyManager()

    private var elapsedTimer: Timer?
    private var permissionTimer: Timer?
    private var resetTask: Task<Void, Never>?
    private var recordingStart: Date?
    private var cancellables = Set<AnyCancellable>()

    var isRecording: Bool { phase == .recording }
    var isBusy: Bool { phase == .recording || phase == .transcribing }

    var speedSummary: String? {
        guard let processing = lastProcessingSeconds,
              let factor = lastRealtimeFactor,
              processing > 0 else { return nil }

        if factor > 0, factor < 1 {
            return "\(String(format: "%.1f", 1 / factor))× schneller als Echtzeit"
        }
        return "Fertig in \(String(format: "%.1f", processing)) s"
    }

    private init() {
        audioRecorder.onLevel = { [weak self] level in
            self?.append(level: level)
        }

        whisper.onStateChange = { [weak self] state in
            self?.modelState = state
        }

        hotkeys.onStartRecording = { [weak self] in self?.startRecording() }
        hotkeys.onStopRecording = { [weak self] in self?.stopRecording() }
        hotkeys.onCancelRecording = { [weak self] in self?.cancelRecording() }

        settings.$hotkeyMode
            .receive(on: RunLoop.main)
            .sink { [weak self] mode in self?.hotkeys.mode = mode }
            .store(in: &cancellables)

        settings.$model
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] model in
                Task { await self?.whisper.prepare(model: model) }
            }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    func bootstrap() {
        refreshPermissions()
        hotkeys.mode = settings.hotkeyMode
        hotkeys.start()

        Task { await whisper.prepare(model: settings.model) }

        // System Settings is a separate app. Re-check immediately when VoiceFlow becomes
        // active again, then restart the global monitor when access was newly granted.
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.refreshPermissions() }
            .store(in: &cancellables)

        permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshPermissions() }
        }
        if let permissionTimer {
            RunLoop.main.add(permissionTimer, forMode: .common)
        }
    }

    func shutdown() {
        hotkeys.stop()
        permissionTimer?.invalidate()
        elapsedTimer?.invalidate()
        audioRecorder.cancel()
    }

    func refreshPermissions() {
        let previousAccessibility = accessibilityGranted
        let currentMicrophone = permissions.hasMicrophoneAccess()
        let currentAccessibility = permissions.hasAccessibilityAccess()

        micGranted = currentMicrophone
        accessibilityGranted = currentAccessibility

        if currentAccessibility && !previousAccessibility {
            NSLog("[Permissions] Accessibility became available; restarting hotkey monitor")
            hotkeys.start()
        }
    }

    func requestMicrophoneAccess() {
        permissions.requestMicrophoneAccess { [weak self] _ in
            Task { @MainActor in
                self?.refreshPermissions()
                self?.schedulePermissionRefreshes()
            }
        }
    }

    func requestAccessibilityAccess() {
        permissions.promptForAccessibility()
        schedulePermissionRefreshes()
    }

    func repairAccessibilityAccess() {
        accessibilityGranted = false
        _ = permissions.repairAccessibilityAccess()
        schedulePermissionRefreshes()
    }

    func openMicrophoneSettings() {
        permissions.openMicrophoneSettings()
    }

    func openAccessibilitySettings() {
        permissions.openAccessibilitySettings()
    }

    private func schedulePermissionRefreshes() {
        Task { [weak self] in
            for delay in [300_000_000, 900_000_000, 1_800_000_000] as [UInt64] {
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled else { return }
                self?.refreshPermissions()
            }
        }
    }

    func redownloadModel() {
        Task { await whisper.prepare(model: settings.model) }
    }

    func isDownloaded(_ model: WhisperModel) -> Bool {
        whisper.isDownloaded(model)
    }

    // MARK: - Recording

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        guard phase != .recording else { return }
        guard phase != .transcribing else { return }

        refreshPermissions()
        guard micGranted else {
            requestMicrophoneAccess()
            show(.error("Kein Mikrofonzugriff. Bitte in den Systemeinstellungen erlauben."))
            return
        }

        guard modelState.isReady else {
            if case .downloading(let progress) = modelState {
                show(.error("Modell lädt noch … \(Int(progress * 100)) %"))
            } else {
                show(.error("Sprachmodell ist noch nicht bereit."))
                Task { await whisper.prepare(model: settings.model) }
            }
            return
        }

        resetTask?.cancel()
        textInserter.rememberFrontmostApp()

        guard audioRecorder.startRecording() else {
            show(.error("Mikrofon konnte nicht gestartet werden."))
            return
        }

        levels = Array(repeating: 0, count: Self.waveformBars)
        recordingStart = Date()
        elapsed = 0
        phase = .recording
        hotkeys.syncToggleState(isRecording: true)
        playSound(named: "Tink")

        elapsedTimer?.invalidate()
        elapsedTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.recordingStart else { return }
                self.elapsed = Date().timeIntervalSince(start)

                if self.elapsed >= Self.maxRecordingSeconds {
                    NSLog("[App] Reached maximum recording length, stopping")
                    self.stopRecording()
                }
            }
        }
        if let elapsedTimer {
            RunLoop.main.add(elapsedTimer, forMode: .common)
        }
    }

    func stopRecording() {
        guard phase == .recording else { return }

        stopTimers()
        let samples = audioRecorder.stopRecording()
        let capturedDuration = elapsed
        phase = .transcribing
        hotkeys.syncToggleState(isRecording: false)
        playSound(named: "Pop")

        let language = settings.language
        let mode = settings.recognitionMode
        let vocabulary = settings.customVocabulary
        let smartFormatting = settings.smartFormatting
        let targetName = NSWorkspace.shared.frontmostApplication?.localizedName

        Task { [weak self] in
            guard let self else { return }
            let result = await self.whisper.transcribe(samples: samples,
                                                       language: language,
                                                       mode: mode,
                                                       customVocabulary: vocabulary,
                                                       smartFormatting: smartFormatting)
            await MainActor.run {
                self.finish(result: result,
                            capturedDuration: capturedDuration,
                            appName: targetName)
            }
        }
    }

    func cancelRecording() {
        guard phase == .recording else { return }
        stopTimers()
        audioRecorder.cancel()
        hotkeys.syncToggleState(isRecording: false)
        show(.idle)
    }

    private func finish(result: TranscriptionResult,
                        capturedDuration: Double,
                        appName: String?) {
        lastProcessingSeconds = result.processingSeconds
        lastRealtimeFactor = result.realtimeFactor

        guard let text = result.text, !text.isEmpty else {
            show(.error(capturedDuration < 0.5
                        ? "Zu kurz — bitte etwas länger sprechen."
                        : "Nichts verstanden. Bitte erneut versuchen."))
            return
        }

        let transcript = Transcript(text: text,
                                    durationSeconds: max(result.durationSeconds, capturedDuration),
                                    appName: appName)
        history.add(transcript)
        stats.recordSession(words: transcript.wordCount,
                            durationSeconds: transcript.durationSeconds)
        stats.lastTranscript = text

        if settings.autoPaste {
            let pasted = textInserter.insertText(text)
            if !pasted {
                refreshPermissions()
                show(.error("In die Zwischenablage kopiert — Bedienungshilfen fehlen zum Einfügen."))
                return
            }
        } else {
            textInserter.copyToClipboard(text)
        }

        show(.inserted(words: transcript.wordCount))
    }

    // MARK: - Helpers

    private func stopTimers() {
        elapsedTimer?.invalidate()
        elapsedTimer = nil
        recordingStart = nil
    }

    private func append(level: Float) {
        guard phase == .recording else { return }
        levels.removeFirst()
        levels.append(level)
    }

    /// Shows a transient phase and falls back to `.idle` after a moment.
    private func show(_ newPhase: Phase) {
        resetTask?.cancel()
        phase = newPhase

        guard newPhase != .idle else { return }

        let delay: UInt64 = {
            if case .error = newPhase { return 3_500_000_000 }
            return 1_400_000_000
        }()

        resetTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard let self, self.phase == newPhase else { return }
                self.phase = .idle
            }
        }
    }

    private func playSound(named name: String) {
        guard settings.playSounds else { return }
        NSSound(named: name)?.play()
    }
}
