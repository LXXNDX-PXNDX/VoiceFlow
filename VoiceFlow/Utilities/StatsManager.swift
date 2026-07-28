import Foundation

final class StatsManager: ObservableObject {
    static let shared = StatsManager()

    private let defaults = UserDefaults.standard
    private let prefix = "vf_"

    var totalWords: Int {
        get { defaults.integer(forKey: "\(prefix)totalWords") }
        set { defaults.set(newValue, forKey: "\(prefix)totalWords") }
    }

    var totalSessions: Int {
        get { defaults.integer(forKey: "\(prefix)totalSessions") }
        set { defaults.set(newValue, forKey: "\(prefix)totalSessions") }
    }

    var totalRecordingSeconds: Double {
        get { defaults.double(forKey: "\(prefix)totalSeconds") }
        set { defaults.set(newValue, forKey: "\(prefix)totalSeconds") }
    }

    var todayWords: Int {
        get {
            guard todayKey == defaults.string(forKey: "\(prefix)todayKey") else { return 0 }
            return defaults.integer(forKey: "\(prefix)todayWords")
        }
        set {
            defaults.set(todayKey, forKey: "\(prefix)todayKey")
            defaults.set(newValue, forKey: "\(prefix)todayWords")
        }
    }

    var todaySessions: Int {
        get {
            guard todayKey == defaults.string(forKey: "\(prefix)todayKey") else { return 0 }
            return defaults.integer(forKey: "\(prefix)todaySessions")
        }
        set {
            defaults.set(todayKey, forKey: "\(prefix)todayKey")
            defaults.set(newValue, forKey: "\(prefix)todaySessions")
        }
    }

    var lastTranscript: String {
        get { defaults.string(forKey: "\(prefix)lastTranscript") ?? "" }
        set { defaults.set(newValue, forKey: "\(prefix)lastTranscript") }
    }

    var longestTranscriptWords: Int {
        get { defaults.integer(forKey: "\(prefix)longestWords") }
        set { defaults.set(newValue, forKey: "\(prefix)longestWords") }
    }

    private var todayKey: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }

    func recordSession(words: Int, durationSeconds: Double) {
        objectWillChange.send()
        totalWords += words
        totalSessions += 1
        totalRecordingSeconds += durationSeconds
        todayWords += words
        todaySessions += 1
        if words > longestTranscriptWords {
            longestTranscriptWords = words
        }
    }

    func reset() {
        objectWillChange.send()
        for key in ["totalWords", "totalSessions", "totalSeconds", "todayWords",
                    "todaySessions", "todayKey", "lastTranscript", "longestWords"] {
            defaults.removeObject(forKey: "\(prefix)\(key)")
        }
    }

    var averageWordsPerSession: Int {
        guard totalSessions > 0 else { return 0 }
        return totalWords / totalSessions
    }

    /// Speaking speed across all sessions — the headline number in the UI.
    var wordsPerMinute: Int {
        guard totalRecordingSeconds > 1 else { return 0 }
        return Int(Double(totalWords) / (totalRecordingSeconds / 60))
    }

    /// Time saved versus typing, assuming a 40 wpm keyboard pace.
    var minutesSaved: Int {
        let typingMinutes = Double(totalWords) / 40.0
        let spokenMinutes = totalRecordingSeconds / 60
        return max(0, Int(typingMinutes - spokenMinutes))
    }

    var formattedTotalTime: String {
        let total = Int(totalRecordingSeconds)
        let hours = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 { return "\(hours)h \(mins)m" }
        if mins > 0 { return "\(mins)m \(secs)s" }
        return "\(secs)s"
    }
}
