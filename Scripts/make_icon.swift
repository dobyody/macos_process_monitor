// Generates the DevMonitor app icon (1024×1024 PNG).
// Usage: swift Scripts/make_icon.swift Assets/icon_1024.png
import AppKit

let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Assets/icon_1024.png"

let size: CGFloat = 1024

// Brand gradient: indigo → violet
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.42, green: 0.36, blue: 0.96, alpha: 1),  // indigo
    NSColor(calibratedRed: 0.61, green: 0.36, blue: 0.96, alpha: 1),  // violet
])!

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else {
    fatalError("no graphics context")
}

// Squircle tile (macOS-style margin + corner radius)
let inset: CGFloat = 34
let radius: CGFloat = 228
let tile = NSBezierPath(roundedRect: NSRect(x: inset, y: inset, width: size - 2 * inset, height: size - 2 * inset),
                        xRadius: radius, yRadius: radius)
tile.addClip()
gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -60)

// Soft highlight, top-left
ctx.saveGState()
let highlight = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [NSColor.white.withAlphaComponent(0.22).cgColor,
                                    NSColor.white.withAlphaComponent(0).cgColor] as CFArray,
                           locations: [0, 0.6])!
ctx.drawLinearGradient(highlight,
                       start: CGPoint(x: 200, y: 1024),
                       end: CGPoint(x: 700, y: 400),
                       options: [])
ctx.restoreGState()

// Glyph: </>
func stroke(_ build: (inout CGMutablePath) -> Void, width: CGFloat) {
    var path = CGMutablePath()
    build(&path)
    ctx.addPath(path)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.setStrokeColor(NSColor.white.cgColor)
    // gentle white glow behind the strokes
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28,
                  color: NSColor.white.withAlphaComponent(0.35).cgColor)
    ctx.strokePath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
}

let lw: CGFloat = 66
// left chevron  ‹
stroke({ p in
    p.move(to: CGPoint(x: 356, y: 706))
    p.addLine(to: CGPoint(x: 186, y: 512))
    p.addLine(to: CGPoint(x: 356, y: 318))
}, width: lw)
// right chevron  ›
stroke({ p in
    p.move(to: CGPoint(x: 668, y: 318))
    p.addLine(to: CGPoint(x: 838, y: 512))
    p.addLine(to: CGPoint(x: 668, y: 706))
}, width: lw)
// slash  /
stroke({ p in
    p.move(to: CGPoint(x: 583, y: 288))
    p.addLine(to: CGPoint(x: 441, y: 736))
}, width: lw)

// three "process" dots, bottom-left of the glyph
for (i, alpha) in [0.95, 0.55, 0.25].enumerated() {
    let dot = NSBezierPath(ovalIn: NSRect(x: 186 + CGFloat(i) * 62, y: 150, width: 34, height: 34))
    NSColor.white.withAlphaComponent(alpha).setFill()
    dot.fill()
}

image.unlockFocus()

let dir = (output as NSString).deletingLastPathComponent
try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encoding failed")
}
try png.write(to: URL(fileURLWithPath: output))
print("✓ wrote \(output)")
