import Combine
import Foundation

/// The five looks the mark can have. Each is a pair: one shape while the icons are hidden,
/// another while they are showing.
public enum MarkStyle: String, CaseIterable {
    case plus, chevron, dot, line, corner

    /// What the Preferences window calls it.
    public var name: String {
        switch self {
        case .plus: return "Plus"
        case .chevron: return "Chevron"
        case .dot: return "Dot"
        case .line: return "Line"
        case .corner: return "Corner"
        }
    }
}

/// Everything the user can change. Backed by UserDefaults, so it survives relaunches.
public final class Preferences: ObservableObject {
    public static let shared = Preferences()

    public enum Key {
        public static let autoHide = "autoHide"
        public static let autoHideSeconds = "autoHideSeconds"
        public static let hasHiddenBefore = "hasHiddenBefore"
        public static let hidingWidth = "hidingWidth"
        public static let hidingBarWidth = "hidingBarWidth"
        public static let markStyle = "markStyle"
        public static let showInDock = "showInDock"
        public static let seat = "seat"
        public static let seating = "seating"
        public static let lastSeenVersion = "lastSeenVersion"
    }

    /// The delays offered for hiding icons again, in seconds.
    public static let autoHideChoices: [Double] = [5, 10, 15, 30, 60]
    public static let defaultAutoHideSeconds: Double = 10

    private let defaults: UserDefaults

    @Published public var autoHide: Bool {
        didSet { defaults.set(autoHide, forKey: Key.autoHide) }
    }

    @Published public var autoHideSeconds: Double {
        didSet { defaults.set(autoHideSeconds, forKey: Key.autoHideSeconds) }
    }

    /// False until the user hides icons for the first time. On a fresh install Duck stays
    /// open, and shows its window, until the user has seen where the mark is.
    @Published public var hasHiddenBefore: Bool {
        didSet { defaults.set(hasHiddenBefore, forKey: Key.hasHiddenBefore) }
    }

    /// The width that last did the hiding, and the screen it was measured on. Saves
    /// walking the width up from nothing every time, which is what makes icons crawl.
    @Published public var hidingWidth: Double {
        didSet { defaults.set(hidingWidth, forKey: Key.hidingWidth) }
    }

    @Published public var hidingBarWidth: Double {
        didSet { defaults.set(hidingBarWidth, forKey: Key.hidingBarWidth) }
    }

    /// Which look the mark has. Plus unless the person picked another.
    @Published public var markStyle: MarkStyle {
        didSet { defaults.set(markStyle.rawValue, forKey: Key.markStyle) }
    }

    /// Off, Duck lives in the menu bar and nowhere else. On, it is a normal app as well: an
    /// icon in the Dock and a place in ⌘-Tab.
    @Published public var showInDock: Bool {
        didSet { defaults.set(showInDock, forKey: Key.showInDock) }
    }

    /// The slot Duck asks macOS for. Smaller sits further right. Duck keeps it in step with
    /// wherever the mark was last dragged, so the five items travel together.
    @Published public var seat: Double {
        didSet { defaults.set(seat, forKey: Key.seat) }
    }

    /// How many times Duck has seated its items. Part of every item's name, because macOS
    /// only honours a position for a name it has never seen.
    public var seating: Int {
        didSet { defaults.set(seating, forKey: Key.seating) }
    }

    /// The version whose notes have already been shown. Empty until Duck has shown a set
    /// once, which on an existing install means the update that first carried this.
    public var lastSeenVersion: String {
        didSet { defaults.set(lastSeenVersion, forKey: Key.lastSeenVersion) }
    }

    /// True once Duck has been used rather than merely installed. Both of these are only
    /// ever written by a real hide, so together they separate someone updating from
    /// someone opening Duck for the first time.
    public var hasUsedDuckBefore: Bool { hasHiddenBefore || hidingWidth > 0 }

    /// Whether this launch should show what changed.
    ///
    /// A fresh install gets nothing: the app is all new, and a list of what changed in it
    /// means nothing to someone who has never seen the old one. An install that has been
    /// used before gets the notes once per version. `lastSeen` is empty on the first
    /// launch after the update that brought this panel, which is exactly the launch that
    /// should show it.
    public static func shouldShowNotes(current: String, lastSeen: String, hasUsedDuckBefore: Bool) -> Bool {
        guard !current.isEmpty else { return false }
        guard !lastSeen.isEmpty else { return hasUsedDuckBefore }
        return lastSeen != current
    }

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Key.autoHide: true,
            Key.autoHideSeconds: Preferences.defaultAutoHideSeconds,
            Key.hasHiddenBefore: false,
            Key.markStyle: MarkStyle.plus.rawValue,
            Key.showInDock: false,
            Key.seat: 120.0,
        ])

        autoHide = defaults.bool(forKey: Key.autoHide)
        let storedSeconds = defaults.double(forKey: Key.autoHideSeconds)
        autoHideSeconds = Preferences.autoHideChoices.contains(storedSeconds)
            ? storedSeconds
            : Preferences.defaultAutoHideSeconds
        hasHiddenBefore = defaults.bool(forKey: Key.hasHiddenBefore)
        hidingWidth = defaults.double(forKey: Key.hidingWidth)
        hidingBarWidth = defaults.double(forKey: Key.hidingBarWidth)
        markStyle = MarkStyle(rawValue: defaults.string(forKey: Key.markStyle) ?? "") ?? .plus
        showInDock = defaults.bool(forKey: Key.showInDock)
        seat = defaults.double(forKey: Key.seat)
        seating = defaults.integer(forKey: Key.seating)
        lastSeenVersion = defaults.string(forKey: Key.lastSeenVersion) ?? ""
    }
}
