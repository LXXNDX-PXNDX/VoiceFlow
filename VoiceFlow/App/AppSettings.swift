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

/// Controls the decoder, not the downloaded model. Keeping those choices separate makes
/// performance predictable and avoids reloading hundreds of megabytes for every mode change.
enum RecognitionMode: String, CaseIterable, Identifiable {
    case automatic
    case instant
    case precise

    var id: String { rawValue }

    /// Stable value passed through the C bridge.
    var decoderCode: Int32 {
        switch self {
        case .automatic: return 0
        case .instant:   return 1
        case .precise:   return 2
        }
    }

    var label: String {
        switch self {
        case .automatic: return "Automatisch"
        case .instant:   return "Sofort"
        case .precise:   return "Präzise"
        }
    }

    var hint: String {
        switch self {
        case .automatic: return "Schnelle Standarderkennung mit guter Qualität."
        case .instant:   return "Minimale Wartezeit für kurze Diktate."
        case .precise:   return "Mehr Rechenzeit für schwierige Namen und längere Texte."
        }
    }
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
        case .tiny:  return "Tiny — maximal schnell"
        case .base:  return "Base — empfohlen"
        case .small: return "Small — höchste Qualität"
        }
    }

    var shortLabel: String {
        switch self {
        case .tiny:  return "Tiny"
        case .base:  return "Base"
        case .small: return "Small"
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
        SpeechLanguage(code: "auto", label: "Automatisch (Systemsprache)"),
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

    /// Whisper's language detection is useful for mixed-language recordings, but it costs
    /// noticeable time and is less reliable for a two- or three-word dictation. "Automatic"
    /// therefore uses the macOS language whenever it is supported and only falls back to
    /// Whisper detection for unknown system locales.
    static func resolvedCode(for selection: String) -> String {
        guard selection == "auto" else { return selection }
        guard let systemCode = Locale.current.language.languageCode?.identifier.lowercased(),
              all.contains(where: { $0.code == systemCode }) else {
            return "auto"
        }
        return systemCode
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

    @Published var recognitionMode: RecognitionMode {
        didSet { defaults.set(recognitionMode.rawValue, forKey: Keys.recognitionMode) }
    }

    /// Comma- or line-separated names and specialist terms that are supplied as a small
    /// Whisper prompt. This is local, optional and substantially improves uncommon words.
    @Published var customVocabulary: String {
        didSet { defaults.set(customVocabulary, forKey: Keys.customVocabulary) }
    }

    @Published var smartFormatting: Bool {
        didSet { defaults.set(smartFormatting, forKey: Keys.smartFormatting) }
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
        recognitionMode = RecognitionMode(rawValue: defaults.string(forKey: Keys.recognitionMode) ?? "") ?? .automatic
        customVocabulary = defaults.string(forKey: Keys.customVocabulary) ?? ""
        smartFormatting = defaults.object(forKey: Keys.smartFormatting) as? Bool ?? true
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
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("[Settings] Launch at login failed: \(error.localizedDescription)")
        }
    }

    private enum Keys {
        static let hotkeyMode = "vf_hotkeyMode"
        static let language = "vf_language"
        static let model = "vf_model"
        static let recognitionMode = "vf_recognitionMode"
        static let customVocabulary = "vf_customVocabulary"
        static let smartFormatting = "vf_smartFormatting"
        static let autoPaste = "vf_autoPaste"
        static let playSounds = "vf_playSounds"
        static let showPill = "vf_showPill"
        static let onboarded = "vf_onboarded"
    }
}
