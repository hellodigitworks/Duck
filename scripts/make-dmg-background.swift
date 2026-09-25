// Draws the picture behind the Duck.dmg window: paper, a quiet arrow from where Finder puts
// Duck to where it puts Applications, and one line saying what to do.
// Run by scripts/make-dmg.sh, which passes the folder to write into:
//   swift scripts/make-dmg-background.swift <folder>
// Writes background.png (640×400) and background@2x.png (1280×800). make-dmg.sh joins the
// two into one file so Finder picks the sharp one on a Retina screen.
//
// A DMG window has one picture, whatever the Mac's appearance, so this is paper in dark
// mode too. The positions here must match the icon positions in make-dmg.sh.

import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent().deletingLastPathComponent()
let out = URL(fileURLWithPath: CommandLine.arguments[1])

let paper = NSColor(red: 0.957, green: 0.937, blue: 0.902, alpha: 1)
let ink = NSColor(red: 0.078, green: 0.071, blue: 0.059, alpha: 1)
let muted = NSColor(red: 0.435, green: 0.404, blue: 0.361, alpha: 1)

let width: CGFloat = 640
let height: CGFloat = 400
// Icon centres, measured from the top left as Finder measures them.
let duckX: CGFloat = 180
let appsX: CGFloat = 460
let iconY: CGFloat = 180

let inter: NSFont = {
    let url = root.appendingPathComponent("fonts/Inter-Regular.ttf")
    CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
    return NSFont(name: "Inter-Regular", size: 13) ?? .systemFont(ofSize: 13)
}()

func draw(scale: CGFloat, to name: String) {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: Int(width * scale), pixelsHigh: Int(height * scale),
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    // Drawing happens in points; the rep holds scale × as many pixels.
    rep.size = NSSize(width: width, height: height)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    paper.setFill()
    NSRect(x: 0, y: 0, width: width, height: height).fill()

    // The arrow: a hairline with an open head, in the gap between the two icons.
    let y = height - iconY
    let start = duckX + 76
    let end = appsX - 76
    let arrow = NSBezierPath()
    arrow.lineWidth = 1.5
    arrow.lineCapStyle = .round
    arrow.lineJoinStyle = .round
    arrow.move(to: NSPoint(x: start, y: y))
    arrow.line(to: NSPoint(x: end, y: y))
    arrow.move(to: NSPoint(x: end - 9, y: y + 9))
    arrow.line(to: NSPoint(x: end, y: y))
    arrow.line(to: NSPoint(x: end - 9, y: y - 9))
    ink.withAlphaComponent(0.55).setStroke()
    arrow.stroke()

    // One line under everything, centred.
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let line = NSAttributedString(string: "Drag Duck into Applications, then open it from there.", attributes: [
        .font: inter, .foregroundColor: muted, .paragraphStyle: style,
    ])
    line.draw(in: NSRect(x: 0, y: 58, width: width, height: 20))

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
}

try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
draw(scale: 1, to: "background.png")
draw(scale: 2, to: "background@2x.png")
