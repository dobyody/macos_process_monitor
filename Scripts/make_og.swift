// Generates the GitHub social preview (docs/og.png, 1280×640).
// Usage: swift Scripts/make_og.swift docs/og.png
import AppKit

let output = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "docs/og.png"

let W: CGFloat = 1280, H: CGFloat = 640

let image = NSImage(size: NSSize(width: W, height: H))
image.lockFocus()
guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("no ctx") }

// Background: deep indigo → near-black
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [
                        NSColor(calibratedRed: 0.16, green: 0.10, blue: 0.42, alpha: 1).cgColor,
                        NSColor(calibratedWhite: 0.05, alpha: 1).cgColor
                    ] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: 0, y: H), end: CGPoint(x: W, y: 0), options: [])

// Faint oversized glyph watermark, right side
ctx.saveGState()
ctx.translateBy(x: W - 300, y: H / 2 - 210)
ctx.scaleBy(x: 2.6, y: 2.6)
ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.05).cgColor)
ctx.setLineWidth(24)
ctx.setLineCap(.round); ctx.setLineJoin(.round)
var watermark = CGMutablePath()
watermark.move(to: CGPoint(x: 34, y: 30)); watermark.addLine(to: CGPoint(x: 12, y: 50)); watermark.addLine(to: CGPoint(x: 34, y: 70))
watermark.move(to: CGPoint(x: 66, y: 30)); watermark.addLine(to: CGPoint(x: 88, y: 50)); watermark.addLine(to: CGPoint(x: 66, y: 70))
watermark.move(to: CGPoint(x: 56, y: 22)); watermark.addLine(to: CGPoint(x: 44, y: 78))
ctx.addPath(watermark); ctx.strokePath()
ctx.restoreGState()

func draw(string: String, x: CGFloat, y: CGFloat, size: CGFloat,
          weight: NSFont.Weight = .bold, color: NSColor = .white, alpha: CGFloat = 1) {
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color.withAlphaComponent(alpha)
    ]
    (string as NSString).draw(at: NSPoint(x: x, y: y), withAttributes: attrs)
}

// Left: logo tile
let tileSide: CGFloat = 220
let tileRect = NSRect(x: 96, y: H / 2 - tileSide / 2 + 40, width: tileSide, height: tileSide)
let tile = NSBezierPath(roundedRect: tileRect, xRadius: 56, yRadius: 56)
NSGradient(colors: [
    NSColor(calibratedRed: 0.42, green: 0.36, blue: 0.96, alpha: 1),
    NSColor(calibratedRed: 0.61, green: 0.36, blue: 0.96, alpha: 1)
])!.draw(in: tileRect, angle: -60)

// Glyph inside the tile
ctx.saveGState()
ctx.translateBy(x: tileRect.origin.x, y: tileRect.origin.y)
ctx.setStrokeColor(NSColor.white.cgColor)
ctx.setLineWidth(20); ctx.setLineCap(.round); ctx.setLineJoin(.round)
var glyph = CGMutablePath()
let s = tileSide
glyph.move(to: CGPoint(x: s * 0.36, y: s * 0.32)); glyph.addLine(to: CGPoint(x: s * 0.16, y: s * 0.50)); glyph.addLine(to: CGPoint(x: s * 0.36, y: s * 0.68))
glyph.move(to: CGPoint(x: s * 0.64, y: s * 0.32)); glyph.addLine(to: CGPoint(x: s * 0.84, y: s * 0.50)); glyph.addLine(to: CGPoint(x: s * 0.64, y: s * 0.68))
glyph.move(to: CGPoint(x: s * 0.56, y: s * 0.24)); glyph.addLine(to: CGPoint(x: s * 0.44, y: s * 0.76))
ctx.addPath(glyph); ctx.strokePath()
ctx.restoreGState()

// Right: title + tagline + chips
let textX: CGFloat = tileRect.maxX + 64
draw(string: "DevMonitor", x: textX, y: H / 2 + 92, size: 92, weight: .heavy)
draw(string: "macOS menu bar process monitor for developers",
     x: textX + 4, y: H / 2 + 30, size: 33, weight: .semibold,
     color: NSColor(calibratedWhite: 1, alpha: 1), alpha: 0.82)
draw(string: "node · python · go · rust · docker — grouped by project,",
     x: textX + 4, y: H / 2 - 34, size: 26, weight: .regular, alpha: 0.6)
draw(string: "with CPU, RAM, ports and one-click kill",
     x: textX + 4, y: H / 2 - 74, size: 26, weight: .regular, alpha: 0.6)

// github tagline, bottom-right
draw(string: "github.com/dobyody/macos_process_monitor",
     x: W - 560, y: 44, size: 24, weight: .medium, alpha: 0.5)

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("png encoding failed")
}
try png.write(to: URL(fileURLWithPath: output))
print("✓ wrote \(output)")
