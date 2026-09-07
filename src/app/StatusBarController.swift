import AppKit
import Combine
import QuartzCore
import DuckCore

/// Owns the menu bar mark and the hiding logic.
///
/// One thing is visible: the mark. A plus while the icons are hidden, an ✕ while they
/// are showing, rotating 45 degrees between the two. Everything to its left hides,
/// everything to its right stays.
///
/// How hiding works: macOS lays out menu bar icons from the right, and an icon that does
/// not fit drops off the left end. Duck keeps a few empty items just left of the mark and
/// widens them until the bar is full, which takes every icon past them out of view.
/// Narrow them again and the icons come straight back. Nothing is removed.
///
/// Three things had to be right, and all three were measured on macOS 27:
///
/// - **The width has to go up in steps.** Set it in one jump and macOS shuffles the icons
///   sideways and keeps them on screen: a gap where the icons were, nothing hidden. So the
///   first hide on a screen walks the width up, then remembers what worked and opens there
///   next time, which is what stops the icons sliding across the bar on every click.
/// - **One item can only take about half the screen.** Past that macOS ignores it, so the
///   width is shared across several items rather than piled onto one.
/// - **An empty status item is 16pt wide, not nothing.** A width constraint on its content
///   view holds it open. Dropping that constraint and setting the window's size by hand
///   takes it down to a single point, which is why Duck leaves no gap in the bar. The trick
///   comes from Ice, and Ice's own note is that a future macOS could take it away: if the
///   constraint is not found, the items simply rest at 16pt as they used to.
///
/// One thing this cannot do: a spacer only pushes what is on its left. macOS hands out
/// menu bar slots and remembers them, so another app's icon can end up sitting between
/// Duck's last spacer and the mark, and dragging the mark rightwards leaves the spacers
/// behind. Those icons are out of reach at any width. Duck measures the gap and says so
/// rather than hiding some and calling it done.
final class StatusBarController: NSObject, NSMenuDelegate {
    private let preferences: Preferences
    private let updates: UpdateCheck

    /// Every item Duck owns, in creation order. Position decides which is the mark.
    private let items: [NSStatusItem]
    /// The width constraint macOS puts on each item, kept so it can be switched off.
    private var widthHolders: [ObjectIdentifier: NSLayoutConstraint] = [:]

    /// The item the user sees and clicks. Always the rightmost of Duck's items.
    private var mark: NSStatusItem
    /// The invisible ones that do the pushing.
    private var spacers: [NSStatusItem]

    /// Small enough that macOS gives the room away rather than shuffling icons sideways.
    private static let rampStep: CGFloat = 100
    private static let rampDelay = 0.05

    private(set) var isCollapsed = false
    /// Points of other apps' icons sitting between Duck's rightmost spacer and the mark.
    /// A spacer only pushes what is on its left, so nothing here can be hidden at any width.
    private(set) var strandedWidth: CGFloat = 0
    private var autoHideTimer: Timer?
    private var rolesRefresh: DispatchWorkItem?
    private var rampToken = 0
    /// Where the mark is between a plus (0) and an ✕ (1).
    private var markFraction: CGFloat = 1
    private var markAnimation: Timer?
    private var cancellables = Set<AnyCancellable>()
    private lazy var contextMenu = makeContextMenu()

    var openPreferences: (() -> Void)?

    private enum MenuTag: Int {
        case showHide = 1, autoHide, update, stranded, strandedRule
    }

    init(preferences: Preferences, updates: UpdateCheck) {
        self.preferences = preferences
        self.updates = updates

        // Creation order: each new item lands to the left of the previous one, so the
        // first one made is the one the user ends up clicking.
        let first = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        first.autosaveName = "duck.toggle"
        let rest = (0..<StatusBarController.spacerCount(for: NSScreen.screens)).map { index -> NSStatusItem in
            let spacer = NSStatusBar.system.statusItem(withLength: 0)
            spacer.autosaveName = "duck.spacer\(index)"
            return spacer
        }
        items = [first] + rest
        mark = first
        spacers = rest
        super.init()

        for (index, item) in items.enumerated() {
            let holder = StatusBarController.widthHolder(of: item)
            widthHolders[ObjectIdentifier(item)] = holder
            Log.note("Item \(index) width holder: \(holder.map { "found (\($0.constant)pt)" } ?? "MISSING")")
        }
        Log.note("Launched \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") on macOS \(ProcessInfo.processInfo.operatingSystemVersionString), screens \(NSScreen.screens.map { Int($0.frame.width) }), \(rest.count) spacers")
        configureRoles()
        observePreferences()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(someWindowMoved(_:)),
            name: NSWindow.didMoveNotification, object: nil)

