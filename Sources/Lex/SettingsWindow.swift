import AppKit
import SwiftUI
import LexCore

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show() {
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 640, height: 760),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered, defer: false)
            window.title = "Lex – Einstellungen"
            window.contentView = NSHostingView(rootView: SettingsView())
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate()
        window?.makeKeyAndOrderFront(nil)
    }
}

extension Notification.Name {
    static let lexConfigChanged = Notification.Name("LexConfigChanged")
}

@MainActor
final class SettingsModel: ObservableObject {
    @Published var config = LexConfig.load() {
        didSet {
            config.save()
            NotificationCenter.default.post(name: .lexConfigChanged, object: nil)
        }
    }
    @Published var newKey = ""
    /// Shortcut erst bei ENTER/Übernehmen anwenden – sonst würden Zwischenstände wie "cmd+s" global registriert.
    @Published var hotkeyDraft = LexConfig.load().hotkey ?? "cmd+shift+L"
    @Published var keyStatus: String?
    @Published var availableModels: [String] = []
    @Published var loginEnabled = LoginItem.isEnabled
    @Published var loginError: String?

    func setLogin(_ on: Bool) {
        do {
            try LoginItem.set(on)
            loginError = nil
        } catch {
            loginError = error.localizedDescription
        }
        loginEnabled = LoginItem.isEnabled
    }

    /// Hinweis, wenn der Login-Start auf eine andere Lex-Kopie zeigt oder Lex aus dem Entwicklungsordner läuft.
    var loginNote: String? {
        if let configured = LoginItem.configuredExecutable, configured != LoginItem.currentExecutable {
            return "Startet beim Login: \(configured.replacingOccurrences(of: "/Contents/MacOS/Lex", with: "")) – Aus- und wieder Einschalten startet diese Kopie."
        }
        if !LoginItem.runsFromApplications {
            return "Lex läuft aus \(Bundle.main.bundlePath) – besser erst mit ./build.sh install nach /Applications kopieren."
        }
        return nil
    }

    var hasKey: Bool { APIKey.load() != nil }

    /// Modelle für die Auswahlmenüs: gängige Anbieter, ohne Batch-/Bildvarianten.
    var modelsByProvider: [(provider: String, models: [String])] {
        let providers = ["anthropic", "openai", "google", "perplexity", "typesafe", "mistralai", "deepseek", "x-ai", "meta-llama"]
        let usable = availableModels.filter { !$0.contains(":") && !$0.hasPrefix("~") && !$0.contains("image") }
        return providers.compactMap { provider in
            let models = usable.filter { $0.hasPrefix(provider + "/") }
            return models.isEmpty ? nil : (provider, models)
        }
    }

    func loadModels() async {
        availableModels = (try? await OpenRouter.listModels()) ?? []
    }

    func isKnown(_ model: String) -> Bool {
        availableModels.isEmpty || availableModels.contains(model)
    }

    func modelBinding(_ kind: Kind) -> Binding<String> {
        Binding(get: { self.config.model(for: kind) },
                set: { self.config.models[kind.rawValue] = $0.trimmingCharacters(in: .whitespaces) })
    }

    func saveKey() {
        guard !newKey.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        keyStatus = APIKey.save(newKey) ? "Gespeichert." : "Konnte nicht gespeichert werden."
        newKey = ""
    }

    var hotkeyDraftValid: Bool { HotKeySpec.parse(hotkeyDraft) != nil }

    func applyHotkey() {
        guard hotkeyDraftValid else { return }
        config.hotkey = hotkeyDraft.trimmingCharacters(in: .whitespaces)
    }
}

struct SettingsView: View {
    @StateObject private var model = SettingsModel()

    /// Reihenfolge der Kategorien in den Einstellungen.
    private let kinds: [Kind] = [.translateToGerman, .translateFromGerman, .foreignWord, .explain,
                                 .languageQuestion, .factQuestion, .current, .general]

