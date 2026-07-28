import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var stats = StatsManager.shared
    @State private var showResetConfirmation = false
    @State private var showPermissionRepairConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                recognitionSection
                vocabularySection
                hotkeySection
                behaviourSection
                permissionsSection
                aboutSection
            }
            .padding(.horizontal, 26)
            .padding(.top, 34)
            .padding(.bottom, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("Statistiken zurücksetzen?",
                            isPresented: $showResetConfirmation) {
            Button("Zurücksetzen", role: .destructive) { stats.reset() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Wörter, Aufnahmen und Sprechzeit werden auf null gesetzt. Der Verlauf bleibt erhalten.")
        }
        .confirmationDialog("Bedienungshilfen reparieren?",
                            isPresented: $showPermissionRepairConfirmation) {
            Button("VoiceFlow-Eintrag zurücksetzen", role: .destructive) {
                state.repairAccessibilityAccess()
            }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("macOS entfernt nur den alten VoiceFlow-Eintrag. Danach kannst du die aktuelle App erneut erlauben.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("Einstellungen")
                .font(.system(size: 27, weight: .semibold))
                .tracking(-0.5)
            Text("VoiceFlow ist automatisch optimiert. Du kannst nur dort eingreifen, wo es wirklich hilft.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
    }

    private var recognitionSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Geschwindigkeit & Erkennung",
                          subtitle: "Automatisch ist für die meisten Diktate die beste Wahl.")

            Card {
                VStack(spacing: 12) {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(RecognitionMode.allCases) { mode in
                            ModeOption(mode: mode,
                                       selected: settings.recognitionMode == mode) {
                                settings.recognitionMode = mode
                            }
                        }
                    }

                    Divider().opacity(0.55)

                    SettingRow(title: "Sprache",
                               subtitle: "Automatisch nutzt zuerst deine macOS-Sprache. Das ist bei kurzen Sätzen schneller und genauer.") {
                        Picker("", selection: $settings.language) {
                            ForEach(SpeechLanguage.all) { language in
                                Text(language.label).tag(language.code)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 205)
                    }

                    Divider().opacity(0.55)

                    SettingRow(title: "Sprachmodell",
                               subtitle: modelSubtitle) {
                        Picker("", selection: $settings.model) {
                            ForEach(WhisperModel.allCases) { model in
                                Text(model.label).tag(model)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 205)
                    }

                    if case .downloading(let progress) = state.modelState {
                        VStack(alignment: .leading, spacing: 5) {
                            ProgressView(value: progress)
                                .progressViewStyle(.linear)
                            Text("Modell wird geladen · \(Int(progress * 100)) %")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)
                        }
                    }

                    if case .failed(let message) = state.modelState {
                        HStack(spacing: 8) {
                            Label(message, systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.danger)
                            Spacer(minLength: 8)
                            Button("Neu laden", action: state.redownloadModel)
                                .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    private var modelSubtitle: String {
        let downloaded = state.isDownloaded(settings.model)
        let stateText = downloaded ? "geladen" : "wird beim Wechsel geladen"
        switch settings.model {
        case .tiny:
            return "Kleinste lokale AI, extrem schnell. \(settings.model.approximateSize), \(stateText)."
        case .base:
            return "Empfohlene Mischung aus Tempo und Worterkennung. \(settings.model.approximateSize), \(stateText)."
        case .small:
            return "Genauer bei Akzenten und Fachwörtern, aber deutlich langsamer. \(settings.model.approximateSize), \(stateText)."
        }
    }

    private var vocabularySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Eigene Wörter",
                          subtitle: "Optional: Namen, Marken oder Fachbegriffe verbessern, ohne eine Cloud-AI zu verwenden.")
            Card {
                VStack(alignment: .leading, spacing: 10) {
                    TextEditor(text: $settings.customVocabulary)
                        .font(.system(size: 12))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: 70, maxHeight: 90)
                        .background(Color.primary.opacity(0.035),
                                    in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                        )

                    Text("Mit Kommas oder neuen Zeilen trennen, zum Beispiel: ChatGPT, Leander, Basel")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)

                    Divider().opacity(0.55)

                    SettingRow(title: "Intelligente Formatierung",
                               subtitle: "Räumt Leerzeichen auf und setzt einen sauberen Satzanfang.") {
                        Toggle("", isOn: $settings.smartFormatting)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Aufnahme starten", subtitle: "Gilt systemweit in jeder App.")
            Card {
                VStack(spacing: 0) {
                    ForEach(HotkeyMode.allCases) { mode in
                        Button {
                            settings.hotkeyMode = mode
                        } label: {
                            HStack(spacing: 11) {
                                Image(systemName: settings.hotkeyMode == mode
                                      ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(settings.hotkeyMode == mode ? Theme.accent : .secondary)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(mode.label)
                                        .font(.system(size: 12.5, weight: .medium))
                                    Text(mode.hint)
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 7)
                        }
                        .buttonStyle(.plain)

                        if mode != HotkeyMode.allCases.last {
                            Divider().opacity(0.5)
                        }
                    }
                }
            }
        }
    }

    private var behaviourSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Verhalten")
            Card {
                VStack(spacing: 0) {
                    SettingRow(title: "Text automatisch einfügen",
                               subtitle: "Aus: Text landet nur in der Zwischenablage.") {
                        Toggle("", isOn: $settings.autoPaste).labelsHidden()
                    }
                    Divider().opacity(0.5)
                    SettingRow(title: "Kleine Aufnahme-Anzeige",
                               subtitle: "Zeigt Status und Wellenform am unteren Bildschirmrand.") {
                        Toggle("", isOn: $settings.showPill).labelsHidden()
                    }
                    Divider().opacity(0.5)
                    SettingRow(title: "Töne", subtitle: "Kurzer Klang bei Start und Ende.") {
                        Toggle("", isOn: $settings.playSounds).labelsHidden()
                    }
                    Divider().opacity(0.5)
                    SettingRow(title: "Bei Anmeldung starten") {
                        Toggle("", isOn: $settings.launchAtLogin).labelsHidden()
                    }
                }
            }
        }
    }

    private var permissionsSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(
                title: "Berechtigungen",
                subtitle: "„Erlaubt“ erscheint nur, wenn macOS VoiceFlow offiziell freigegeben hat."
            )

            Card {
                VStack(spacing: 0) {
                    permissionRow(title: "Mikrofon",
                                  granted: state.micGranted,
                                  detail: "Für die lokale Aufnahme.",
                                  action: state.requestMicrophoneAccess)

                    Divider().opacity(0.5)

                    SettingRow(
                        title: "Bedienungshilfen",
                        subtitle: "Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen"
                    ) {
                        if state.accessibilityGranted {
                            Label("Erlaubt", systemImage: "checkmark.circle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.green)
                        } else {
                            Label("Nicht erlaubt", systemImage: "xmark.circle.fill")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Theme.danger)
                        }
                    }

                    Divider().opacity(0.5)

                    if state.accessibilityGranted {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(Theme.green)

                            Text("macOS hat den Zugriff für diese VoiceFlow-Version bestätigt.")
                                .font(.system(size: 10.5))
                                .foregroundStyle(.secondary)

                            Spacer(minLength: 8)

                            Button("Systemeinstellungen", action: state.openAccessibilitySettings)
                                .controlSize(.small)
                        }
                        .padding(.vertical, 8)
                    } else {
                        VStack(alignment: .leading, spacing: 11) {
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: "1.circle.fill")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.accent)
                                    .padding(.top, 1)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("VoiceFlow in macOS aktivieren")
                                        .font(.system(size: 11.5, weight: .semibold))
                                    Text("Öffne Bedienungshilfen und schalte VoiceFlow ein. Fehlt VoiceFlow in der Liste, klicke auf „+“ und wähle /Applications/VoiceFlow.app.")
                                        .font(.system(size: 10.5))
                                        .foregroundStyle(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            HStack(spacing: 8) {
                                Button("Bedienungshilfen öffnen", action: state.requestAccessibilityAccess)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)

                                Button("Neu prüfen", action: state.refreshPermissions)
                                    .controlSize(.small)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 9)

                        Divider().opacity(0.5)

                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "wrench.and.screwdriver.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.amber)
                                .padding(.top, 2)

                            VStack(alignment: .leading, spacing: 3) {
                                Text("VoiceFlow ist eingeschaltet, bleibt hier aber rot?")
                                    .font(.system(size: 11.5, weight: .medium))
                                Text("Dann kann ein alter macOS-Eintrag von einer früheren App-Version übrig sein.")
                                    .font(.system(size: 10.5))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            Spacer(minLength: 8)

                            Button("Reparieren") {
                                showPermissionRepairConfirmation = true
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 7)
                    }
                }
            }
        }
    }

    private func permissionRow(title: String,
                               granted: Bool,
                               detail: String,
                               action: @escaping () -> Void) -> some View {
        SettingRow(title: title, subtitle: detail) {
            if granted {
                Label("Erlaubt", systemImage: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.green)
            } else {
                Button("Erlauben", action: action)
                    .controlSize(.small)
            }
        }
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            SectionHeader(title: "Daten & App")
            Card {
                VStack(spacing: 0) {
                    SettingRow(title: "Alles bleibt auf diesem Mac",
                               subtitle: "Audio und Text werden nicht an einen Server geschickt.") {
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.green)
                    }
                    Divider().opacity(0.5)
                    SettingRow(title: "Statistiken zurücksetzen",
                               subtitle: "Wörter, Aufnahmen und Sprechzeit.") {
                        Button("Zurücksetzen") { showResetConfirmation = true }
                            .controlSize(.small)
                    }
                }
            }

            Text("VoiceFlow \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0") · SwiftUI + whisper.cpp")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 3)
        }
    }
}
