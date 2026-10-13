import Foundation

/// Fortschrittsereignisse einer Anfrage – die UI zeigt sie nacheinander an.
public enum LookupEvent: Sendable {
    case classifying
    case classified(Classification)
    case routed(Route)
    case model(String)
    case delta(String)
}

/// Wohin eine Anfrage geht und warum.
public struct Route: Codable, Sendable {
    public let category: Kind
    public let model: String
    /// "prefix" (vom Nutzer erzwungen), "jev" oder "fallback" (Jev unsicher).
    public let reason: String
    public let languageName: String?
}

/// Verbindet Eingabe → Kategorie → Prompt + Modell → gestreamte Antwort.
public struct Lookup: Sendable {
    let client: OpenRouter
    let config: LexConfig

    public init(apiKey: String, config: LexConfig) {
        self.client = OpenRouter(apiKey: apiKey)
        self.config = config
    }

    public func run(_ input: ParsedInput) -> AsyncThrowingStream<LookupEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (text, route) = try await route(input, emit: { continuation.yield($0) })
                    continuation.yield(.routed(route))

                    let system = Prompts.system(for: route.category, languageName: route.languageName)
                    var citations: [String] = []
                    for try await event in client.streamChat(model: route.model, system: system, user: text) {
                        switch event {
                        case .model(let m): continuation.yield(.model(m))
                        case .delta(let d): continuation.yield(.delta(d))
                        case .citations(let c): citations = c
                        }
                    }
                    if !citations.isEmpty {
                        let list = citations.enumerated().map { "\($0.offset + 1). <\($0.element)>" }.joined(separator: "\n")
                        continuation.yield(.delta("\n\n## Quellen\n\(list)\n"))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func route(_ input: ParsedInput, emit: (LookupEvent) -> Void) async throws -> (String, Route) {
        switch input {
        case .translate(let text, _, let name):
            return (text, Route(category: .translateFromGerman, model: config.model(for: .translateFromGerman), reason: "prefix", languageName: name))
        case .explain(let text):
            return (text, Route(category: .explain, model: config.model(for: .explain), reason: "prefix", languageName: nil))
        case .open(let text):
            emit(.classifying)
            let c = try await Classifier(client: client, model: config.jevModel).classify(text)
            emit(.classified(c))
            let category = Lookup.category(for: c, config: config)
            let reason = category == .general ? "fallback" : "jev"
            return (text, Route(category: category, model: config.model(for: category), reason: reason, languageName: nil))
        case .command, .empty:
            throw OpenRouterError(message: "Nichts nachzuschlagen.")
        }
    }

    /// Reine Routing-Politik – getrennt, damit sie ohne Netz testbar ist.
    public static func category(for c: Classification, config: LexConfig) -> Kind {
        if c.currentInfo >= config.currentInfoThreshold, c.intent == .factQuestion || c.intent == .explain {
            return .current
        }
        if c.confidence < config.minConfidence { return .general }
        return c.intent
    }
}
