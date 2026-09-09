import AppKit
import SwiftUI
import DuckCore

/// One preferences window for the life of the app. Closing it just hides it.
/// Cream, always: the window forces the light appearance so the system controls agree with it.
final class PreferencesWindowController: NSWindowController {
    static let shared = PreferencesWindowController()

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 440),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false)
        window.title = "Duck"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.appearance = NSAppearance(named: .aqua)
        window.backgroundColor = NSColor(red: 0.957, green: 0.937, blue: 0.902, alpha: 1)
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // Small: the rows and the foot, nothing else.
        window.contentMinSize = NSSize(width: 360, height: 400)
        window.contentViewController = NSHostingController(
            rootView: PreferencesView(preferences: .shared, login: LoginItemModel(),
                                      updates: .shared, notes: .shared))
        window.setContentSize(NSSize(width: 380, height: 440))
        window.setFrameAutosaveName("DuckPreferences2") // a new name, so the old, taller frame is not restored
        super.init(window: window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("Not used")
    }

    func show() {
        guard let window else { return }
        if !window.isVisible, !window.setFrameUsingName("DuckPreferences2") {
            window.center()
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
