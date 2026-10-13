import SwiftUI
import LexCore

struct LookupView: View {
    @ObservedObject var model: LookupModel
    /// Größte Höhe, die der Antwortbereich einnehmen darf (vom Panel je nach Bildschirm gesetzt).
    var maxAnswerHeight: CGFloat
    var onHeightChange: (CGFloat) -> Void

    @FocusState private var focused: Bool
    @State private var answerHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            inputRow
            if model.hasOutput {
                Divider()
                StatusRow(model: model)
                if !model.answer.isEmpty {
                    Divider()
                    ScrollView {
                        MarkdownView(markdown: model.answer)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .onGeometryChange(for: CGFloat.self, of: \.size.height) { answerHeight = $0 }
                    }
                    .frame(height: min(answerHeight, maxAnswerHeight))
                }
            }
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { onHeightChange($0) }
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
        .onReceive(NotificationCenter.default.publisher(for: .lexFocusInput)) { _ in
            focused = true
            DispatchQueue.main.async { NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil) }
        }
    }

    private var inputRow: some View {
        HStack(spacing: 12) {
            Image(systemName: model.phase == .enterKey ? "key.fill" : "text.magnifyingglass")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.secondary)
            Group {
                if model.phase == .enterKey {
                    SecureField("OpenRouter-API-Key einfügen, dann ENTER", text: $model.input)
                } else {
                    TextField("en: Satz übersetzen · fremden Text eingeben · Begriff nachschlagen · ex: erklären", text: $model.input)
                }
            }
            .textFieldStyle(.plain)
            .font(.system(size: 22))
            .focused($focused)
            .onSubmit { model.submit() }
            if model.isBusy {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 58)
    }
}

/// Zeigt, was gerade passiert: Jev ordnet ein → Kategorie/Modell → schreibt → fertig.
struct StatusRow: View {
    @ObservedObject var model: LookupModel

    var body: some View {
        HStack(spacing: 8) {
            icon
            Text(text).lineLimit(isFailed ? 4 : 1).truncationMode(.middle)
            Spacer(minLength: 8)
            if model.isBusy, let start = model.startedAt {
                TimelineView(.periodic(from: start, by: 0.1)) { context in
                    Text(seconds(context.date.timeIntervalSince(start))).monospacedDigit()
                }
            } else if let duration = model.duration {
                Text(seconds(duration)).monospacedDigit()
            }
            if model.phase == .done, !model.answer.isEmpty {
                Button { model.openDeepDive() } label: {
                    Label("Ausführlich in \(model.chatService.name)", systemImage: "arrow.up.right.square")
                }
                .buttonStyle(.link)
                .help("Frage im Browser für eine ausführliche Antwort öffnen (⌘↩)")
                Button { model.copyAnswer() } label: { Image(systemName: "doc.on.doc") }
                    .buttonStyle(.borderless)
                    .help("Antwort kopieren (⌘⇧C)")
                    .keyboardShortcut("c", modifiers: [.command, .shift])
            }
        }
        .font(.callout)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        .frame(minHeight: 30)
    }

    private var isFailed: Bool { if case .failed = model.phase { true } else { false } }

    @ViewBuilder private var icon: some View {
        switch model.phase {
        case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        case .done: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .enterKey: Image(systemName: "key")
        case .idle: Image(systemName: "info.circle")
        default: Image(systemName: "sparkles").symbolEffect(.pulse)
        }
    }

    private var routeText: String {
        guard let route = model.route else { return "" }
        var parts = [route.category.label]
        if let lang = route.languageName, route.category == .translateFromGerman { parts[0] += " → \(lang)" }
        parts.append(model.model ?? route.model)
        if let c = model.classification {
            parts.append("Jev \(Int((c.confidence * 100).rounded())) %" + (route.reason == "fallback" ? " (unsicher)" : ""))
        } else if route.reason == "prefix" {
            parts.append("Präfix")
        }
        return parts.joined(separator: " · ")
    }

    private var text: String {
        if let notice = model.notice { return notice }
        switch model.phase {
        case .idle: return ""
        case .enterKey: return "Lex braucht einen OpenRouter-API-Key (openrouter.ai/keys). Er wird im Schlüsselbund gespeichert."
        case .classifying: return "Jev ordnet die Anfrage ein …"
        case .waiting: return routeText + " · wartet auf Antwort …"
        case .streaming: return routeText + " · schreibt …"
        case .done: return routeText
        case .failed(let message): return message
        }
    }

    private func seconds(_ t: TimeInterval) -> String {
        String(format: "%.1f s", t).replacingOccurrences(of: ".", with: ",")
    }
}

extension Notification.Name {
    static let lexFocusInput = Notification.Name("LexFocusInput")
}
