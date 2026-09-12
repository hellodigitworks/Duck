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
    private var items: [NSStatusItem]
    /// The names this seating goes by, mark first. Kept so the older ones can be dropped.
    private var seatedNames: [String]
    /// The width constraint macOS puts on each item, kept so it can be switched off.
    private var widthHolders: [ObjectIdentifier: NSLayoutConstraint] = [:]

    /// The item the user sees and clicks. Always the rightmost of Duck's items.
    private var mark: NSStatusItem
    /// The invisible ones that do the pushing.
    private var spacers: [NSStatusItem]
    /// The line at the far left. Everything between it and the mark is what hides, so it
    /// only stands there while the icons are showing: once they are gone it has nothing to
    /// bound, and the bar is left with the mark alone.
    private var edge: NSStatusItem

    /// Small enough that macOS gives the room away rather than shuffling icons sideways.
    private static let rampStep: CGFloat = 100
    private static let rampDelay = 0.05

    private(set) var isCollapsed = false
    /// Points of other apps' icons sitting between Duck's rightmost spacer and the mark.
    /// A spacer only pushes what is on its left, so nothing here can be hidden at any width.
    private(set) var strandedWidth: CGFloat = 0
    /// True while the items are being made again, so nothing reads half a menu bar.
    private var reseating = false
    private var reseatWork: DispatchWorkItem?
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

        // Seated fresh on every launch, so the five always come back as one unbroken run
        // with the mark on its right end. Names carry the seating number because macOS only
        // honours a position for a name it has never seen.
        preferences.seating += 1
        let names = Seating.names(
            spacers: StatusBarController.spacerCount(for: NSScreen.screens),
            seating: preferences.seating)
        let edgeName = Seating.name("edge", seating: preferences.seating)
        Seating.claim(names, from: preferences.seat)
        Seating.claimOne(edgeName, at: Seating.edgePosition)
        seatedNames = names + [edgeName]
        let made = StatusBarController.makeItems(named: names)
        items = made
        mark = made[0]
        spacers = Array(made.dropFirst())
        edge = StatusBarController.makeEdge(named: edgeName)
        super.init()

        readWidthHolders()
        Log.note("Launched \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") on macOS \(ProcessInfo.processInfo.operatingSystemVersionString), screens \(NSScreen.screens.map { Int($0.frame.width) }), \(spacers.count) spacers, seat \(Int(preferences.seat)) at seating \(preferences.seating)")
        configureRoles()
        observePreferences()

        NotificationCenter.default.addObserver(
            self, selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(someWindowMoved(_:)),
            name: NSWindow.didMoveNotification, object: nil)

        // The buttons need a layout pass before their positions can be trusted. Once the
        // bar is ready, honour the chosen auto-hide delay instead of hiding immediately.
        prepareAfterLaunch(attempt: 0)
    }

    // MARK: - Seating

    /// Makes one item per name, mark first. The mark sizes itself to its picture; the
    /// spacers start at nothing and are widened only while hiding.
    private static func makeItems(named names: [String]) -> [NSStatusItem] {
        names.enumerated().map { index, name in
            let item = NSStatusBar.system.statusItem(
                withLength: index == 0 ? NSStatusItem.variableLength : 0)
            item.autosaveName = name
            return item
        }
    }

    /// The line stands in its own item out past the icons, where the mark cannot reach.
    private static func makeEdge(named name: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = name
        item.button?.image = Mark.rule
        return item
    }

    private func readWidthHolders() {
        widthHolders.removeAll()
        for (index, item) in items.enumerated() {
            let holder = StatusBarController.widthHolder(of: item)
            widthHolders[ObjectIdentifier(item)] = holder
            Log.note("Item \(index) width holder: \(holder.map { "found (\($0.constant)pt)" } ?? "MISSING")")
        }
    }

    /// True when the five sit as one unbroken run with the mark on the right. That is the
    /// whole basis of hiding: a widened item only pushes what is on its left, so anything
    /// wedged between the last spacer and the mark can never be moved off the bar.
    private var blockIsWhole: Bool {
        var frames: [CGRect] = []
        for item in items {
            guard let frame = item.button?.window?.frame, frame.origin.x > 0 else { return false }
            frames.append(frame)
        }
        let sorted = frames.sorted { $0.origin.x > $1.origin.x }
        guard let markFrame = mark.button?.window?.frame, markFrame.origin.x == sorted[0].origin.x
        else { return false }
        for (right, left) in zip(sorted, sorted.dropFirst()) where right.origin.x - left.maxX > 2 {
            return false
        }
        return true
    }

    /// Where the mark sits now. The number a re-seating tries to land back on.
    private var markX: CGFloat? {
        guard let x = mark.button?.window?.frame.origin.x, x > 0 else { return nil }
        return x
    }

    /// Called whenever the bar may have moved under us. A whole block needs nothing.
    private func reseatIfBroken() {
        guard !isCollapsed, !reseating, !blockIsWhole else { return }
        guard let target = markX else {
            // Nothing of Duck's is on the bar at all. Start again from a seat known to draw,
            // rather than aiming at a mark that is not there.
            preferences.seat = Seating.fallback
            Log.note("Nothing on the bar. Seating again from \(Int(Seating.fallback)).")
            reseat(target: nil)
            return
        }
        Log.note("Block broken, seating again onto x=\(Int(target)): \(layoutDescription())")
        reseat(target: target)
    }

    /// Seats being tried, in order, until the five come back as one run.
    private var seatQueue: [Double] = []
    /// The last seat that did come back whole, to fall back on if a correction spoils it.
    private var wholeSeat: Double?
    private var seatTarget: CGFloat?
    private var seatCorrections = 0

    /// Puts the block back together, aiming to leave the mark where it already is.
    ///
    /// Two things can go wrong and they pull opposite ways. The seat may be crowded, another
    /// app holding a slot inside Duck's range, and the answer is to step sideways. Or the
    /// block may come back whole but in the wrong place, and the answer is to move the seat
    /// towards where the mark was. Whole wins: a run in the wrong place still hides, a run
    /// in pieces does not.
    private func reseat(target: CGFloat?) {
        guard !reseating else { return }
        reseating = true
        seatTarget = target
        seatCorrections = 0
        wholeSeat = nil
        let base = preferences.seat
        seatQueue = [base, base + 8, base - 8, base + 16, base - 16, Seating.fallback, Seating.fallback + 40]
        takeNextSeat()
    }

    private func takeNextSeat() {
        guard !seatQueue.isEmpty else {
            reseating = false
            Log.note("Gave up seating. The bar has no clear run of five: \(layoutDescription())")
            measureStranded(mark: mark, spacers: spacers)
            return
        }
        settle(at: seatQueue.removeFirst())
    }

    /// Takes the next seating number, asks macOS for consecutive slots and makes the items
    /// again. Smaller seat sits further right.
    private func settle(at seat: Double) {
        reseatWork?.cancel()
        preferences.seat = min(max(seat, Seating.range.lowerBound), Seating.range.upperBound)

        for item in items { NSStatusBar.system.removeStatusItem(item) }
        NSStatusBar.system.removeStatusItem(edge)
        preferences.seating += 1
        let names = Seating.names(spacers: spacers.count, seating: preferences.seating)
        let edgeName = Seating.name("edge", seating: preferences.seating)
        Seating.claim(names, from: preferences.seat)
        Seating.claimOne(edgeName, at: Seating.edgePosition)
        seatedNames = names + [edgeName]
        items = StatusBarController.makeItems(named: names)
        mark = items[0]
        spacers = Array(items.dropFirst())
        edge = StatusBarController.makeEdge(named: edgeName)
        readWidthHolders()
        configureRoles()

        let work = DispatchWorkItem { [weak self] in self?.judge() }
        reseatWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7, execute: work)
    }

    /// Reads back what that seat actually did, and decides whether to try another.
    private func judge() {
        guard let landed = markX, blockIsWhole else {
            if let good = wholeSeat {
                // A correction broke a run that was already whole. Put the good one back.
                Log.note("Correction spoiled the run. Back to seat \(Int(good)).")
                seatQueue = []
                wholeSeat = nil
                seatCorrections = 99
                settle(at: good)
                return
            }
            Log.note("Seat \(Int(preferences.seat)) did not come back whole: \(layoutDescription())")
            takeNextSeat()
            return
        }

        if let target = seatTarget, abs(landed - target) > 16, seatCorrections < 2 {
            wholeSeat = preferences.seat
            seatCorrections += 1
            let corrected = preferences.seat - Double(target - landed)
            Log.note("Seat \(Int(preferences.seat)) landed the mark at x=\(Int(landed)), wanted \(Int(target)). Trying \(Int(corrected)).")
            settle(at: corrected)
            return
        }

        reseating = false
        seatQueue = []
        Seating.forget(keeping: seatedNames)
        strandedWidth = 0
        applyMarkTooltip()
        Log.note("Seated \(preferences.seating) at \(Int(preferences.seat)), mark at x=\(Int(landed)), block whole: \(layoutDescription())")
        applyLayout()
        scheduleAutoHideIfNeeded()
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
        if let button = edge.button {
            button.image = Mark.rule
            button.target = self
            button.action = #selector(markClicked)
            _ = button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Everything between here and Duck hides. Hold ⌘ and drag icons in."
        }
        applyMarkTooltip()
        applyLayout()
    }

    /// Sets every item's width and the mark's picture from the current state.
    private func applyLayout() {
        widen(mark, to: NSStatusItem.variableLength)
        edge.isVisible = !isCollapsed
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
            self.reseatIfBroken()
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
        guard !reseating else { return }
        guard assignRoles() else {
            Log.note("Not hiding yet: the menu bar has not settled. \(layoutDescription())")
            return
        }
        guard blockIsWhole else {
            Log.note("Not hiding yet: the items are in pieces, seating them again first.")
            reseatIfBroken()
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

    private func prepareAfterLaunch(attempt: Int) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self, !self.isCollapsed else { return }
            if self.reseating {
                self.prepareAfterLaunch(attempt: attempt)
            } else if self.assignRoles(), self.blockIsWhole {
                if AutoHideSchedule.shouldScheduleAfterLaunch(
                    hasHiddenBefore: self.preferences.hasHiddenBefore,
                    autoHideEnabled: self.preferences.autoHide) {
                    Log.note("Menu bar ready after launch. Auto-hide will run in \(Int(self.preferences.autoHideSeconds)) seconds.")
                    self.scheduleAutoHideIfNeeded()
                } else {
                    Log.note("Launch: staying open until a manual hide or enabled auto-hide. \(self.layoutDescription())")
                }
            } else if attempt < 6 {
                self.reseatIfBroken()
                self.prepareAfterLaunch(attempt: attempt + 1)
            } else {
                Log.note("Launch: the menu bar never settled. Leaving controls visible. \(self.layoutDescription())")
            }
        }
    }

    // MARK: - Auto hide

    private func scheduleAutoHideIfNeeded() {
        autoHideTimer?.invalidate()
        autoHideTimer = nil
        guard preferences.autoHide, !isCollapsed else { return }
        let timer = Timer(timeInterval: preferences.autoHideSeconds, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.autoHideTimer = nil
            self.hideAfterMenuBarSettles(attempt: 0)
        }
        RunLoop.main.add(timer, forMode: .common)
        autoHideTimer = timer
    }

    /// Auto-hide can fire while a system control, such as brightness, has a popover open.
    /// During that short change macOS reports incomplete item positions. Wait for usable
    /// positions instead of leaving Duck permanently open.
    private func hideAfterMenuBarSettles(attempt: Int) {
        guard preferences.autoHide, !isCollapsed else { return }
        guard !reseating, assignRoles(), blockIsWhole else {
            guard AutoHideSchedule.shouldRetry(after: attempt) else {
                Log.note("Auto-hide gave up after \(attempt) retries: the menu bar stayed unsettled. \(layoutDescription())")
                return
            }
            Log.note("Auto-hide waiting for the menu bar to settle, retry \(attempt + 1)/\(AutoHideSchedule.maximumRetries).")
            DispatchQueue.main.asyncAfter(deadline: .now() + AutoHideSchedule.retryDelay) { [weak self] in
                self?.hideAfterMenuBarSettles(attempt: attempt + 1)
            }
            return
        }
        collapse()
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
        let described = items.enumerated().map { index, item in
            let role = item === mark ? "mark" : "spacer"
            let frame = item.button?.window?.frame ?? .zero
            let holder = widthHolders[ObjectIdentifier(item)]
            let held = holder.map { $0.isActive ? "held" : "free" } ?? "noholder"
            return "\(index):\(role) len=\(Int(item.length)) x=\(Int(frame.origin.x)) w=\(Int(frame.width)) \(held)\(item.isVisible ? "" : " invisible")"
        }
        let edgeFrame = edge.button?.window?.frame ?? .zero
        return (described + ["line x=\(Int(edgeFrame.origin.x)) w=\(Int(edgeFrame.width))\(edge.isVisible ? "" : " invisible")"])
            .joined(separator: " | ")
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
