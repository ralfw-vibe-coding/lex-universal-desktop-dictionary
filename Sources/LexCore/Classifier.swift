import Foundation

/// Jevs Einschätzung einer Anfrage ohne Präfix.
public struct Classification: Codable, Sendable {
    public let intent: Kind
    public let confidence: Double
    public let probabilities: [String: Double]
    /// Wahrscheinlichkeit, dass die Antwort aktuelle Daten braucht.
    public let currentInfo: Double
    public let milliseconds: Int
}

/// Fragt Jev in einem Aufruf (parallel): Was will der Nutzer? Braucht es aktuelle Infos?
/// Die Fragen sind auf Englisch formuliert – Jevs stärkste Sprache –, die Eingabe bleibt im Original.
public struct Classifier: Sendable {
    let client: OpenRouter
    let model: String

    public init(client: OpenRouter, model: String) {
        self.client = client
        self.model = model
    }

    static let intents: [Kind: String] = [
        .translateToGerman: "`user_input` is a sentence, phrase or longer text written in a language other than German, and the user wants it translated into German. Examples: 'the dog is barking', 'je ne sais pas ce que tu veux', 'how are you doing today'.",
        .foreignWord: "`user_input` is a single ordinary word or short everyday idiom from a language other than German (normal vocabulary, not a special concept or proper name), and the user wants its meaning and German equivalents like in a dictionary. Examples: 'serendipity', 'to bark', 'sobremesa', 'kick the bucket'.",
        .explain: "`user_input` names a concept, technical term, phenomenon, method, theory, tradition, work or person – in German or in any other language – and the user wants it explained like an encyclopedia article. Examples: 'Gewaltenteilung', 'holotropes Atmen', 'tat twam asi', 'Quantenverschränkung', 'Wu wei', 'Kategorischer Imperativ'.",
        .languageQuestion: "`user_input` asks about correct language usage: spelling, grammar, inflection, punctuation, word choice, or the difference between similar words or forms. Examples: 'gewunken oder gewinkt', 'das oder dass', 'Unterschied scheinbar anscheinend', 'Plural von Status'.",
        .factQuestion: "`user_input` asks a concrete factual question that has a short, definite answer such as a number, date, name or place. Examples: 'wie hoch ist die Zugspitze', 'wann starb Goethe', 'Hauptstadt von Australien', 'wie viele Einwohner hat Hamburg'.",
    ]

    var questions: [String: Any] {
        [
            "intent": [
                "type": "choice",
                "instructions": "A German-speaking user typed `user_input` into a desktop lookup tool that translates and explains things. What does the user want?",
                "criteria": Dictionary(uniqueKeysWithValues: Classifier.intents.map { ($0.key.rawValue, $0.value) }),
            ],
            "current_info": [
                "type": "noul",
                "instructions": "Does a correct answer to `user_input` depend on up-to-date information that may have changed within the last year (current events, people currently in office, prices, exchange rates, recent releases, schedules, weather, sports results)?",
                "criteria": [
                    "true": "The answer depends on recent or changing information.",
                    "false": "The answer is stable knowledge, a translation, a definition, or a language rule.",
                ],
            ],
        ]
    }

    public func classify(_ text: String) async throws -> Classification {
        let start = Date()
        let answers = try await client.decide(model: model, state: ["user_input": text], questions: questions)
        let ms = Int(Date().timeIntervalSince(start) * 1000)

        guard let intent = answers["intent"] as? [String: Any],
              let choice = intent["choice"] as? String,
              let category = Kind(rawValue: choice) else {
            throw OpenRouterError(message: "Jev lieferte keine Kategorie: \(answers)")
        }
        let current = (answers["current_info"] as? [String: Any])?["noul"] as? Double ?? 0
        return Classification(
            intent: category,
            confidence: (intent["confidence"] as? Double) ?? 0,
            probabilities: (intent["probabilities"] as? [String: Double]) ?? [:],
            currentInfo: current,
            milliseconds: ms
        )
    }
}
