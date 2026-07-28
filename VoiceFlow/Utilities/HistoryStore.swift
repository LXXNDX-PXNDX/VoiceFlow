import Foundation

struct Transcript: Identifiable, Codable, Equatable {
    let id: UUID
    let text: String
    let date: Date
    let durationSeconds: Double
    let appName: String?

    var wordCount: Int {
        text.split(whereSeparator: { $0 == " " || $0 == "\n" }).count
    }

    init(id: UUID = UUID(), text: String, date: Date = Date(), durationSeconds: Double, appName: String?) {
        self.id = id
        self.text = text
        self.date = date
        self.durationSeconds = durationSeconds
        self.appName = appName
    }
}

/// Keeps the recent transcripts on disk so they survive a restart.
final class HistoryStore: ObservableObject {
    static let shared = HistoryStore()

    @Published private(set) var items: [Transcript] = []

    private let maxItems = 300
    private let fileURL: URL

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = appSupport.appendingPathComponent("VoiceFlow", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("history.json")
        items = load()
    }

    func add(_ transcript: Transcript) {
        items.insert(transcript, at: 0)
        if items.count > maxItems {
            items.removeLast(items.count - maxItems)
        }
        persist()
    }

    func delete(_ transcript: Transcript) {
        items.removeAll { $0.id == transcript.id }
        persist()
    }

    func clear() {
        items.removeAll()
        persist()
    }

    private func load() -> [Transcript] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([Transcript].self, from: data)) ?? []
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        do {
            let data = try encoder.encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            NSLog("[History] Could not save: \(error.localizedDescription)")
        }
    }
}
