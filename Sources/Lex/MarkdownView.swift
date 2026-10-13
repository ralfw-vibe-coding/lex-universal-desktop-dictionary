import SwiftUI
import LexCore

/// Rendert Markdown-Blöcke; Inline-Formatierung (fett, kursiv, Code, Links) übernimmt AttributedString.
struct MarkdownView: View {
    let markdown: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(MarkdownBlocks.parse(markdown).enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            inline(text)
                .font(level == 1 ? .title2.bold() : level == 2 ? .title3.bold() : .headline)
                .padding(.top, level == 1 ? 2 : 6)
        case .paragraph(let text):
            inline(text).lineSpacing(2)
        case .bullet(let indent, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("•").foregroundStyle(.secondary)
                inline(text).lineSpacing(2)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .numbered(let indent, let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).").foregroundStyle(.secondary).monospacedDigit()
                inline(text).lineSpacing(2)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .quote(let text):
            inline(text)
                .font(.title3)
                .lineSpacing(3)
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.accentColor.opacity(0.6)).frame(width: 3)
                }
        case .code(let text):
            Text(text)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 6))
        case .rule:
            Divider()
        }
    }

    private func inline(_ text: String) -> Text {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        if let attributed = try? AttributedString(markdown: text, options: options) {
            return Text(attributed)
        }
        return Text(text)
    }
}
