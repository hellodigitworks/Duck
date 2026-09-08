import AppKit
import DuckCore

/// The one mark Duck puts in the menu bar, in whichever of the five looks the person
/// picked. Every look is a pair: one shape while the icons are hidden (fraction 0), another
/// while they are showing (1), and the frames in between so the change is a small motion
/// rather than a swap.
///
/// - plus:    a plus that turns 45 degrees into an ✕
/// - chevron: ‹ that flips to ›
/// - dot:     a filled dot that empties to a ring
/// - line:    a dash that stands up
/// - corner:  a folded corner that flips over
///
/// Drawn rather than SF Symbols, because the motion has to land on any point between the
/// two. Sized and weighted to sit with the system's own menu bar glyphs.
enum Mark {
    private static let box: CGFloat = 18
    private static let arm: CGFloat = 6.6
    private static let stroke: CGFloat = 1.7
    private static let steps = 25

    /// Frames from hidden (0) to showing (1), one set per look, drawn the first time asked.
    private static var frames: [MarkStyle: [NSImage]] = [:]

    static func image(style: MarkStyle, fraction: CGFloat) -> NSImage {
        let set = frames(for: style)
        let clamped = min(max(fraction, 0), 1)
        return set[Int((clamped * CGFloat(set.count - 1)).rounded())]
    }

    private static func frames(for style: MarkStyle) -> [NSImage] {
        if let set = frames[style] { return set }
        let set = (0..<steps).map { draw(style: style, fraction: CGFloat($0) / CGFloat(steps - 1)) }
        frames[style] = set
        return set
    }

    private static func draw(style: MarkStyle, fraction: CGFloat) -> NSImage {
        let image = NSImage(size: NSSize(width: box, height: box), flipped: false) { rect in
            let center = CGPoint(x: rect.midX, y: rect.midY)
            NSColor.black.set()
            switch style {
            case .plus: plus(at: center, fraction: fraction)
            case .chevron: chevron(at: center, fraction: fraction)
            case .dot: dot(at: center, fraction: fraction)
            case .line: line(at: center, fraction: fraction)
            case .corner: corner(at: center, fraction: fraction)
            }
            return true
        }
        // Template: the menu bar tints it for light and dark on its own.
        image.isTemplate = true
        return image
    }

    /// The line that stands at the far left while the icons are showing. Everything between
    /// it and the mark is what hides. Its own menu bar item, so it can sit out past the
    /// icons where the mark cannot.
    static let rule: NSImage = {
        let width: CGFloat = 5
        let height: CGFloat = 13
        let image = NSImage(size: NSSize(width: width, height: box), flipped: false) { rect in
            NSColor.black.withAlphaComponent(0.45).set()
            NSBezierPath(rect: NSRect(
                x: rect.midX - 0.5, y: rect.midY - height / 2, width: 1, height: height)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }()

    private static func path() -> NSBezierPath {
        let path = NSBezierPath()
        path.lineWidth = stroke
        path.lineCapStyle = .round
        path.lineJoinStyle = .round
        return path
    }

    /// Two strokes through the centre, turning from upright to 45 degrees.
    private static func plus(at center: CGPoint, fraction: CGFloat) {
        let angle = fraction * .pi / 4
        let path = path()
        for base in [CGFloat.zero, .pi / 2] {
            let dx = cos(base + angle) * arm
            let dy = sin(base + angle) * arm
            path.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
            path.line(to: CGPoint(x: center.x + dx, y: center.y + dy))
        }
        path.stroke()
    }

    /// One stroke, lying flat at 0 and standing at 1.
    private static func line(at center: CGPoint, fraction: CGFloat) {
        let angle = fraction * .pi / 2
        let dx = cos(angle) * arm
        let dy = sin(angle) * arm
        let path = path()
        path.move(to: CGPoint(x: center.x - dx, y: center.y - dy))
        path.line(to: CGPoint(x: center.x + dx, y: center.y + dy))
        path.stroke()
    }

    /// ‹ at 0, › at 1. It narrows to a bar halfway and opens out the other way.
    private static func chevron(at center: CGPoint, fraction: CGFloat) {
        let lean = cos(fraction * .pi) * 3.2
        let tip = CGPoint(x: center.x - lean, y: center.y)
        let path = path()
        path.move(to: CGPoint(x: center.x + lean, y: center.y + 5.4))
        path.line(to: tip)
        path.line(to: CGPoint(x: center.x + lean, y: center.y - 5.4))
        path.stroke()
    }

    /// A filled dot at 0 that empties into a ring by 1.
    private static func dot(at center: CGPoint, fraction: CGFloat) {
        let radius: CGFloat = 5
        let ring = NSBezierPath(ovalIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        ring.lineWidth = stroke
        ring.stroke()
        NSColor.black.withAlphaComponent(1 - fraction).setFill()
        ring.fill()
    }

    /// A folded corner: the top-right half of a square at 0, flipped to the bottom-right by 1.
    private static func corner(at center: CGPoint, fraction: CGFloat) {
        let half: CGFloat = 5.2
        let flip = cos(fraction * .pi)
        let path = path()
        path.move(to: CGPoint(x: center.x - half, y: center.y + half * flip))
        path.line(to: CGPoint(x: center.x + half, y: center.y + half * flip))
        path.line(to: CGPoint(x: center.x + half, y: center.y - half * flip))
        path.close()
        path.fill()
        path.stroke()
    }
}