        // The buttons need a layout pass before their positions can be trusted.
        collapseWhenReady(attempt: 0)
    }

    // MARK: - Geometry

    /// The most one item may ask for. Past about half the screen macOS stops making room
    /// for it, so a width that big hides nothing at all.
    private var widthCeiling: CGFloat {
        let bar = NSScreen.main?.frame.width ?? NSScreen.screens.map(\.frame.width).max() ?? 1440
        return max(200, floor(bar / 2) - 32)
    }

    /// macOS 27 caps one item at about half the screen, so the width is shared across a
    /// few items there. Before 27 one item can take any width, which is how Ice does it,
    /// so there is one spacer and it is set to `pushLength` in a single step.
    private static var sharesWidth: Bool {
        if #available(macOS 27, *) { return true }
        return false
    }

    /// What the one spacer asks for before macOS 27. Ice's number.
    private static let pushLength: CGFloat = 10_000

    /// Enough items to fill the widest bar this Mac can show, plus one to spare.
    private static func spacerCount(for screens: [NSScreen]) -> Int {
        guard sharesWidth else { return 1 }
        let widest = screens.map(\.frame.width).max() ?? 1440
        let ceiling = max(200, floor(widest / 2) - 32)
        return max(2, Int((widest / ceiling).rounded(.up)) + 1)
    }

    /// The constraint that keeps a status item from reaching zero width.
    private static func widthHolder(of item: NSStatusItem) -> NSLayoutConstraint? {
        guard
            let button = item.button,
            let constraints = button.window?.contentView?.constraintsAffectingLayout(for: .horizontal)
        else {
            return nil
        }
        return constraints.first { $0.secondItem === button.superview }
    }

    /// Takes an item down to a single point, so it leaves no gap between the icons.
    private func shrink(_ item: NSStatusItem) {
        item.length = 0
        guard let holder = widthHolders[ObjectIdentifier(item)] else { return }
        holder.isActive = false
        if let window = item.button?.window {
            var size = window.frame.size
            size.width = 1
            window.setContentSize(size)
        }
    }

    private func widen(_ item: NSStatusItem, to width: CGFloat) {
        widthHolders[ObjectIdentifier(item)]?.isActive = true
        item.length = width
    }

    // MARK: - Roles

    /// The rightmost of Duck's items is the mark; the rest push. macOS and the user both
    /// move these around, so the roles are read back from where they actually are.
    @discardableResult
    private func assignRoles() -> Bool {
        guard !isCollapsed else { return false }
        var positioned: [(item: NSStatusItem, x: CGFloat)] = []
        for item in items {
            guard let x = originX(of: item) else { return false }
            positioned.append((item, x))
        }
        let sorted = positioned.sorted { $0.x > $1.x }.map(\.item)
        guard let newMark = sorted.first else { return false }
        let newSpacers = Array(sorted.dropFirst())

        if newMark !== mark || !newSpacers.elementsEqual(spacers, by: ===) {
            mark = newMark
            spacers = newSpacers
            configureRoles()
            Log.note("Roles reassigned by position: \(layoutDescription())")
        }
        measureStranded(mark: newMark, spacers: newSpacers)
        return true
    }

    /// The gap between the rightmost spacer's right edge and the mark's left edge. Anything
    /// in there belongs to another app and sits on the wrong side of every spacer Duck has,
    /// so widening cannot move it off the bar. Only meaningful while showing.
    private func measureStranded(mark: NSStatusItem, spacers: [NSStatusItem]) {
        guard let markFrame = mark.button?.window?.frame, markFrame.origin.x > 0 else { return }
        let nearest = spacers
            .compactMap { $0.button?.window?.frame }
            .filter { $0.origin.x > 0 }
            .map(\.maxX)
            .max()
        guard let nearest else { return }
        // A point or two is rounding, not another app's icon.
        let gap = max(0, markFrame.origin.x - nearest)
        let measured = gap < 8 ? 0 : gap
        guard abs(measured - strandedWidth) > 1 else { return }
        strandedWidth = measured
        applyMarkTooltip()
        if measured > 0 {
            Log.note("Out of reach: \(Int(measured))pt of other icons sit between Duck's last spacer and the mark. Widening cannot move them. \(layoutDescription())")
        } else {
            Log.note("Back in reach: Duck's spacers are next to the mark again.")
        }
    }

    /// How many icons that gap is worth. Menu bar items run about 32pt, so this is a count
    /// a person can check against the bar, not a measurement.
    private var strandedIcons: Int {
        guard strandedWidth > 0 else { return 0 }
        return max(1, Int((strandedWidth / 32).rounded()))
    }

    private func applyMarkTooltip() {
        mark.button?.toolTip = strandedWidth > 0
            ? "Click to hide or show the icons to the left. \(strandedIcons) of them cannot be hidden from here: drag them further left. Right-click for options."
            : "Click to hide or show the icons to the left. Right-click for options."
    }

    /// Gives every item the look and behaviour of its current role.
    private func configureRoles() {
        for item in items {
            item.menu = nil
            if let button = item.button {
                button.target = nil
                button.action = nil
                button.image = nil
                button.toolTip = nil
            }
        }
        if let button = mark.button {
            button.target = self
            button.action = #selector(markClicked)
            _ = button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        applyMarkTooltip()
        applyLayout()
    }

    /// Sets every item's width and the mark's picture from the current state.
    private func applyLayout() {
        widen(mark, to: NSStatusItem.variableLength)
        setMark(to: isCollapsed ? 0 : 1)

        rampToken += 1
        if isCollapsed {
            if Self.sharesWidth {
                grow(spacers, token: rampToken, total: startingWidth)
            } else {
                push(spacers)
            }
        } else {
            for spacer in spacers { shrink(spacer) }
        }
        snapshotSoon()
    }

    /// Before macOS 27: the first spacer takes the whole push in one step, the rest stay
    /// out of the way. No ramp, no sharing, no remembered width.
    private func push(_ items: [NSStatusItem]) {
        guard let first = items.first else { return }
        widen(first, to: Self.pushLength)
        for spacer in items.dropFirst() { shrink(spacer) }
        Log.note("Pushed with \(Int(Self.pushLength))pt: \(layoutDescription())")
    }

    /// Writes down where everything in the bar is a moment after a change, when the bar
    /// has had time to lay itself out. The frames read straight after a change are stale.
    private func snapshotSoon() {
        let token = rampToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self, self.rampToken == token else { return }
            Log.note("Bar 1.5s later, \(self.isCollapsed ? "hidden" : "showing"): \(self.layoutDescription()) || \(self.barSnapshot())")
        }
    }

    // MARK: - Hiding

    /// Widens the spacers a step at a time until the bar is full.
    ///
    /// The step where the far edge stops moving is the step where the bar is full, and a
    /// little past that clears the ‹‹ overflow arrows macOS shows when items no longer fit.
    private func grow(_ items: [NSStatusItem], token: Int, total: CGFloat, lastEdge: CGFloat = .greatestFiniteMagnitude) {
        guard !items.isEmpty, rampToken == token else { return }
        share(total, across: items)

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.rampDelay) { [weak self] in
            guard let self, self.rampToken == token else { return }
            let edge = items
                .filter { $0.length > 0 }
                .compactMap { $0.button?.window?.frame.origin.x }
                .filter { $0 > 0 }
                .min() ?? 0
            let limit = self.widthCeiling * CGFloat(items.count)

            if edge >= lastEdge - 1 || total >= limit {
                let settled = min(total + 200, limit)
                self.share(settled, across: items)
                self.remember(total)
                let short = self.strandedWidth > 0 ? ", \(Int(self.strandedWidth))pt still showing out of reach" : ""
                Log.note("Hidden with \(Int(settled))pt (ceiling \(Int(self.widthCeiling)) × \(items.count)), opened at \(Int(self.startingWidth))\(short): \(self.layoutDescription())")
                return
            }
            Log.note("Ramp \(Int(total))pt, far edge \(Int(edge))")
            self.grow(items, token: token, total: min(total + Self.rampStep, limit), lastEdge: edge)
        }
    }

    /// Shares one total width across the spacers, filling each to its ceiling in turn.
    private func share(_ total: CGFloat, across items: [NSStatusItem]) {
        var left = total
        for item in items {
            let take = min(left, widthCeiling)
            if take > 0 {
                widen(item, to: take)
            } else {
                shrink(item)
            }
            left -= take
        }
    }

    /// Where the ramp begins. The first hide on a bar walks up from nothing, which is the
    /// icons visibly sliding away. After that it opens straight at the width that worked
    /// last time, so the icons go in one frame and the ramp only confirms the bar is full.
    private var startingWidth: CGFloat {
        let bar = Double(NSScreen.main?.frame.width ?? 0)
        guard preferences.hidingBarWidth == bar, preferences.hidingWidth > 200 else {
            return Self.rampStep
        }
        return max(Self.rampStep, CGFloat(preferences.hidingWidth))
    }

    /// Keeps the narrowest width that has done the job on this bar. Narrowest, because the
    /// number creeps up otherwise, and too wide is a width macOS ignores.
    private func remember(_ width: CGFloat) {
        let bar = Double(NSScreen.main?.frame.width ?? 0)
        let known = preferences.hidingBarWidth == bar ? preferences.hidingWidth : 0
        preferences.hidingWidth = known > 200 ? min(known, Double(width)) : Double(width)
        preferences.hidingBarWidth = bar
    }

    // MARK: - The mark

    /// Turns the plus into an ✕, or back: 45 degrees in a fifth of a second. Called on
    /// every layout pass, so a mark already in the right place is only redrawn.
    private func setMark(to target: CGFloat) {
        markAnimation?.invalidate()
        markAnimation = nil
        mark.button?.image = Mark.image(style: preferences.markStyle, fraction:markFraction)
        guard abs(target - markFraction) > 0.001 else { return }

        let start = markFraction
        let began = CACurrentMediaTime()
        let duration = 0.2
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            let progress = min(1, (CACurrentMediaTime() - began) / duration)
            // Ease in and out, so it starts and lands softly.
            let eased = progress < 0.5
                ? 2 * progress * progress
                : 1 - pow(-2 * progress + 2, 2) / 2
            self.markFraction = start + (target - start) * CGFloat(eased)
            self.mark.button?.image = Mark.image(style: preferences.markStyle, fraction:self.markFraction)
            if progress >= 1 {
                timer.invalidate()
                self.markAnimation = nil
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        markAnimation = timer
    }

    // MARK: - Watching the bar

    /// Re-check roles a moment after something moved, but only while showing.
    private func scheduleRolesRefresh(after delay: TimeInterval = 0.4) {
        rolesRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self, !self.isCollapsed else { return }
            self.assignRoles()
        }
        rolesRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
    }

    @objc private func someWindowMoved(_ notification: Notification) {
        guard !isCollapsed, let window = notification.object as? NSWindow else { return }
        if let index = items.firstIndex(where: { $0.button?.window === window }) {
            Log.note("Item \(index) moved to x=\(Int(window.frame.origin.x)) w=\(Int(window.frame.width))")
            scheduleRolesRefresh()
        }
    }

    private func observePreferences() {
        preferences.$autoHide
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleAutoHideIfNeeded() }
            .store(in: &cancellables)

        preferences.$autoHideSeconds
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleAutoHideIfNeeded() }
            .store(in: &cancellables)

        // A new look for the mark shows up in the bar the moment it is picked.
        preferences.$markStyle
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] style in
                guard let self else { return }
                self.mark.button?.image = Mark.image(style: style, fraction: self.markFraction)
            }
            .store(in: &cancellables)
    }

    // MARK: - Clicks

    @objc private func markClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            mark.menu = contextMenu
            mark.button?.performClick(nil)
        } else {
            toggle()
        }
    }

    /// Hide if showing, show if hidden.
    func toggle() {
        if isCollapsed { expand() } else { collapse() }
    }

    func collapse() {
        guard !isCollapsed else { return }
        guard assignRoles() else {
            Log.note("Not hiding yet: the menu bar has not settled. \(layoutDescription())")
            return
        }
        Log.note("Hiding: \(layoutDescription())")
        isCollapsed = true
        autoHideTimer?.invalidate()
        rolesRefresh?.cancel()
        applyLayout()
        if !preferences.hasHiddenBefore { preferences.hasHiddenBefore = true }
    }

    func expand() {
        guard isCollapsed else { return }
        isCollapsed = false
        applyLayout()
        scheduleAutoHideIfNeeded()
        // The bar shuffles as the icons come back, so read the roles again once it settles.
        scheduleRolesRefresh(after: 0.6)
        Log.note("Showing: \(layoutDescription())")
    }

    private func collapseWhenReady(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.isCollapsed else { return }
            if self.assignRoles() {
                // A fresh install stays open until the user hides on purpose.
                if self.preferences.hasHiddenBefore {
                    self.collapse()
                } else {
                    Log.note("First launch: staying open. \(self.layoutDescription())")
                }
            } else if attempt < 6 {
                self.collapseWhenReady(attempt: attempt + 1)
            } else {
                Log.note("Did not hide: the menu bar never settled. \(self.layoutDescription())")
            }
        }
    }

    // MARK: - Auto hide

    private func scheduleAutoHideIfNeeded() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        guard preferences.autoHide, !isCollapsed else { return }
        let timer = Timer(timeInterval: preferences.autoHideSeconds, repeats: false) { [weak self] _ in
            self?.collapse()
        }
        RunLoop.main.add(timer, forMode: .common)
        autoHideTimer = timer
    }

    // MARK: - Positions

    /// Each menu bar item lives in its own small window. Comparing their x origins tells us
    /// the order they are in. Only meaningful while showing.
    private func originX(of item: NSStatusItem) -> CGFloat? {
        guard let window = item.button?.window, window.frame.width > 0, window.frame.origin.x > 0 else { return nil }
        return window.frame.origin.x
    }

    @objc private func screenParametersChanged() {
        Log.note("Screens changed to \(NSScreen.screens.map { Int($0.frame.width) }): one item may now take \(Int(self.widthCeiling))pt")
        guard isCollapsed else {
            applyLayout()
            return
        }
        // Plug in a different display and the hide is still the one measured for the old
        // bar. Let everything back out and hide again once the new bar has settled.
        isCollapsed = false
        applyLayout()
        hideAgainAfterScreenChange(attempt: 0)
    }

    private func hideAgainAfterScreenChange(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.isCollapsed else { return }
            if self.assignRoles() {
                self.collapse()
            } else if attempt < 6 {
                self.hideAgainAfterScreenChange(attempt: attempt + 1)
            } else {
                Log.note("Did not hide after the screen changed: the menu bar never settled.")
            }
        }
    }

    // MARK: - Diagnostics

    /// Every item in one line: role, length, where its window is. What a bug report needs.
    private func layoutDescription() -> String {
        items.enumerated().map { index, item in
            let role = item === mark ? "mark" : "spacer"
            let frame = item.button?.window?.frame ?? .zero
            let holder = widthHolders[ObjectIdentifier(item)]
            let held = holder.map { $0.isActive ? "held" : "free" } ?? "noholder"
            return "\(index):\(role) len=\(Int(item.length)) x=\(Int(frame.origin.x)) w=\(Int(frame.width)) \(held)\(item.isVisible ? "" : " invisible")"
        }.joined(separator: " | ")
    }

    /// Every window sitting at menu bar height, by owner, left to right: what is actually on
    /// the bar right now, other apps' items included. Bounds only, so no permission is needed.
    private func barSnapshot() -> String {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return "(no window list)"
        }
        let entries: [(x: CGFloat, text: String)] = list.compactMap { info in
            guard let layer = info[kCGWindowLayer as String] as? Int,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let width = bounds["Width"],
                  let y = bounds["Y"], let height = bounds["Height"], y < 40, height < 60,
                  let owner = info[kCGWindowOwnerName as String] as? String
            else { return nil }
            return (x, "\(owner)(\(layer)):\(Int(x))+\(Int(width))")
        }
        return entries.sorted { $0.x < $1.x }.map(\.text).joined(separator: " ")
    }

    /// A report a person can paste into a message: the Mac, the screens, every item, the log.
    func diagnosticsReport() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let screens = NSScreen.screens.map { "\(Int($0.frame.origin.x)),\(Int($0.frame.origin.y)) \(Int($0.frame.width))×\(Int($0.frame.height))\($0 == NSScreen.main ? " main" : "")" }
        return """
        Duck \(version) on macOS \(ProcessInfo.processInfo.operatingSystemVersionString)
        Screens: \(screens.joined(separator: "; "))
        State: \(isCollapsed ? "hidden" : "showing"), ceiling \(Int(widthCeiling))pt, remembered \(Int(preferences.hidingWidth))pt for a \(Int(preferences.hidingBarWidth))pt bar
        Out of reach: \(strandedWidth > 0 ? "\(Int(strandedWidth))pt, about \(strandedIcons) icon(s) between the last spacer and the mark" : "none")"
        Items: \(layoutDescription())
        Bar: \(barSnapshot())

        Log:
        \(Log.tail())
        """
    }

    @objc private func menuCopyDiagnostics() {
        let report = diagnosticsReport()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
        Log.note("Diagnostics copied")
    }

    // MARK: - Context menu

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        // Only there when another app's icon has landed between Duck's spacers and the
        // mark. Nothing to click: it says what happened and what to do about it.
        let stranded = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        stranded.tag = MenuTag.stranded.rawValue
        stranded.isEnabled = false
        stranded.isHidden = true
        menu.addItem(stranded)

        let strandedRule = NSMenuItem.separator()
        strandedRule.tag = MenuTag.strandedRule.rawValue
        strandedRule.isHidden = true
        menu.addItem(strandedRule)

        let showHide = NSMenuItem(title: "Hide icons", action: #selector(menuToggle), keyEquivalent: "")
        showHide.target = self
        showHide.tag = MenuTag.showHide.rawValue
        menu.addItem(showHide)

        let autoHide = NSMenuItem(title: "Hide again automatically", action: #selector(menuToggleAutoHide), keyEquivalent: "")
        autoHide.target = self
        autoHide.tag = MenuTag.autoHide.rawValue
        menu.addItem(autoHide)

        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Preferences…", action: #selector(menuOpenPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        // Behind the Option key: hold ⌥ while the menu is open and Preferences becomes
        // Copy Diagnostics. Still one paste away for a bug report, never in the way.
        let report = NSMenuItem(title: "Copy Diagnostics", action: #selector(menuCopyDiagnostics), keyEquivalent: ",")
        report.keyEquivalentModifierMask = [.command, .option]
        report.isAlternate = true
        report.target = self
        menu.addItem(report)

        // Only there once a newer release exists.
        let update = NSMenuItem(title: "", action: #selector(menuOpenUpdate), keyEquivalent: "")
        update.target = self
        update.tag = MenuTag.update.rawValue
        update.isHidden = true
        menu.addItem(update)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Duck", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        let count = strandedIcons
        if let item = menu.item(withTag: MenuTag.stranded.rawValue) {
            item.isHidden = count == 0
            item.title = count == 1
                ? "1 icon cannot be hidden — drag it further left"
                : "\(count) icons cannot be hidden — drag them further left"
        }
        menu.item(withTag: MenuTag.strandedRule.rawValue)?.isHidden = count == 0
        menu.item(withTag: MenuTag.showHide.rawValue)?.title = isCollapsed ? "Show hidden icons" : "Hide icons"
        menu.item(withTag: MenuTag.autoHide.rawValue)?.state = preferences.autoHide ? .on : .off
        if let item = menu.item(withTag: MenuTag.update.rawValue) {
            item.isHidden = updates.newer == nil
            item.title = updates.newer.map { "Download Duck \($0.version)…" } ?? ""
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        // The mark only borrows the menu for a right-click. Left-clicks must reach the action.
        DispatchQueue.main.async { [weak self] in
            self?.mark.menu = nil
        }
    }

    @objc private func menuToggle() { toggle() }
    @objc private func menuToggleAutoHide() { preferences.autoHide.toggle() }
    @objc private func menuOpenPreferences() { openPreferences?() }
    @objc private func menuOpenUpdate() {
        if let url = updates.newer?.url { NSWorkspace.shared.open(url) }
    }
}
