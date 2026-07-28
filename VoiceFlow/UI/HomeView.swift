import SwiftUI

struct HomeView: View {
    @ObservedObject var state: AppState
    @Binding var tab: SidebarTab
    @ObservedObject private var stats = StatsManager.shared
    @ObservedObject private var history = HistoryStore.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                setupBanner
                recorder
                statsGrid
                recentTranscript
            }
            .padding(22)
            .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(.system(size: 22, weight: .bold))
            Text("Sprich statt zu tippen — überall auf dem Mac.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Guten Morgen"
        case 11..<17: return "Hallo"
        case 17..<22: return "Guten Abend"
        default: return "Gute Nacht"
        }
    }

    // MARK: - Setup

    @ViewBuilder
    private var setupBanner: some View {
        let issues = openIssues
        if !issues.isEmpty {
            Card(padding: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 7) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.amber)
                        Text("Noch \(issues.count) \(issues.count == 1 ? "Schritt" : "Schritte") bis zum Start")
                            .font(.system(size: 12.5, weight: .semibold))
                    }
                    ForEach(issues, id: \.title) { issue in
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(issue.title).font(.system(size: 12))
                                Text(issue.detail)
                                    .font(.system(size: 11))
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
                                     detail: "Ohne Mikrofon kann nichts aufgenommen werden.",
                                     actionTitle: "Erlauben",
                                     action: state.requestMicrophoneAccess))
        }
        if !state.accessibilityGranted {
            issues.append(SetupIssue(title: "Bedienungshilfen",
                                     detail: "Nötig für den globalen Hotkey und das Einfügen.",
                                     actionTitle: "Öffnen",
                                     action: state.requestAccessibilityAccess))
        }
        if case .failed(let message) = state.modelState {
            issues.append(SetupIssue(title: "Sprachmodell",
                                     detail: message,
                                     actionTitle: "Erneut laden",
                                     action: state.redownloadModel))
        }
        return issues
    }

    // MARK: - Recorder

    private var recorder: some View {
        Card(padding: 20) {
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Theme.accentGradient)
                        .opacity(state.isRecording ? 0.22 : 0.14)
                        .frame(width: state.isRecording ? 116 : 96,
                               height: state.isRecording ? 116 : 96)

                    Button(action: state.toggleRecording) {
                        ZStack {
                            Circle()
                                .fill(state.isRecording ? AnyShapeStyle(Theme.danger)
                                                        : AnyShapeStyle(Theme.accentGradient))
                                .frame(width: 72, height: 72)
                            Image(systemName: state.isRecording ? "stop.fill" : "mic.fill")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(state.phase == .transcribing)
                }
                .frame(height: 120)
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: state.isRecording)

                Group {
                    if state.isRecording {
                        Waveform(levels: state.levels, barWidth: 4, spacing: 4)
                            .frame(height: 34)
                    } else {
                        Text(hintText)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .frame(height: 34)
                    }
                }

                if case .downloading(let progress) = state.modelState {
                    VStack(spacing: 5) {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                        Text("Sprachmodell wird geladen — \(Int(progress * 100)) %")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var hintText: String {
        switch state.phase {
        case .transcribing: return "Transkribiere …"
        case .error(let message): return message
        case .inserted(let words): return "\(words) \(words == 1 ? "Wort" : "Wörter") eingefügt"
        default: return "\(state.settings.hotkeyMode.label) — \(state.settings.hotkeyMode.hint)"
        }
    }

    // MARK: - Stats

    private var statsGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Deine Zahlen")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10),
                                GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                StatTile(value: "\(stats.todayWords)", label: "Heute", icon: "sun.max.fill", tint: Theme.violet)
                StatTile(value: "\(stats.totalWords)", label: "Gesamt", icon: "text.word.spacing", tint: Theme.indigo)
                StatTile(value: "\(stats.totalSessions)", label: "Aufnahmen", icon: "mic.fill", tint: Theme.cyan)
                StatTile(value: "\(stats.wordsPerMinute)", label: "Wörter/Min", icon: "speedometer", tint: Theme.pink)
                StatTile(value: stats.formattedTotalTime, label: "Sprechzeit", icon: "clock.fill", tint: Theme.amber)
                StatTile(value: "\(stats.minutesSaved)m", label: "Gespart", icon: "bolt.fill", tint: Theme.green)
            }
        }
    }

    // MARK: - Last transcript

    @ViewBuilder
    private var recentTranscript: some View {
        if let last = history.items.first {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionHeader(title: "Zuletzt diktiert")
                    Button("Alle ansehen") { tab = .history }
                        .buttonStyle(.link)
                        .font(.system(size: 11))
                }
                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(last.text)
                            .font(.system(size: 12.5))
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 8) {
                            Text(last.date, style: .time)
                            Text("·")
                            Text("\(last.wordCount) Wörter")
                            if let app = last.appName {
                                Text("·")
                                Text(app)
                            }
                        }
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}
