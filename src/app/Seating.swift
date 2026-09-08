import AppKit
import DuckCore

/// Where Duck's items sit in the menu bar, and how they are kept together.
///
/// Duck hides by widening invisible items that sit to the left of the mark, and a widened
/// item only pushes what is on its left. So the five have to be one unbroken run with the
/// mark on its right end. They do not stay that way on their own. macOS hands out menu bar
/// slots and remembers them by item name, so another app's icon drifts in between, and
/// ⌘-dragging the mark leaves the rest behind. Anything caught between the last spacer and
/// the mark can never be hidden, at any width.
///
/// The one lever macOS still honours is `NSStatusItem Preferred Position`, and only for a
/// name it has never seen: written for a name already in use it is ignored. Measured on
/// macOS 27, along with the useful part, that five consecutive positions come back as one
/// unbroken run, in order, with the first item made on the right.
///
/// So every name carries a seating number, and re-seating is: take the next number, write
/// the positions, make the items again.
enum Seating {
    private static let prefix = "NSStatusItem Preferred Position "

    /// Positions outside this range put the items somewhere macOS never draws.
    static let range: ClosedRange<Double> = 40...400
    static let fallback: Double = 120

    /// The name an item goes by at one seating. Never reused: once macOS has seen a name it
    /// keeps the slot it gave that name and ignores anything asked for afterwards.
    static func name(_ role: String, seating: Int) -> String { "duck.\(role).s\(seating)" }

    /// The names of a whole seating, mark first, in the order they must be made.
    static func names(spacers: Int, seating: Int) -> [String] {
        [name("mark", seating: seating)] + (0..<spacers).map { name("spacer\($0)", seating: seating) }
    }

    /// Where the line stands: as far left as macOS will place a third-party item, so every
    /// icon that hides is on the near side of it. Measured on macOS 27, anything past about
    /// 340 lands on the same leftmost slot.
    static let edgePosition: Double = 400

    /// Asks macOS for one slot, for an item that sits away from the block.
    static func claimOne(_ name: String, at position: Double) {
        UserDefaults.standard.set(position, forKey: prefix + name)
    }

    /// Asks macOS for consecutive slots, mark first. Has to be written before the items are
    /// made: this is read once, as an item appears, and never again.
    static func claim(_ names: [String], from position: Double) {
        let start = min(max(position, range.lowerBound), range.upperBound)
        for (offset, name) in names.enumerated() {
            UserDefaults.standard.set(start + Double(offset), forKey: prefix + name)
        }
    }

    /// Drops the positions asked for at every earlier seating, and the old unnumbered names
    /// from before Duck seated anything, so the defaults file does not collect a line per
    /// re-seat forever.
    static func forget(keeping names: [String]) {
        let keep = Set(names.map { prefix + $0 })
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys
        where key.hasPrefix(prefix + "duck.") && !keep.contains(key) {
            defaults.removeObject(forKey: key)
        }
    }
}
