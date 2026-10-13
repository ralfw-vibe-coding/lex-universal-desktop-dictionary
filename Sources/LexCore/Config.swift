import Foundation

/// Die Anfragearten, auf die Lex verzweigt. Jede hat einen eigenen Prompt und ein eigenes Modell.
public enum Kind: String, Codable, CaseIterable, Sendable {
    case translateFromGerman = "translate_from_german"  // nur per Präfix `xx:`
    case translateToGerman = "translate_to_german"
    case foreignWord = "foreign_word"
    case explain = "explain_concept"
    case languageQuestion = "language_question"
    case factQuestion = "fact_question"
    case current = "current_info"                       // Faktenfrage, die aktuelle Daten braucht
    case general = "general"                            // Fallback, wenn Jev unsicher ist

    public var label: String {
        switch self {
        case .translateFromGerman: "Übersetzung"
        case .translateToGerman: "Übersetzung ins Deutsche"
        case .foreignWord: "Wörterbuch"
        case .explain: "Erklärung"
        case .languageQuestion: "Sprachfrage"
        case .factQuestion: "Faktenfrage"
        case .current: "Aktuelle Info"
        case .general: "Allgemein"
        }
    }
}

public struct LexConfig: Codable, Sendable {
    /// Modell-IDs bei OpenRouter je Kategorie. "typesafe/jev-router" ist ebenfalls möglich.
    public var models: [String: String]
    public var jevModel: String
    /// Unterhalb dieser Jev-Konfidenz geht die Anfrage an den Allzweck-Prompt.
    public var minConfidence: Double
    /// Ab dieser Wahrscheinlichkeit gilt eine Anfrage als "braucht aktuelle Infos".
    public var currentInfoThreshold: Double
    /// Globaler Shortcut, z. B. "cmd+shift+L", "ctrl+alt+space".
    public var hotkey: String?
    /// Wohin "Ausführlich im Chat" führt: "claude" oder "chatgpt".
    public var chat: String?

    public var chatService: ChatService { chat.flatMap(ChatService.init(rawValue:)) ?? .claude }

    public static let defaults = LexConfig(
        models: [
            Kind.translateFromGerman.rawValue: "anthropic/claude-sonnet-5.5",
            Kind.translateToGerman.rawValue: "anthropic/claude-sonnet-5.5",
            Kind.foreignWord.rawValue: "anthropic/claude-sonnet-5.5",
            Kind.explain.rawValue: "anthropic/claude-sonnet-5.5",
            Kind.languageQuestion.rawValue: "anthropic/claude-sonnet-5.5",
            Kind.factQuestion.rawValue: "anthropic/claude-sonnet-5.5",
            Kind.current.rawValue: "perplexity/sonar-pro",
            Kind.general.rawValue: "anthropic/claude-sonnet-5.5",
        ],
        jevModel: "~typesafe/jev-latest",
        minConfidence: 0.35,
        currentInfoThreshold: 0.6,
        hotkey: "cmd+shift+L",
        chat: "claude"
    )

    public func model(for category: Kind) -> String {
        models[category.rawValue] ?? LexConfig.defaults.models[category.rawValue]!
    }

    // MARK: Laden

    public static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config/lex", directoryHint: .isDirectory)
    }

    /// Lädt `~/.config/lex/config.json`; legt sie beim ersten Start mit Standardwerten an.
    public static func load() -> LexConfig {
        let url = directory.appending(path: "config.json")
        if let data = try? Data(contentsOf: url),
           let config = try? JSONDecoder().decode(LexConfig.self, from: data) {
            return config
        }
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: directory.appending(path: "prompts"), withIntermediateDirectories: true)
            defaults.save()
        }
        return defaults
    }

    public func save() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try? FileManager.default.createDirectory(at: LexConfig.directory, withIntermediateDirectories: true)
        try? encoder.encode(self).write(to: LexConfig.directory.appending(path: "config.json"), options: .atomic)
    }
}
