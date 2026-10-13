import Foundation
import LexCore

// lex-eval routing [datei.json]   – misst, wie gut Jev die Testfälle einordnet
// lex-eval ask "eingabe"          – kompletter Durchlauf im Terminal (Route + gestreamte Antwort)

struct Case: Decodable {
    let input: String
    let expected: Kind
    let current: Bool?
}

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data((message + "\n").utf8))
    exit(1)
}

guard let key = APIKey.load() else { fail("OPENROUTER_API_KEY ist nicht gesetzt.") }
let config = LexConfig.load()
let args = Array(CommandLine.arguments.dropFirst())

switch args.first {
case "routing":
    let path = args.count > 1 ? args[1] : "Evals/routing.json"
    guard let data = FileManager.default.contents(atPath: path),
          let cases = try? JSONDecoder().decode([Case].self, from: data) else { fail("Kann \(path) nicht lesen.") }
    let classifier = Classifier(client: OpenRouter(apiKey: key), model: config.jevModel)

    let results = try await withThrowingTaskGroup(of: (Int, Classification).self) { group in
        for (i, c) in cases.enumerated() {
            group.addTask { (i, try await classifier.classify(c.input)) }
        }
        var out = [Classification?](repeating: nil, count: cases.count)
        for try await (i, r) in group { out[i] = r }
        return out.map { $0! }
    }

    var hits = 0, currentHits = 0, currentTotal = 0
    for (c, r) in zip(cases, results) {
        let routed = Lookup.category(for: r, config: config)
        let ok = r.intent == c.expected
        if ok { hits += 1 }
        var currentMark = ""
        if let expectCurrent = c.current {
            currentTotal += 1
            let got = r.currentInfo >= config.currentInfoThreshold
            if got == expectCurrent { currentHits += 1 } else { currentMark = "  ⚠︎ aktuell=\(String(format: "%.2f", r.currentInfo))" }
        }
        let line = String(format: "%@ %-32@ %-20@ → %-20@ conf %.2f  akt %.2f  %4d ms  → %@%@",
                          ok ? "✓" : "✗", String(c.input.prefix(32)) as NSString, c.expected.rawValue as NSString,
                          r.intent.rawValue as NSString, r.confidence, r.currentInfo, r.milliseconds,
                          routed.rawValue as NSString, currentMark as NSString)
        print(line)
    }
    let ms = results.map(\.milliseconds).sorted()
    print("\nKategorie: \(hits)/\(cases.count) richtig (\(hits * 100 / max(cases.count, 1)) %)")
    if currentTotal > 0 { print("Aktuelle Infos: \(currentHits)/\(currentTotal) richtig") }
    print("Jev-Latenz (parallel gemessen): Median \(ms[ms.count / 2]) ms, max \(ms.last!) ms")

case "ask":
    let text = args.dropFirst().joined(separator: " ")
    let parsed = InputParser.parse(text)
    let start = Date()
    var firstToken: Date?
    for try await event in Lookup(apiKey: key, config: config).run(parsed) {
        switch event {
        case .classifying: print("[Jev ordnet ein …]")
        case .classified(let c): print("[Jev: \(c.intent.rawValue) conf \(String(format: "%.2f", c.confidence)) aktuell \(String(format: "%.2f", c.currentInfo)) – \(c.milliseconds) ms]")
        case .routed(let r): print("[Route: \(r.category.rawValue) → \(r.model) (\(r.reason))]\n")
        case .model(let m): FileHandle.standardError.write(Data("[Modell laut Stream: \(m)]\n".utf8))
        case .delta(let d):
            if firstToken == nil { firstToken = Date() }
            print(d, terminator: ""); fflush(stdout)
        }
    }
    let total = Date().timeIntervalSince(start)
    let ttft = firstToken.map { $0.timeIntervalSince(start) } ?? total
    print(String(format: "\n\n[erstes Token nach %.1f s, fertig nach %.1f s]", ttft, total))

default:
    fail("Aufruf: lex-eval routing [Evals/routing.json] | lex-eval ask \"eingabe\"")
}
