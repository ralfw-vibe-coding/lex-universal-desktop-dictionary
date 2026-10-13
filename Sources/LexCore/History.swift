import Foundation

public struct HistoryEntry: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let date: Date
    public let input: String
    public let category: Kind
    public let model: String
    /// "prefix", "jev" oder "fallback"
    public let reason: String
    public let jevConfidence: Double?
    public let jevCurrentInfo: Double?
    public let jevMilliseconds: Int?
    public let totalMilliseconds: Int
    public let answer: String
    public let error: String?

    public init(input: String, route: Route, classification: Classification?, model: String,
                totalMilliseconds: Int, answer: String, error: String?) {
        self.id = UUID()
        self.date = Date()
        self.input = input
        self.category = route.category
        self.model = model
        self.reason = route.reason
        self.jevConfidence = classification?.confidence
        self.jevCurrentInfo = classification?.currentInfo
        self.jevMilliseconds = classification?.milliseconds
        self.totalMilliseconds = totalMilliseconds
        self.answer = answer
        self.error = error
    }
}

/// Historie als JSON-Datei in `~/Library/Application Support/Lex/history.json`.
public final class HistoryStore: @unchecked Sendable {
    public static let shared = HistoryStore()

    private let url: URL
    private let queue = DispatchQueue(label: "lex.history")
    private var cache: [HistoryEntry]?

    public init(url: URL? = nil) {
        self.url = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "Lex/history.json")
    }

    /// Neueste zuerst.
    public func all() -> [HistoryEntry] {
        queue.sync { loaded() }
    }

    public func append(_ entry: HistoryEntry) {
        queue.sync {
            var entries = loaded()
            entries.insert(entry, at: 0)
            save(entries)
        }
    }

    public func delete(_ ids: Set<UUID>) {
        queue.sync { save(loaded().filter { !ids.contains($0.id) }) }
    }

    private func loaded() -> [HistoryEntry] {
        if let cache { return cache }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let entries = (try? Data(contentsOf: url)).flatMap { try? decoder.decode([HistoryEntry].self, from: $0) } ?? []
        cache = entries
        return entries
    }

    private func save(_ entries: [HistoryEntry]) {
        cache = entries
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? encoder.encode(entries).write(to: url, options: .atomic)
    }
}
