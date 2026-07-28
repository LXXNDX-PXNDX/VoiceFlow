import Foundation
import ServiceManagement

enum HotkeyMode: String, CaseIterable, Identifiable {
    case fnHold
    case fnDoubleTap
    case rightCommandHold
    case rightOptionHold

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fnHold:           return "Fn gedrückt halten"
        case .fnDoubleTap:      return "Fn doppelt tippen"
        case .rightCommandHold: return "Rechte ⌘ gedrückt halten"
        case .rightOptionHold:  return "Rechte ⌥ gedrückt halten"
        }
    }

    var hint: String {
        switch self {
        case .fnHold:           return "Halten zum Sprechen, loslassen zum Einfügen."
        case .fnDoubleTap:      return "Zweimal tippen startet, zweimal tippen stoppt."
        case .rightCommandHold: return "Halten zum Sprechen. Nützlich, wenn Fn belegt ist."
        case .rightOptionHold:  return "Halten zum Sprechen. Nützlich, wenn Fn belegt ist."
        }
    }

    var isHold: Bool { self != .fnDoubleTap }
}

enum WhisperModel: String, CaseIterable, Identifiable {
    case tiny, base, small

    var id: String { rawValue }
    var fileName: String { "ggml-\(rawValue).bin" }
    var downloadURL: URL {
        URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/\(fileName)")!
    }

    var label: String {
        switch self {
        case .tiny:  return "Tiny — am schnellsten"
        case .base:  return "Base — ausgewogen"
        case .small: return "Small — beste Qualität"
        }
    }

    var approximateSize: String {
        switch self {
        case .tiny:  return "75 MB"
        case .base:  return "142 MB"
        case .small: return "466 MB"
        }
    }
}

struct SpeechLanguage: Identifiable, Hashable {
    let code: String
    let label: String
    var id: String { code }

    static let all: [SpeechLanguage] = [
        SpeechLanguage(code: "auto", label: "Automatisch erkennen"),
        SpeechLanguage(code: "de", label: "Deutsch"),
        SpeechLanguage(code: "en", label: "Englisch"),
        SpeechLanguage(code: "fr", label: "Französisch"),
        SpeechLanguage(code: "es", label: "Spanisch"),
        SpeechLanguage(code: "it", label: "Italienisch"),
        SpeechLanguage(code: "nl", label: "Niederländisch"),
        SpeechLanguage(code: "pt", label: "Portugiesisch"),
        SpeechLanguage(code: "pl", label: "Polnisch"),
        SpeechLanguage(code: "tr", label: "Türkisch"),
        SpeechLanguage(code: "ru", label: "Russisch")
    ]

    static func label(for code: String) -> String {
        all.first { $0.code == code }?.label ?? code.uppercased()
    }
}

/// User-facing preferences, persisted in UserDefaults.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    @Published var hotkeyMode: HotkeyMode {
        didSet { defaults.set(hotkeyMode.rawValue, forKey: Keys.hotkeyMode) }
    }

    @Published var language: String {
        didSet { defaults.set(language, forKey: Keys.language) }
    }

    @Published var model: WhisperModel {
        didSet { defaults.set(model.rawValue, forKey: Keys.model) }
    }

    /// Paste the transcript into the frontmost app. When off, it only lands on the clipboard.
    @Published var autoPaste: Bool {
        didSet { defaults.set(autoPaste, forKey: Keys.autoPaste) }
    }

    @Published var playSounds: Bool {
        didSet { defaults.set(playSounds, forKey: Keys.playSounds) }
    }

    @Published var showPill: Bool {
        didSet { defaults.set(showPill, forKey: Keys.showPill) }
    }

    @Published var launchAtLogin: Bool {
        didSet { applyLaunchAtLogin(launchAtLogin) }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.onboarded) }
        set { defaults.set(newValue, forKey: Keys.onboarded) }
    }

    private init() {
        hotkeyMode = HotkeyMode(rawValue: defaults.string(forKey: Keys.hotkeyMode) ?? "") ?? .fnHold
        language = defaults.string(forKey: Keys.language) ?? "auto"
        model = WhisperModel(rawValue: defaults.string(forKey: Keys.model) ?? "") ?? .base
        autoPaste = defaults.object(forKey: Keys.autoPaste) as? Bool ?? true
        playSounds = defaults.object(forKey: Keys.playSounds) as? Bool ?? true
        showPill = defaults.object(forKey: Keys.showPill) as? Bool ?? true
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }

    private func applyLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("[Settings] Launch at login failed: \(error.localizedDescription)")
        }
    }

    private enum Keys {
        static let hotkeyMode = "vf_hotkeyMode"
        static let language = "vf_language"
        static let model = "vf_model"
        static let autoPaste = "vf_autoPaste"
        static let playSounds = "vf_playSounds"
        static let showPill = "vf_showPill"
        static let onboarded = "vf_onboarded"
    }
}