    var body: some View {
        Form {
            Section("Allgemein") {
                Toggle("Beim Login starten", isOn: Binding(get: { model.loginEnabled }, set: { model.setLogin($0) }))
                if let note = model.loginNote {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                }
                if let error = model.loginError {
                    Text(error).font(.caption).foregroundStyle(.orange)
                }
                Picker("Ausführlich nachfragen in", selection: Binding(
                    get: { model.config.chatService },
                    set: { model.config.chat = $0.rawValue })) {
                    ForEach(ChatService.allCases, id: \.self) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)

                LabeledContent("Shortcut zum Öffnen") {
                    HStack {
                        TextField("", text: $model.hotkeyDraft)
                            .frame(width: 180)
                            .onSubmit { model.applyHotkey() }
                        Button("Übernehmen") { model.applyHotkey() }
                            .disabled(!model.hotkeyDraftValid || model.hotkeyDraft == model.config.hotkey)
                        if !model.hotkeyDraftValid {
                            Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                                .help("Unbekannte Tastenkombination")
                        }
                    }
                }
                Text("z. B. cmd+shift+L, ctrl+alt+space, cmd+opt+K – gilt nach „Übernehmen“ sofort.")
                    .font(.caption).foregroundStyle(.secondary)

                LabeledContent("Panel leeren nach") {
                    HStack(spacing: 6) {
                        TextField("", value: Binding(get: { model.config.resetAfterSeconds ?? 60 },
                                                     set: { model.config.resetAfterSeconds = max(0, $0) }),
                                  format: .number)
                            .frame(width: 60)
                            .multilineTextAlignment(.trailing)
                        Stepper("", value: Binding(get: { model.config.resetAfterSeconds ?? 60 },
                                                   set: { model.config.resetAfterSeconds = max(0, $0) }),
                                in: 0...3600, step: 10)
                            .labelsHidden()
                        Text("Sekunden")
                    }
                }
                Text("Öffnest du Lex innerhalb dieser Zeit wieder, siehst du die letzte Frage und Antwort; danach ist das Panel leer. 0 = immer leer.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("OpenRouter-API-Key") {
                LabeledContent("Status", value: model.hasKey ? "vorhanden" : "fehlt")
                HStack {
                    SecureField("Neuen Key einfügen", text: $model.newKey)
                        .onSubmit { model.saveKey() }
                    Button("Speichern") { model.saveKey() }
                        .disabled(model.newKey.isEmpty)
                }
                if let status = model.keyStatus {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
                Link("Keys verwalten auf openrouter.ai", destination: URL(string: "https://openrouter.ai/keys")!)
                    .font(.caption)
            }

            Section {
                ForEach(kinds, id: \.self) { kind in
                    LabeledContent(settingsLabel(kind)) {
                        HStack(spacing: 4) {
                            TextField("", text: model.modelBinding(kind))
                            if !model.isKnown(model.config.model(for: kind)) {
                                Image(systemName: "exclamationmark.triangle").foregroundStyle(.orange)
                                    .help("Dieses Modell kennt OpenRouter nicht.")
                            }
                            modelMenu(for: kind)
                        }
                    }
                }
            } header: {
                Text("Modelle je Anfrageart")
            } footer: {
                Text("Modell-IDs von openrouter.ai/models. „typesafe/jev-router“ lässt Jev das Modell je Anfrage wählen.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Jev (Einordnung)") {
                LabeledContent("Modell") {
                    TextField("", text: Binding(get: { model.config.jevModel }, set: { model.config.jevModel = $0 }))
                }
                LabeledContent("Mindest-Sicherheit") {
                    HStack {
                        Slider(value: $model.config.minConfidence, in: 0...1, step: 0.05)
                        Text("\(Int(model.config.minConfidence * 100)) %").monospacedDigit().frame(width: 44)
                    }
                }
                Text("Darunter geht die Anfrage an den Allzweck-Prompt.").font(.caption).foregroundStyle(.secondary)
                LabeledContent("Schwelle „aktuelle Infos“") {
                    HStack {
                        Slider(value: $model.config.currentInfoThreshold, in: 0...1, step: 0.05)
                        Text("\(Int(model.config.currentInfoThreshold * 100)) %").monospacedDigit().frame(width: 44)
                    }
                }
                Text("Darüber werden Sach- und Begriffsfragen mit Websuche beantwortet.").font(.caption).foregroundStyle(.secondary)
            }

            Section("Dateien") {
                HStack {
                    Button("Prompts bearbeiten …") {
                        NSWorkspace.shared.open(Prompts.exportDefaults())
                    }
                    .help("Legt die eingebauten Prompts als .md-Dateien an (falls noch nicht vorhanden) und öffnet den Ordner. Geänderte Dateien gelten sofort; löschen stellt den eingebauten Prompt wieder her.")
                    Button("Konfigurationsordner") {
                        NSWorkspace.shared.open(LexConfig.directory)
                    }
                    Button("Historie im Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([HistoryStore.shared.fileURL])
                    }
                }
            }
        }
        .formStyle(.grouped)
        .task { await model.loadModels() }
    }

    private func settingsLabel(_ kind: Kind) -> String {
        switch kind {
        case .translateFromGerman: "Übersetzung aus dem Deutschen (en: …)"
        case .current: "Aktuelle Info (mit Websuche)"
        case .general: "Allgemein (wenn Jev unsicher ist)"
        default: kind.label
        }
    }

    private func modelMenu(for kind: Kind) -> some View {
        Menu {
            ForEach(model.modelsByProvider, id: \.provider) { group in
                Menu(group.provider) {
                    ForEach(group.models, id: \.self) { id in
                        Button(id) { model.config.models[kind.rawValue] = id }
                    }
                }
            }
            Divider()
            Button("Standard: \(LexConfig.defaults.model(for: kind))") {
                model.config.models[kind.rawValue] = LexConfig.defaults.model(for: kind)
            }
        } label: {
            Image(systemName: "chevron.down.circle")
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .disabled(model.availableModels.isEmpty)
    }
}
