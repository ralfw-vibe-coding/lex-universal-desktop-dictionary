import AppKit
import SwiftUI
import LexCore

@MainActor
final class HistoryWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1000, height: 680),
                styleMask: [.titled, .closable, .resizable, .miniaturizable, .fullSizeContentView],
                backing: .buffered, defer: false)
            window.title = "Lex – Historie"
            window.contentView = NSHostingView(rootView: HistoryView())
            window.isReleasedWhenClosed = false
            window.setFrameAutosaveName("LexHistory")
            if !window.setFrameUsingName("LexHistory") { window.center() }
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

final class HistoryModel: ObservableObject {
    @Published var entries: [HistoryEntry] = []
    @Published var search = ""
    @Published var selection: UUID?

    init() {
        reload()
        NotificationCenter.default.addObserver(forName: .lexHistoryChanged, object: nil, queue: .main) { [weak self] _ in
            self?.reload()
        }
    }

    func reload() {
        entries = HistoryStore.shared.all()
        if selection == nil { selection = entries.first?.id }
    }

    var filtered: [HistoryEntry] {
        let q = search.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return entries }
        return entries.filter { $0.input.localizedCaseInsensitiveContains(q) || $0.answer.localizedCaseInsensitiveContains(q) }
    }

    var selected: HistoryEntry? { entries.first { $0.id == selection } }

    func delete(_ id: UUID) {
        HistoryStore.shared.delete([id])
        if selection == id { selection = nil }
        reload()
    }
}

struct HistoryView: View {
    @StateObject private var model = HistoryModel()

    var body: some View {
        NavigationSplitView {
            List(model.filtered, selection: $model.selection) { entry in
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.input).lineLimit(1).fontWeight(.medium)
                    HStack(spacing: 6) {
                        Text(entry.category.label)
                        Text("·")
                        Text(entry.date, format: .relative(presentation: .named))
                    }
                    .font(.caption)
                    .foregroundStyle(entry.error == nil ? Color.secondary : Color.orange)
                }
                .padding(.vertical, 2)
                .contextMenu {
                    Button("Löschen", role: .destructive) { model.delete(entry.id) }
                }
            }
            .searchable(text: $model.search, placement: .sidebar, prompt: "Historie durchsuchen")
            .navigationSplitViewColumnWidth(min: 240, ideal: 300)
            .overlay {
                if model.entries.isEmpty {
                    ContentUnavailableView("Noch keine Anfragen", systemImage: "clock",
                                           description: Text("⌘⇧L öffnet Lex."))
                }
            }
        } detail: {
            if let entry = model.selected {
                HistoryDetail(entry: entry, onDelete: { model.delete(entry.id) })
                    .id(entry.id)
            } else {
                Text("Eintrag auswählen").foregroundStyle(.secondary)
            }
        }
        .onDeleteCommand { if let id = model.selection { model.delete(id) } }
    }
}

struct HistoryDetail: View {
    let entry: HistoryEntry
    let onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(entry.input)
                    .font(.title.weight(.semibold))
                    .textSelection(.enabled)
                Text(meta)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                if let error = entry.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                }
                Divider()
                MarkdownView(markdown: entry.answer)
            }
            .padding(24)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .toolbar {
            Button {
                let service = LexConfig.load().chatService
                let text = InputParser.parse(entry.input).lookupText ?? entry.input
                let language: String? = if case .translate(_, _, let name) = InputParser.parse(entry.input) { name } else { nil }
                NSWorkspace.shared.open(service.url(prompt: DeepDive.prompt(input: text, kind: entry.category, languageName: language)))
            } label: { Label("Ausführlich im Chat", systemImage: "arrow.up.right.square") }
            .help("Im Browser bei Claude bzw. ChatGPT ausführlich nachfragen")
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.answer, forType: .string)
            } label: { Label("Antwort kopieren", systemImage: "doc.on.doc") }
            Button(role: .destructive, action: onDelete) { Label("Löschen", systemImage: "trash") }
        }
    }

    private var meta: String {
        var parts = [entry.date.formatted(date: .abbreviated, time: .shortened), entry.category.label, entry.model]
        switch entry.reason {
        case "prefix": parts.append("per Präfix")
        case "fallback": parts.append("Jev unsicher → Allzweck")
        default: break
        }
        if let c = entry.jevConfidence { parts.append("Jev \(Int((c * 100).rounded())) %") }
        if let ms = entry.jevMilliseconds { parts.append("Jev \(ms) ms") }
        parts.append(String(format: "%.1f s gesamt", Double(entry.totalMilliseconds) / 1000))
        return parts.joined(separator: " · ")
    }
}
