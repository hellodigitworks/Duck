// Makes the Duck app icon from icons/duck.svg.
// The duck sits on a cream rounded square with a margin, the macOS way, at every size an
// iconset needs, and iconutil folds them into icons/AppIcon.icns. A second tile, ink with
// the duck in cream, goes to icons/AppIcon-dark.png: the app puts that one in the Dock
// while the Mac is in dark mode, since an .icns cannot carry two looks on its own.
//
// macOS 26 and later draw app icons themselves, in glass, and in light, dark, clear and
// tinted looks. They read icons/AppIcon.icon, an Icon Composer document this script also
// writes: the same cream tile and ink duck, swapped to an ink tile and cream duck in dark
// mode. Given only the .icns, macOS darkens the cream tile on its own and the ink duck all
// but disappears into it. make-app.sh compiles the document into the app with actool.
//
// Regenerate with: swift scripts/make-icon.swift
// Input:  icons/duck.svg, the master. Change the duck there, in Illustrator, never here.
// Output: icons/AppIcon.icns, icons/AppIcon-dark.png, icons/AppIcon.icon and the
//         intermediate icons/AppIcon.iconset. Open AppIcon.icon in Icon Composer (inside
//         Xcode) to see every look, but change it here, or the next run undoes it.
// make-images.swift reads the same duck.svg for the page, the README and the lab shot,
// so one drawing is the duck everywhere.

import AppKit

let cream = NSColor(red: 0.957, green: 0.937, blue: 0.902, alpha: 1.0)
let ink = NSColor(red: 0.078, green: 0.071, blue: 0.059, alpha: 1.0)

let scriptDir = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
let root = scriptDir.deletingLastPathComponent()
let iconsDir = root.appendingPathComponent("icons")
let iconset = iconsDir.appendingPathComponent("AppIcon.iconset")

guard let duck = NSImage(contentsOf: iconsDir.appendingPathComponent("duck.svg")) else {
    fatalError("icons/duck.svg is missing. It is drawn by hand, so nothing here can make it.")
}

/// One tile. A cream rounded square with a margin and transparent corners, and the duck
/// centred on it at 72% of the square, so it breathes the way Apple's own icons do. The
/// drawing fills its own box edge to edge, which is why it needs the room.
func draw(size px: Int, dark: Bool = false) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
        samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    ctx.imageInterpolation = .high

    let s = CGFloat(px)
    let margin = s * 0.09
    let tile = NSRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let radius = tile.width * 0.225
    (dark ? ink : cream).setFill()
    NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius).fill()

    // Fit the drawing in a square 72% of the tile, keeping its own proportions.
    let box = tile.width * 0.72
    let scale = box / max(duck.size.width, duck.size.height)
    let w = duck.size.width * scale
    let h = duck.size.height * scale
    let bird = dark ? recoloured(duck, to: cream) : duck
    bird.draw(in: NSRect(x: tile.midX - w / 2, y: tile.midY - h / 2, width: w, height: h),
              from: .zero, operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

/// The same drawing in another colour: the duck's own shape, filled through its alpha.
func recoloured(_ image: NSImage, to colour: NSColor) -> NSImage {
    let out = NSImage(size: NSSize(width: 1024, height: 1024 * image.size.height / image.size.width))
    out.lockFocus()
    image.draw(in: NSRect(origin: .zero, size: out.size), from: .zero, operation: .sourceOver, fraction: 1)
    colour.set()
    NSRect(origin: .zero, size: out.size).fill(using: .sourceAtop)
    out.unlockFocus()
    return out
}

try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    let rep = draw(size: px)
    guard let data = rep.representation(using: .png, properties: [:]) else { continue }
    try? data.write(to: iconset.appendingPathComponent("\(name).png"))
}

if let data = draw(size: 1024, dark: true).representation(using: .png, properties: [:]) {
    try? data.write(to: iconsDir.appendingPathComponent("AppIcon-dark.png"))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset.path, "-o", iconsDir.appendingPathComponent("AppIcon.icns").path]
try task.run()
task.waitUntilExit()
print(task.terminationStatus == 0 ? "AppIcon.icns and AppIcon-dark.png written from icons/duck.svg" : "iconutil failed")

// The Icon Composer document: a folder holding icon.json and the drawing it points at.
// Colours are the cream and ink above, written the way Icon Composer writes them.
// Scale 10.2 puts the 58pt-wide drawing about 72% across the tile, as in the .icns.
let document = iconsDir.appendingPathComponent("AppIcon.icon")
let assets = document.appendingPathComponent("Assets")
try? FileManager.default.removeItem(at: document)
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
try FileManager.default.copyItem(
    at: iconsDir.appendingPathComponent("duck.svg"), to: assets.appendingPathComponent("duck.svg"))
func srgb(_ c: NSColor) -> String {
    String(format: "srgb:%.5f,%.5f,%.5f,1.00000", c.redComponent, c.greenComponent, c.blueComponent)
}
let json = """
{
  "fill-specializations" : [
    { "value" : { "solid" : "\(srgb(cream))" } },
    { "appearance" : "dark", "value" : { "solid" : "\(srgb(ink))" } }
  ],
  "groups" : [
    {
      "layers" : [
        {
          "fill-specializations" : [
            { "value" : { "solid" : "\(srgb(ink))" } },
            { "appearance" : "dark", "value" : { "solid" : "\(srgb(cream))" } }
          ],
          "image-name" : "duck.svg",
          "name" : "duck",
          "position" : { "scale" : 10.2, "translation-in-points" : [ 0, 0 ] }
        }
      ],
      "shadow" : { "kind" : "neutral", "opacity" : 0.5 },
      "translucency" : { "enabled" : false, "value" : 0.5 }
    }
  ],
  "supported-platforms" : { "squares" : "shared" }
}

"""
try json.write(to: document.appendingPathComponent("icon.json"), atomically: true, encoding: .utf8)
print("AppIcon.icon written from icons/duck.svg")
