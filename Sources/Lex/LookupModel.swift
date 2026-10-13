import AppKit
import LexCore

/// Zustand des Nachschlage-Panels.
@MainActor
final class LookupModel: ObservableObject {
    enum Phase: Equatable {
        case idle
        case classifying
        case waiting      // Route steht, erstes Token noch nicht da
        case streaming
        case done
        case failed(String)
        case enterKey
    }

    @Published var input = ""
    @Published var phase: Phase = .idle
    @Published var answer = ""
    @Published var route: Route?
    @Published var classification: Classification?
    @Published var model: String?
    @Published var startedAt: Date?
    @Published var duration: TimeInterval?
    @Published var notice: String?
    private(set) var lastQuery = ""

    var onOpenHistory: () -> Void = {}
    private var task: Task<Void, Never>?

    var isBusy: Bool { [.classifying, .waiting, .streaming].contains(phase) }
    var hasOutput: Bool { phase != .idle || notice != nil }

    func prepare() {
        if APIKey.load() == nil { askForKey() }
    }

    func askForKey() {
        input = ""
        notice = nil
        phase = .enterKey
    }

    func submit() {
        if phase == .enterKey { return saveKey() }

        switch InputParser.parse(input) {
        case .empty: return
        case .command(.quit): NSApp.terminate(nil)
        case .command(.history): input = ""; onOpenHistory()
        case .command(.key): askForKey()
        case .command(.chat(let service)): setChat(service)
        case .command(.unknown(let text)): notice = "Unbekannter Befehl \(text) – möglich: /h, /chat claude|chatgpt, /key, /q"
        case let parsed: start(parsed)
        }
    }

    private func saveKey() {
        let key = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return }
        input = ""
        if APIKey.save(key) {
            phase = .idle
            notice = "API-Key im Schlüsselbund gespeichert. Los geht's."
        } else {
            phase = .failed("API-Key konnte nicht im Schlüsselbund gespeichert werden.")
        }
    }

    private func start(_ parsed: ParsedInput) {
        guard let key = APIKey.load() else { return askForKey() }
        task?.cancel()

        let query = input.trimmingCharacters(in: .whitespacesAndNewlines)
        lastQuery = query
        let lookup = Lookup(apiKey: key, config: LexConfig.load())
        let begin = Date()

        answer = ""
        route = nil
        classification = nil
        model = nil
        notice = nil
        duration = nil
        startedAt = begin
        phase = parsed.isOpen ? .classifying : .waiting

        task = Task {
            var failure: String?
            do {
                for try await event in lookup.run(parsed) {
                    switch event {
                    case .classifying: phase = .classifying
                    case .classified(let c): classification = c
                    case .routed(let r): route = r; model = r.model; phase = .waiting
                    case .model(let m): model = m
                    case .delta(let d): answer += d; phase = .streaming
                    }
                }
                phase = .done
            } catch is CancellationError {
                return
            } catch {
                failure = error.localizedDescription
                phase = .failed(failure!)
            }
            duration = Date().timeIntervalSince(begin)
            if let route {
                HistoryStore.shared.append(HistoryEntry(
                    input: query, route: route, classification: classification, model: model ?? route.model,
                    totalMilliseconds: Int(duration! * 1000), answer: answer, error: failure))
                NotificationCenter.default.post(name: .lexHistoryChanged, object: nil)
            }
        }
    }

    private func setChat(_ service: ChatService?) {
        input = ""
        var config = LexConfig.load()
        if let service {
            config.chat = service.rawValue
            config.save()
        }
        phase = .idle
        notice = "Ausführliche Antworten öffnen in \(config.chatService.name). Umschalten mit /chat claude oder /chat chatgpt."
    }

    var chatService: ChatService { LexConfig.load().chatService }

    /// Öffnet die Anfrage im eingestellten Chat für eine ausführliche Antwort.
    func openDeepDive() {
        guard let route, !lastQuery.isEmpty else { return }
        let text = InputParser.parse(lastQuery).lookupText ?? lastQuery
        let prompt = DeepDive.prompt(input: text, kind: route.category, languageName: route.languageName)
        NSWorkspace.shared.open(chatService.url(prompt: prompt))
    }

    func copyAnswer() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(answer, forType: .string)
        notice = "Kopiert."
        Task { try? await Task.sleep(for: .seconds(1.5)); if notice == "Kopiert." { notice = nil } }
    }
}

extension ParsedInput {
    var isOpen: Bool { if case .open = self { true } else { false } }

    /// Der eigentliche Nachschlagetext ohne Präfix.
    var lookupText: String? {
        switch self {
        case .translate(let text, _, _), .explain(let text), .open(let text): text
        default: nil
        }
    }
}

extension Notification.Name {
    static let lexHistoryChanged = Notification.Name("LexHistoryChanged")
}
