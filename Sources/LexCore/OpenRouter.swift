import Foundation

public struct OpenRouterError: LocalizedError, Sendable {
    public let message: String
    public var errorDescription: String? { message }
}

/// Dünner Client für die beiden OpenRouter-Schnittstellen, die Lex braucht:
/// die Decisions-API (Jev) und gestreamte Chat Completions.
public struct OpenRouter: Sendable {
    let apiKey: String
    let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    static let base = URL(string: "https://openrouter.ai/api")!

    func request(_ path: String, body: [String: Any]) throws -> URLRequest {
        var request = URLRequest(url: OpenRouter.base.appending(path: path))
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Lex", forHTTPHeaderField: "X-Title")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Alle Chat-Modelle bei OpenRouter (öffentlich, ohne Key).
    public static func listModels() async throws -> [String] {
        let (data, _) = try await URLSession.shared.data(from: base.appending(path: "v1/models"))
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let models = (json?["data"] as? [[String: Any]]) ?? []
        return models.compactMap { $0["id"] as? String }.sorted()
    }

    // MARK: Jev (Decisions-API)

    /// Stellt Jev Fragen über einen Zustand und liefert die rohen Antworten je Frage-ID.
    public func decide(model: String, state: [String: Any], questions: [String: Any]) async throws -> [String: Any] {
        let req = try request("alpha/decisions", body: ["model": model, "state": state, "questions": questions])
        let (data, response) = try await session.data(for: req)
        try OpenRouter.check(response, data: data)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let answers = json["answers"] as? [String: Any] else {
            throw OpenRouterError(message: "Unerwartete Antwort von Jev: \(String(decoding: data.prefix(300), as: UTF8.self))")
        }
        return answers
    }

    // MARK: Chat (gestreamt)

    public enum ChatEvent: Sendable {
        case model(String)
        case delta(String)
        case citations([String])
    }

    public func streamChat(model: String, system: String, user: String) -> AsyncThrowingStream<ChatEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let req = try request("v1/chat/completions", body: [
                        "model": model,
                        "stream": true,
                        "messages": [
                            ["role": "system", "content": system],
                            ["role": "user", "content": user],
                        ],
                    ])
                    let (bytes, response) = try await session.bytes(for: req)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        try OpenRouter.check(response, data: data)
                    }
                    var announcedModel = false
                    var citations: [String] = []
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }  // SSE-Kommentare (": OPENROUTER PROCESSING") ignorieren
                        let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                        if payload == "[DONE]" { break }
                        guard let json = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { continue }
                        if let error = json["error"] as? [String: Any] {
                            throw OpenRouterError(message: (error["message"] as? String) ?? "Fehler im Stream")
                        }
                        if !announcedModel, let m = json["model"] as? String {
                            continuation.yield(.model(m))
                            announcedModel = true
                        }
                        if let c = json["citations"] as? [String], c != citations {
                            citations = c
                        }
                        if let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String, !content.isEmpty {
                            continuation.yield(.delta(content))
                        }
                    }
                    if !citations.isEmpty { continuation.yield(.citations(citations)) }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static func check(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse, http.statusCode != 200 else { return }
        var message = String(decoding: data.prefix(500), as: UTF8.self)
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any], let m = error["message"] as? String {
            message = m
        }
        let hint = switch http.statusCode {
        case 401: " – API-Key ungültig? Mit /key neu setzen."
        case 402: " – Guthaben bei OpenRouter aufgebraucht?"
        default: ""
        }
        throw OpenRouterError(message: "OpenRouter \(http.statusCode): \(message)\(hint)")
    }
}
