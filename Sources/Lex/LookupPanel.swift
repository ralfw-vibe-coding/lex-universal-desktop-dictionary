import AppKit
import Carbon.HIToolbox
import SwiftUI
import LexCore

/// Rahmenloses, schwebendes Panel wie Spotlight. Bleibt sichtbar, wenn der Fokus woanders hingeht; ESC blendet aus.
final class LookupPanel: NSPanel {
    var onEscape: () -> Void = {}
    var onHistoryShortcut: () -> Void = {}
    var onDeepDive: () -> Void = {}
    var onSettingsShortcut: () -> Void = {}

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) { onEscape() }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if mods == .command, event.charactersIgnoringModifiers == "y" { onHistoryShortcut(); return true }
        if mods == .command, event.charactersIgnoringModifiers == "," { onSettingsShortcut(); return true }
        if mods == .command, event.charactersIgnoringModifiers == "w" { onEscape(); return true }
        if mods == .command, event.keyCode == 36 || event.keyCode == 76 { onDeepDive(); return true }  // ⌘↩
        return super.performKeyEquivalent(with: event)
    }
}

@MainActor
final class LookupPanelController {
    static let width: CGFloat = 760
    let model = LookupModel()
    private let panel: LookupPanel
    private var hosting: NSHostingView<LookupView>!
    private var initialTop: CGFloat = 0
    /// Globales ESC, solange das Panel sichtbar ist – schließt Lex auch, wenn ein anderes Fenster den Fokus hat.
    private var escapeKey: HotKey?
    private var hiddenAt: Date?
    private var contentHeight: CGFloat = 58

    init(openHistory: @escaping () -> Void, openSettings: @escaping () -> Void) {
        panel = LookupPanel(
            contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 58),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        // Fenster öffnen sich hinter dem schwebenden Panel – deshalb Panel vorher ausblenden.
        let history = { [weak self] in self?.hide(); openHistory() }
        let settings = { [weak self] in self?.hide(); openSettings() }
        model.onOpenHistory = history
        model.onOpenSettings = settings
        panel.onEscape = { [weak self] in self?.hide() }
        panel.onHistoryShortcut = history
        panel.onSettingsShortcut = settings
        panel.onDeepDive = { [weak self] in self?.model.openDeepDive() }

        hosting = NSHostingView(rootView: makeView())
        hosting.sizingOptions = []
        panel.contentView = hosting
    }

    private func makeView() -> LookupView {
        LookupView(model: model, maxAnswerHeight: maxAnswerHeight) { [weak self] height in
            DispatchQueue.main.async {
                self?.contentHeight = ceil(height)
                self?.layout()
            }
        }
    }

    /// Der Bildschirm, auf dem das Panel zuletzt geöffnet wurde.
    private lazy var screen: NSScreen = mouseScreen

    private var mouseScreen: NSScreen {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
    }

    private var maxAnswerHeight: CGFloat {
        screen.visibleFrame.height * 0.85 - 58 - 40
    }

    var isVisible: Bool { panel.isVisible }

    func toggle() {
        if panel.isVisible && panel.isKeyWindow { hide() } else { show() }
    }

    func show() {
        screen = mouseScreen
        let visible = screen.visibleFrame
        // Eingabezeile in der Bildschirmmitte; die Antwort wächst nach unten.
        initialTop = visible.midY + 29 + visible.height * 0.08
        hosting.rootView = makeView()
        // Nach kurzer Pause das Vorherige zeigen, nach längerer ein leeres Panel.
        if let hiddenAt {
            let idleSince = max(hiddenAt, model.finishedAt ?? hiddenAt)
            if LexConfig.load().shouldReset(idleSince: idleSince) { model.reset() }
        }
        model.prepare()
        layout()
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        if escapeKey == nil {
            escapeKey = HotKey(keyCode: kVK_Escape, modifiers: 0) { [weak self] in self?.hide() }
        }
        NotificationCenter.default.post(name: .lexFocusInput, object: nil)
    }

    func hide() {
        escapeKey = nil  // ESC gehört wieder den anderen Apps
        if panel.isVisible { hiddenAt = Date() }
        panel.orderOut(nil)
    }

    /// Oberkante bleibt stehen; reicht der Platz nach unten nicht, rutscht das Panel nach oben.
    private func layout() {
        let visible = screen.visibleFrame
        let height = min(contentHeight, visible.height - 40)
        let bottomLimit = visible.minY + 20
        let top = max(initialTop, min(visible.maxY - 20, bottomLimit + height))
        let frame = NSRect(x: visible.midX - Self.width / 2, y: top - height, width: Self.width, height: height)
        if panel.frame != frame {
            panel.setFrame(frame, display: true)
            panel.invalidateShadow()
        }
    }
}
