import Foundation

/// Der Chat, in dem eine Anfrage ausführlich weiterverfolgt wird.
public enum ChatService: String, Codable, CaseIterable, Sendable {
    case claude, chatgpt

    public var name: String {
        switch self {
        case .claude: "Claude"
        case .chatgpt: "ChatGPT"
        }
    }

    /// Öffnet einen neuen Chat mit vorausgefüllter Frage.
    public func url(prompt: String) -> URL {
        var components = URLComponents(string: self == .claude ? "https://claude.ai/new" : "https://chatgpt.com/")!
        components.queryItems = [URLQueryItem(name: "q", value: prompt)]
        return components.url!
    }
}

/// Formuliert aus der Lex-Anfrage eine Frage für eine ausführliche Antwort im Chat.
public enum DeepDive {
    public static func prompt(input: String, kind: Kind, languageName: String? = nil) -> String {
        switch kind {
        case .translateFromGerman:
            "Übersetze (Zielsprache: \(languageName ?? "Englisch")) und erkläre ausführlich Wortwahl, Varianten, Grammatik und Stolperfallen:\n\n\(input)"
        case .translateToGerman:
            "Übersetze ins Deutsche und erkläre ausführlich Wortformen, Grammatik, Redewendungen und Nuancen des Originals:\n\n\(input)"
        case .foreignWord:
            "Erkläre das Wort „\(input)“ ausführlich wie ein großes Wörterbuch: Bedeutungen mit deutschen Entsprechungen, Beispiele, Etymologie, Gebrauch und Synonyme."
        case .explain:
            "Erkläre „\(input)“ ausführlich wie ein guter Lexikonartikel: Definition, Herkunft, Kernidee, Hintergrund und Geschichte, Beispiele, Kritik und Abgrenzung, verwandte Begriffe."
        case .languageQuestion:
            "Sprachfrage zum Deutschen – bitte ausführlich mit Regel, Beispielen, Ausnahmen und Herkunft beantworten: \(input)"
        case .factQuestion, .current:
            "\(input)\n\nBitte ausführlich beantworten, mit Hintergrund und Quellen."
        case .general:
            "\(input)\n\nBitte ausführlich erklären."
        }
    }
}
