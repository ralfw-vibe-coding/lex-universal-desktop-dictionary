import AppKit
import Carbon.HIToolbox
import LexCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let history = HistoryWindowController()
    private let settings = SettingsWindowController()
    private lazy var panel = LookupPanelController(
        openHistory: { [weak self] in self?.history.show() },
        openSettings: { [weak self] in self?.settings.show() })
    private var hotKey: HotKey?
    private var hotKeySpec: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = LexConfig.load()  // legt beim ersten Start ~/.config/lex/config.json an
        Self.installEditMenu()
        registerHotKey()
        NotificationCenter.default.addObserver(forName: .lexConfigChanged, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.registerHotKey() }
        }

        // Doppelklick / `open -a Lex` bei laufender App: AppKit ruft für Hintergrund-Apps
        // applicationShouldHandleReopen nicht zuverlässig auf – daher das Apple Event direkt abfangen.
        NSAppleEventManager.shared().setEventHandler(
            self, andSelector: #selector(handleReopen(_:withReply:)),
            forEventClass: AEEventClass(kCoreEventClass), andEventID: AEEventID(kAEReopenApplication))

        // Beim Login (LaunchAgent) still starten, sonst gleich das Panel zeigen.
        if CommandLine.arguments.contains("--settings") { settings.show() }
        else if !CommandLine.arguments.contains("--background") { panel.show() }
    }

    @objc func handleReopen(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        panel.show()
    }

    /// (Neu) registrieren, wenn sich der Shortcut in den Einstellungen ändert.
    private func registerHotKey() {
        let spec = LexConfig.load().hotkey ?? "cmd+shift+L"
        guard spec != hotKeySpec else { return }
        guard let parsed = HotKeySpec.parse(spec) else {
            if hotKey == nil { hotKey = HotKey(keyCode: kVK_ANSI_L, modifiers: cmdKey | shiftKey) { [weak self] in self?.panel.toggle() } }
            return
        }
        hotKeySpec = spec
        hotKey = nil
        hotKey = HotKey(keyCode: parsed.keyCode, modifiers: parsed.modifiers) { [weak self] in
            self?.panel.toggle()
        }
    }

    @objc func openSettings() { panel.hide(); settings.show() }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Unsichtbares Hauptmenü: Ohne es funktionieren ⌘C/⌘V/⌘A in Textfeldern nicht.
    static func installEditMenu() {
        let edit = NSMenu(title: "Bearbeiten")
        edit.addItem(withTitle: "Widerrufen", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Wiederholen", action: Selector(("redo:")), keyEquivalent: "Z")
        edit.addItem(.separator())
        edit.addItem(withTitle: "Ausschneiden", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Kopieren", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Einsetzen", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Alles auswählen", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let app = NSMenu(title: "Lex")
        app.addItem(withTitle: "Einstellungen …", action: #selector(AppDelegate.openSettings), keyEquivalent: ",")
        let window = NSMenu(title: "Fenster")
        window.addItem(withTitle: "Schließen", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let main = NSMenu()
        for submenu in [app, edit, window] {
            let item = NSMenuItem()
            item.submenu = submenu
            main.addItem(item)
        }
        NSApp.mainMenu = main
    }
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)  // kein Dock-Icon, kein Menüleisten-Eintrag
    app.run()
}
