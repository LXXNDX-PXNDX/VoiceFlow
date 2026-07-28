import SwiftUI

struct HomeView: View {
    @ObservedObject var state: AppState
    @Binding var tab: SidebarTab
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var stats = StatsManager.shared
    @ObservedObject private var history = HistoryStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                setupBanner
                recorder
                performanceRow
                recentTranscript
                statsGrid
            }
            .padding(.horizontal, 26)
            .padding(.top, 34)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Diktieren")
                    .font(.system(size: 27, weight: .semibold))
                    .tracking(-0.5)
                Text("Sprich natürlich. VoiceFlow schreibt direkt in die aktive App.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)
            modelBadge
        }
    }

    private var modelBadge: some View {
        StatusBadge(text: modelStatusText,
                    icon: modelStatusIcon,
                    tint: modelStatusColor)
    }

    private var modelStatusText: String {
        switch state.modelState {
        case .ready(let model): return "\(model.shortLabel) bereit"
        case .downloading(let progress): return "Download \(Int(progress * 100)) %"
        case .loading: return "Modell startet"
        case .failed: return "Modellfehler"
        case .idle: return "Initialisierung"
        }
    }

    private var modelStatusIcon: String {
        switch state.modelState {
        case .ready: return "bolt.fill"
        case .failed: return "exclamationmark.triangle.fill"
        default: return "arrow.triangle.2.circlepath"
        }
    }

    private var modelStatusColor: Color {
        switch state.modelState {
        case .ready: return Theme.green
        case .failed: return Theme.danger
        default: return Theme.amber
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupBanner: some View {
        let issues = openIssues
        if !issues.isEmpty {
            Card(padding: 14) {
                VStack(alignment: .leading, spacing: 11) {
                    Label("Einmalig einrichten", systemImage: "checklist")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.amber)

                    ForEach(issues, id: \.title) { issue in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.title)
                                    .font(.system(size: 12, weight: .medium))
                                Text(issue.detail)
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 8)
                            Button(issue.actionTitle, action: issue.action)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private struct SetupIssue {
        let title: String
        let detail: String
        let actionTitle: String
        let action: () -> Void
    }

    private var openIssues: [SetupIssue] {
        var issues: [SetupIssue] = []

        if !state.micGranted {
            issues.append(SetupIssue(title: "Mikrofonzugriff",
                                     detail: "VoiceFlow braucht das Mikrofon für die Aufnahme.",
                                     actionTitle: "Erlauben",
                                     action: state.requestMicrophoneAccess))
        }
        if !state.accessibilityGranted {
            issues.append(SetupIssue(title: "Bedienungshilfen",
                                     detail: "Erlaubt den globalen Hotkey und das direkte Einfügen.",
                                     actionTitle: "Öffnen",
                                     action: state.requestAccessibilityAccess))
        }
        if case .failed(let message) = state.modelState {
            issues.append(SetupIssue(title: "Sprachmodell",
                                     detail: message,
                                     actionTitle: "Neu laden",
                                     action: state.redownloadModel))
        }
        return issues
    }

    // MARK: - Recorder

    private var recorder: some View {
        VStack(spacing: 0) {
            VStack(spacing: 17) {
                HStack {
                    StatusBadge(text: phaseBadgeText,
                                icon: phaseBadgeIcon,
                                tint: phaseTint)
                    Spacer()
                    if state.isRecording {
                        Text(timeString)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Button(action: state.toggleRecording) {
                    ZStack {
                        Circle()
                            .fill(phaseTint.opacity(0.10))
                            .frame(width: state.isRecording ? 116 : 104,
                                   height: state.isRecording ? 116 : 104)

                        Circle()
                            .fill(state.isRecording ? Theme.danger : Theme.accent)
                            .frame(width: 78, height: 78)
                            .shadow(color: phaseTint.opacity(0.24), radius: 18, y: 8)

                        Image(systemName: state.isRecording ? "stop.fill" : "mic.fill")
                            .font(.system(size: 27, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(state.phase == .transcribing)
                .animation(.spring(response: 0.3, dampingFraction: 0.78), value: state.isRecording)

                VStack(spacing: 5) {
                    Text(phaseTitle)
                        .font(.system(size: 19, weight: .semibold))
                        .multilineTextAlignment(.center)
                    Text(phaseSubtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }

                Group {
                    if state.isRecording {
                        Waveform(levels: state.levels, barWidth: 4, spacing: 4)
                    } else if state.phase == .transcribing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        HStack(spacing: 5) {
                            ForEach(0..<24, id: \.self) { index in
                                Capsule()
                                    .fill(Theme.accent.opacity(index.isMultiple(of: 3) ? 0.28 : 0.14))
                                    .frame(width: 3, height: CGFloat(5 + (index % 5) * 2))
                            }
                        }
                    }
                }
                .frame(height: 34)
            }
            .padding(22)

            Divider().opacity(0.55)

            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Erkennungsmodus")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text(settings.recognitionMode.hint)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }

                Spacer(minLength: 10)

                Picker("", selection: $settings.recognitionMode) {
                    ForEach(RecognitionMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.segmented)
                .frame(width: 235)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 13)
            .background(Color.primary.opacity(0.018))
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: Theme.largeCorner, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.largeCorner, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.055), radius: 24, y: 10)
    }

    private var phaseTitle: String {
        switch state.phase {
        case .idle: return "Bereit, wenn du es bist"
        case .recording: return "Ich höre zu"
        case .transcribing: return "Text wird erzeugt"
        case .inserted: return "Fertig eingefügt"
        case .error: return "Kurz prüfen"
        }
    }

    private var phaseSubtitle: String {
        switch state.phase {
        case .idle:
            return settings.hotkeyMode.hint
        case .recording:
            return "Sprich normal und lass die Taste los, sobald du fertig bist."
        case .transcribing:
            return "Stille wurde entfernt — Whisper verarbeitet nur deine Stimme."
        case .inserted(let words):
            return "\(words) \(words == 1 ? "Wort" : "Wörter") · \(state.speedSummary ?? "lokal verarbeitet")"
        case .error(let message):
            return message
        }
    }

    private var phaseBadgeText: String {
        switch state.phase {
        case .idle: return "Bereit"
        case .recording: return "Aufnahme"
        case .transcribing: return "Verarbeitung"
        case .inserted: return "Eingefügt"
        case .error: return "Hinweis"
        }
    }

    private var phaseBadgeIcon: String {
        switch state.phase {
        case .idle: return "checkmark.circle.fill"
        case .recording: return "record.circle"
        case .transcribing: return "waveform.badge.magnifyingglass"
        case .inserted: return "checkmark"
        case .error: return "exclamationmark"
        }
    }

    private var phaseTint: Color {
        switch state.phase {
        case .recording: return Theme.danger
        case .error: return Theme.amber
        case .inserted: return Theme.green
        default: return Theme.accent
        }
    }

    private var timeString: String {
        let total = Int(state.elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    private var performanceRow: some View {
        HStack(spacing: 10) {
            compactInfo(icon: "bolt.fill",
                        title: state.speedSummary ?? "Schnelle lokale Verarbeitung",
                        detail: "GPU + Flash Attention",
                        tint: Theme.accent)
            compactInfo(icon: "lock.fill",
                        title: "100 % lokal",
                        detail: "Keine Audio-Uploads",
                        tint: Theme.green)
        }
    }

    private func compactInfo(icon: String, title: String, detail: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 11.5, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
    }

    // MARK: - Recent and stats

    @ViewBuilder
    private var recentTranscript: some View {
        if let last = history.items.first {
            VStack(alignment: .leading, spacing: 9) {
                HStack {
                    SectionHeader(title: "Zuletzt diktiert")
                    Button("Verlauf") { tab = .history }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }

                Card(padding: 15) {
                    VStack(alignment: .leading, spacing: 9) {
                        Text(last.text)
                            .font(.system(size: 12.5))
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)

                        HStack(spacing: 7) {
                            Text(last.date, style: .time)
                            Text("·")
                            Text("\(last.wordCount) Wörter")
                            if let app = last.appName {
                                Text("·")
                                Text(app)
                            }
                            Spacer()
                            if let speed = state.speedSummary {
                                Label(speed, systemImage: "bolt.fill")
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Überblick")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                StatTile(value: "\(stats.todayWords)", label: "Wörter heute", icon: "text.word.spacing", tint: Theme.accent)
                StatTile(value: "\(stats.wordsPerMinute)", label: "Wörter pro Minute", icon: "speedometer", tint: Theme.cyan)
                StatTile(value: "\(stats.totalSessions)", label: "Diktate gesamt", icon: "mic.fill", tint: Theme.pink)
                StatTile(value: "\(stats.minutesSaved)m", label: "Tippzeit gespart", icon: "clock.fill", tint: Theme.green)
            }
        }
    }
}
