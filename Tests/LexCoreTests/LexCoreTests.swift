import Testing
@testable import LexCore

@Suite struct InputParserTests {
    @Test func languagePrefix() {
        #expect(InputParser.parse("en: ich gehe nach hause")
                == .translate(text: "ich gehe nach hause", languageCode: "en", languageName: "Englisch"))
        #expect(InputParser.parse("FR:guten Morgen")
                == .translate(text: "guten Morgen", languageCode: "fr", languageName: "Französisch"))
    }

    @Test func explainPrefix() {
        #expect(InputParser.parse("ex: serendipity") == .explain(text: "serendipity"))
    }

    @Test func noPrefix() {
        #expect(InputParser.parse("the dog is barking") == .open(text: "the dog is barking"))
        #expect(InputParser.parse("Hinweis: Text") == .open(text: "Hinweis: Text"))
        #expect(InputParser.parse("xq: foo") == .open(text: "xq: foo"))
        #expect(InputParser.parse("en:") == .open(text: "en:"))
    }

    @Test func commands() {
        #expect(InputParser.parse("/h") == .command(.history))
        #expect(InputParser.parse("/q") == .command(.quit))
        #expect(InputParser.parse(" /exit ") == .command(.quit))
        #expect(InputParser.parse("/key") == .command(.key))
        #expect(InputParser.parse("   ") == .empty)
        #expect(InputParser.parse("/chat") == .command(.chat(nil)))
        #expect(InputParser.parse("/chat ChatGPT") == .command(.chat(.chatgpt)))
        #expect(InputParser.parse("/foo") == .command(.unknown("/foo")))
        #expect(InputParser.parse("/help") == .command(.help))
        #expect(InputParser.parse("/settings") == .command(.settings))
    }
}

@Suite struct RoutingPolicyTests {
    func c(_ intent: Kind, conf: Double, current: Double = 0) -> Classification {
        Classification(intent: intent, confidence: conf, probabilities: [:], currentInfo: current, milliseconds: 0)
    }

    @Test func confidentIntentIsUsed() {
        #expect(Lookup.category(for: c(.explain, conf: 0.9), config: .defaults) == .explain)
    }

    @Test func lowConfidenceFallsBack() {
        #expect(Lookup.category(for: c(.foreignWord, conf: 0.2), config: .defaults) == .general)
    }

    @Test func currentFactsGoToWebModel() {
        #expect(Lookup.category(for: c(.factQuestion, conf: 0.9, current: 0.8), config: .defaults) == .current)
        #expect(Lookup.category(for: c(.translateToGerman, conf: 0.9, current: 0.8), config: .defaults) == .translateToGerman)
    }
}

@Suite struct MarkdownBlocksTests {
    @Test func blocks() {
        let md = """
        # Titel
        **Kurz** gesagt.
        Zweite Zeile.

        > Zitat
        - eins
          - eingerückt
        2. zwei
        ```
        code
        ```
        """
        #expect(MarkdownBlocks.parse(md) == [
            .heading(level: 1, text: "Titel"),
            .paragraph("**Kurz** gesagt.\nZweite Zeile."),
            .quote("Zitat"),
            .bullet(indent: 0, text: "eins"),
            .bullet(indent: 1, text: "eingerückt"),
            .numbered(indent: 0, number: "2", text: "zwei"),
            .code("code"),
        ])
    }

    @Test func hashtagIsNotHeading() {
        #expect(MarkdownBlocks.parse("#nein") == [.paragraph("#nein")])
    }
}

@Suite struct DeepDiveTests {
    @Test func chatURLs() {
        #expect(ChatService.claude.url(prompt: "a b").absoluteString == "https://claude.ai/new?q=a%20b")
        #expect(ChatService.chatgpt.url(prompt: "x").absoluteString == "https://chatgpt.com/?q=x")
    }
}
