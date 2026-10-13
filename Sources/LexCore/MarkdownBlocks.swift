import Foundation

/// Minimaler Block-Parser für Markdown. SwiftUI rendert nur Inline-Markdown;
/// Überschriften, Listen, Zitate und Codeblöcke zerlegen wir hier selbst.
public enum MarkdownBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case bullet(indent: Int, text: String)
    case numbered(indent: Int, number: String, text: String)
    case quote(String)
    case code(String)
    case rule
}

public enum MarkdownBlocks {
    public static func parse(_ markdown: String) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var paragraph: [String] = []
        var quote: [String] = []
        var code: [String]? = nil

        func flush() {
            if !paragraph.isEmpty { blocks.append(.paragraph(paragraph.joined(separator: "\n"))); paragraph = [] }
            if !quote.isEmpty { blocks.append(.quote(quote.joined(separator: "\n"))); quote = [] }
        }

        for raw in markdown.components(separatedBy: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)

            if line.hasPrefix("```") {
                if let c = code { blocks.append(.code(c.joined(separator: "\n"))); code = nil }
                else { flush(); code = [] }
                continue
            }
            if code != nil { code!.append(raw); continue }

            if line.isEmpty { flush(); continue }

            let indent = (raw.prefix { $0 == " " || $0 == "\t" }.count) / 2

            if line.hasPrefix(">") {
                if !paragraph.isEmpty { flush() }
                quote.append(String(line.dropFirst()).trimmingCharacters(in: .whitespaces))
                continue
            }
            if !quote.isEmpty { flush() }

            if let hashes = line.firstIndex(where: { $0 != "#" }), line.hasPrefix("#"),
               line[hashes] == " " {
                flush()
                let level = line.distance(from: line.startIndex, to: hashes)
                blocks.append(.heading(level: level, text: String(line[hashes...]).trimmingCharacters(in: .whitespaces)))
            } else if line == "---" || line == "***" || line == "___" {
                flush(); blocks.append(.rule)
            } else if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                flush(); blocks.append(.bullet(indent: indent, text: String(line.dropFirst(2))))
            } else if let dot = line.firstIndex(where: { !$0.isNumber }), dot != line.startIndex,
                      line[dot] == "." || line[dot] == ")",
                      line[line.index(after: dot)...].hasPrefix(" ") {
                flush()
                blocks.append(.numbered(indent: indent, number: String(line[..<dot]),
                                        text: String(line[line.index(after: dot)...]).trimmingCharacters(in: .whitespaces)))
            } else {
                paragraph.append(line)
            }
        }
        if let c = code { blocks.append(.code(c.joined(separator: "\n"))) }
        flush()
        return blocks
    }
}
