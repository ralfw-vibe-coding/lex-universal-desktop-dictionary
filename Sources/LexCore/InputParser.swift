import Foundation

/// Was der Nutzer ins Eingabefeld getippt hat – rein syntaktisch zerlegt, ohne KI.
public enum ParsedInput: Equatable, Sendable {
    case command(Command)
    /// `en: ich gehe nach hause` → Übersetzung in die angegebene Sprache.
    case translate(text: String, languageCode: String, languageName: String)
    /// `ex: tat twam asi` → Erklärung erzwingen.
    case explain(text: String)
    /// Kein Präfix → Jev entscheidet.
    case open(text: String)
    case empty
}

public enum Command: Equatable, Sendable {
    case history, quit, key, help, settings
    /// `/chat claude` bzw. `/chat chatgpt`; ohne Argument → aktuelle Einstellung anzeigen.
    case chat(ChatService?)
    case unknown(String)
}

public enum InputParser {
    public static func parse(_ raw: String) -> ParsedInput {
        let input = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return .empty }

        switch input.lowercased() {
        case "/h", "/history", "/historie": return .command(.history)
        case "/q", "/quit", "/exit": return .command(.quit)
        case "/key": return .command(.key)
        case "/help", "/hilfe", "/?": return .command(.help)
        case "/settings", "/einstellungen", "/s": return .command(.settings)
        case "/chat": return .command(.chat(nil))
        default: break
        }
        if input.hasPrefix("/") {
            let parts = input.lowercased().split(separator: " ", maxSplits: 1).map(String.init)
            if parts[0] == "/chat", parts.count == 2, let service = ChatService(rawValue: parts[1].trimmingCharacters(in: .whitespaces)) {
                return .command(.chat(service))
            }
            return .command(.unknown(input))
        }

        guard let colon = input.firstIndex(of: ":") else { return .open(text: input) }
        let prefix = input[..<colon].lowercased()
        let rest = input[input.index(after: colon)...].trimmingCharacters(in: .whitespaces)
        guard !rest.isEmpty else { return .open(text: input) }

        if prefix == "ex" { return .explain(text: rest) }
        if let name = languageName(for: prefix) {
            return .translate(text: rest, languageCode: prefix, languageName: name)
        }
        return .open(text: input)
    }

    /// Nur zweibuchstabige ISO-639-1-Codes gelten als Präfix, damit z. B. "Hinweis: …" nicht kapert wird.
    static func languageName(for code: String) -> String? {
        guard code.count == 2, code.allSatisfy({ $0.isASCII && $0.isLetter }) else { return nil }
        guard Locale.LanguageCode(code).isISOLanguage else { return nil }
        return Locale(identifier: "de_DE").localizedString(forLanguageCode: code)
    }
}
