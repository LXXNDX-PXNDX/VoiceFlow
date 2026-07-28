import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var stats = StatsManager.shared
    @State private var showResetConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Einstellungen")
                    .font(.system(size: 22, weight: .bold))
                    .padding(.top, 12)

                hotkeySection
                transcriptionSection
                behaviourSection
                permissionsSection
                aboutSection
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog("Statistiken zurücksetzen?",
                            isPresented: $showResetConfirmation) {
            Button("Zurücksetzen", role: .destructive) { stats.reset() }
            Button("Abbrechen", role: .cancel) { }
        } message: {
            Text("Wörter, Aufnahmen und Sprechzeit werden auf null gesetzt. Der Verlauf bleibt erhalten.")
        }
    }

    private var hotkeySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Aufnahme starten", subtitle: "Gilt systemweit in jeder App.")
            Card {
                VStack(spacing: 0) {
                    ForEach(HotkeyMode.allCases) { mode in
                        Button {
                            settings.hotkeyMode = mode
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: settings.hotkeyMode == mode
                                      ? "largecircle.fill.circle" : "circle")
                                    .foregroundStyle(settings.hotkeyMode == mode ? Theme.violet : .secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(mode.label).font(.system(size: 12, weight: .medium))
                                    Text(mode.hint)
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
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

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Spracherkennung")
            Card {
                VStack(spacing: 0) {
                    SettingRow(title: "Sprache",
                               subtitle: "Feste Sprache erkennt kurze Sätze zuverlässiger als „Automatisch“.") {
                        Picker("", selection: $settings.language) {
                            ForEach(SpeechLanguage.all) { language in
                                Text(language.label).tag(language.code)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }

                    Divider().opacity(0.5)

                    SettingRow(title: "Modell",
                               subtitle: modelSubtitle) {
                        Picker("", selection: $settings.model) {
                            ForEach(WhisperModel.allCases) { model in
                                Text(model.label).tag(model)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                    }

                    if case .downloading(let progress) = state.modelState {
                        ProgressView(value: progress)
                            .progressViewStyle(.linear)
                            .padding(.top, 4)
                    }

                    if case .failed(let message) = state.modelState {
                        HStack(spacing: 8) {
                            Text(message)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.danger)
                            Spacer(minLength: 8)
                            Button("Erneut laden", action: state.redownloadModel)
                                .controlSize(.small)
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
    }

    private var modelSubtitle: String {
        let downloaded = state.isDownloaded(settings.model)
        return downloaded
            ? "Größer heißt genauer, aber langsamer. \(settings.model.approximateSize), geladen."
            : "Wird beim Wechsel heruntergeladen (\(settings.model.approximateSize))."
    }

    private var behaviourSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Verhalten")
            Card {
                VStack(spacing: 0) {
                    SettingRow(title: "Text automatisch einfügen",
                               subtitle: "Aus: Text landet nur in der Zwischenablage.") {
                        Toggle("", isOn: $settings.autoPaste).labelsHidden()
                    }
                    Divider().opacity(0.5)
                    SettingRow(title: "Aufnahme-Anzeige",
                               subtitle: "Schwebendes Fenster am unteren Bildschirmrand.") {
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
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Berechtigungen")
            Card {
                VStack(spacing: 0) {
                    permissionRow(title: "Mikrofon",
                                  granted: state.micGranted,
                                  detail: "Für die Aufnahme.",
                                  action: state.requestMicrophoneAccess)
                    Divider().opacity(0.5)
                    permissionRow(title: "Bedienungshilfen",
                                  granted: state.accessibilityGranted,
                                  detail: "Für globalen Hotkey und Einfügen.",
                                  action: state.requestAccessibilityAccess)
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
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Daten")
            Card {
                VStack(spacing: 0) {
                    SettingRow(title: "Statistiken zurücksetzen",
                               subtitle: "Wörter, Aufnahmen und Sprechzeit.") {
                        Button("Zurücksetzen") { showResetConfirmation = true }
                            .controlSize(.small)
                    }
                    Divider().opacity(0.5)
                    SettingRow(title: "Alles bleibt auf diesem Mac",
                               subtitle: "Die Spracherkennung läuft lokal, nichts wird hochgeladen.") {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.green)
                    }
                }
            }

            Text("VoiceFlow \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 4)
        }
    }
}
