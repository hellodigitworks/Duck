import AppKit
import Combine
import DuckCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    static let toggleNotification = Notification.Name("com.hdw.duck.toggle")

    private let preferences = Preferences.shared
    private var statusBar: StatusBarController?
    private var cancellables = Set<AnyCancellable>()
    private var appearanceWatch: NSKeyValueObservation?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenu.build()
        showInDock(preferences.showInDock)
        followAppearance()
        observePreferences()

        let statusBar = StatusBarController(preferences: preferences, updates: .shared)
        statusBar.openPreferences = { [weak self] in self?.showPreferences(nil) }
        self.statusBar = statusBar

        UpdateCheck.shared.start()

        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(handleToggleNotification),
            name: AppDelegate.toggleNotification, object: nil)

        // The window shows itself until the user has hidden icons once. After that it is
        // a right-click away.
        if !preferences.hasHiddenBefore {
            showPreferences(nil)
        }

        showNotesAfterAnUpdate()
    }

    /// The first launch on a new version, on an install that has been used, opens the
    /// window with what changed. Once per version, and never on a fresh install: a list of
    /// changes to an app someone has never seen says nothing to them.
    ///
    /// Duck installs with one line in Terminal or through Homebrew, so nobody ever passes a
    /// release page on the way in. Without this, an update is silent.
    private func showNotesAfterAnUpdate() {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let show = Preferences.shouldShowNotes(current: current,
                                               lastSeen: preferences.lastSeenVersion,
                                               hasUsedDuckBefore: preferences.hasUsedDuckBefore)
        preferences.lastSeenVersion = current
        guard show else { return }
        // Set before the window is asked for, so it opens already showing the notes rather
        // than sliding them in over a window that has only just appeared.
        ReleaseNotes.shared.showing = true
        showPreferences(nil)
    }

    /// Opening Duck again while it is running brings up the preferences window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPreferences(nil)
        return true
    }

    @objc func showPreferences(_ sender: Any?) {
        PreferencesWindowController.shared.show()
    }

    @objc private func handleToggleNotification() {
        statusBar?.toggle()
    }

    /// A normal app while the switch is on: an icon in the Dock and a place in ⌘-Tab. Menu
    /// bar only while it is off. main.swift starts it off; this applies what was saved.
    private func showInDock(_ show: Bool) {
        NSApp.setActivationPolicy(show ? .regular : .accessory)
    }

    /// The Dock tile follows the Mac: cream with an ink duck in light mode, ink with a
    /// cream duck in dark. An .icns holds one look, so the dark one is a PNG in the bundle
    /// and the app swaps it in itself whenever the appearance changes.
    private func followAppearance() {
        appearanceWatch = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] _, _ in
            self?.dockTileForAppearance()
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(dockTileForAppearance),
            name: Notification.Name("AppleInterfaceThemeChangedNotification"), object: nil)
    }

    @objc private func dockTileForAppearance() {
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        if dark, let url = Bundle.main.url(forResource: "AppIcon-dark", withExtension: "png"),
           let tile = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = tile
        } else {
            NSApp.applicationIconImage = nil // the bundle's own icon, the light tile
        }
    }

    private func observePreferences() {
        // The switch takes effect the moment it is flipped, no relaunch. Turned on while
        // running, macOS draws the Dock icon but leaves the app's own menu bar asleep until
        // the app comes forward, so it is brought forward once. Turned off, the switch to
        // accessory drops the app to the back, and coming forward again keeps the window
        // the person is using where it was.
        preferences.$showInDock
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] show in
                self?.showInDock(show)
                NSApp.activate(ignoringOtherApps: true)
            }
            .store(in: &cancellables)
    }
}
