import AppKit
import Carbon.HIToolbox
import LexCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let history = HistoryWindowController()
    private lazy var panel = LookupPanelController(openHistory: { [weak self] in self?.history.show() })
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let config = LexConfig.load()  // legt beim ersten Start ~/.config/lex/config.json an
        Self.installEditMenu()
        let spec = HotKeySpec.parse(config.hotkey ?? "") ?? (kVK_ANSI_L, cmdKey | shiftKey)
        hotKey = HotKey(keyCode: spec.keyCode, modifiers: spec.modifiers) { [weak self] in
            self?.panel.toggle()
        }
        if CommandLine.arguments.contains("--show") { panel.show() }
    }

    /// Erneutes Öffnen der App (Doppelklick, `open -a Lex`) zeigt das Panel.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        panel.show()
        return false
    }

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
        let window = NSMenu(title: "Fenster")
        window.addItem(withTitle: "Schließen", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")

        let main = NSMenu()
        for submenu in [edit, window] {
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
