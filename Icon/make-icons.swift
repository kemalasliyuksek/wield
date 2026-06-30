// Regenerates the app icon (dark) and the menu bar template from glyph.png.
// Run via ./build-icons.sh (which compiles with the Swift toolchain).
//
//   Output:
//     ../Resources/AppIcon.icns      dark squircle app icon (Finder/Launchpad/About)
//     ../Resources/MenuBarIcon.png   simplified monochrome template (menu bar)
//
// glyph.png is the white line-art exported from the Icon Composer source
// (wield.icon). Edit the colors/sizes below and re-run to iterate.

import AppKit
import CoreGraphics

let here = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let glyphURL = here.appendingPathComponent("glyph.png")
let resources = here.deletingLastPathComponent().appendingPathComponent("Resources")
let tmpIconset = here.appendingPathComponent(".wield.iconset")

let cs = CGColorSpaceCreateDeviceRGB()
let white = CGColor(red: 1, green: 1, blue: 1, alpha: 1)

guard let ns = NSImage(contentsOf: glyphURL),
      let glyph = ns.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write(Data("Cannot load glyph.png\n".utf8)); exit(1)
}

func newCtx(_ S: Int) -> CGContext {
    CGContext(data: nil, width: S, height: S, bitsPerComponent: 8, bytesPerRow: 0,
              space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
}
func writePNG(_ image: CGImage, to url: URL) {
    let rep = NSBitmapImageRep(cgImage: image)
    rep.size = NSSize(width: image.width, height: image.height)
    try? rep.representation(using: .png, properties: [:])?.write(to: url)
}

// MARK: Dark app icon
func darkIcon(_ S: Int) -> CGImage {
    let ctx = newCtx(S)
    let f = CGFloat(S)
    let side = f * 0.82
    let o = (f - side) / 2
    let rect = CGRect(x: o, y: o, width: side, height: side)
    let radius = side * 0.2237
    let squircle = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -f * 0.012), blur: f * 0.03,
                  color: CGColor(red: 0, green: 0, blue: 0, alpha: 0.38))
    ctx.addPath(squircle)
    ctx.setFillColor(CGColor(red: 0.07, green: 0.08, blue: 0.12, alpha: 1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(squircle); ctx.clip()
    let grad = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 0.16, green: 0.19, blue: 0.27, alpha: 1),
        CGColor(red: 0.05, green: 0.06, blue: 0.11, alpha: 1)
    ] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: 0, y: f), end: CGPoint(x: 0, y: 0), options: [])
    let glow = CGGradient(colorsSpace: cs, colors: [
        CGColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 0.28),
        CGColor(red: 0.04, green: 0.52, blue: 1.0, alpha: 0.0)
    ] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(glow, startCenter: CGPoint(x: f/2, y: f*0.52), startRadius: 0,
                           endCenter: CGPoint(x: f/2, y: f*0.52), endRadius: f*0.34, options: [])
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.06))
    ctx.setLineWidth(f * 0.012)
    ctx.addPath(CGPath(roundedRect: rect.insetBy(dx: f*0.004, dy: f*0.004),
                       cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.strokePath()

    ctx.setShadow(offset: .zero, blur: f * 0.012,
                  color: CGColor(red: 0.6, green: 0.8, blue: 1.0, alpha: 0.5))
    let g = f * 0.80
    ctx.draw(glyph, in: CGRect(x: (f-g)/2, y: (f-g)/2, width: g, height: g))
    ctx.restoreGState()
    return ctx.makeImage()!
}

// MARK: Simplified menu bar template (window + 4-way move arrow)
func menuBarTemplate(_ S: Int) -> CGImage {
    let ctx = newCtx(S)
    let f = CGFloat(S), c = f/2
    ctx.setStrokeColor(white); ctx.setLineJoin(.round); ctx.setLineCap(.round)
    let m = f*0.105, side = f - 2*m
    ctx.setLineWidth(f*0.06)
    ctx.addPath(CGPath(roundedRect: CGRect(x: m, y: m, width: side, height: side),
                       cornerWidth: side*0.17, cornerHeight: side*0.17, transform: nil))
    ctx.strokePath()
    let d = f*0.255, hl = f*0.072
    ctx.setLineWidth(f*0.052)
    func line(_ a: CGPoint, _ b: CGPoint) { ctx.move(to: a); ctx.addLine(to: b) }
    line(CGPoint(x: c, y: c-d), CGPoint(x: c, y: c+d))
    line(CGPoint(x: c-d, y: c), CGPoint(x: c+d, y: c))
    line(CGPoint(x: c-hl, y: c+d-hl), CGPoint(x: c, y: c+d)); line(CGPoint(x: c+hl, y: c+d-hl), CGPoint(x: c, y: c+d))
    line(CGPoint(x: c-hl, y: c-d+hl), CGPoint(x: c, y: c-d)); line(CGPoint(x: c+hl, y: c-d+hl), CGPoint(x: c, y: c-d))
    line(CGPoint(x: c-d+hl, y: c-hl), CGPoint(x: c-d, y: c)); line(CGPoint(x: c-d+hl, y: c+hl), CGPoint(x: c-d, y: c))
    line(CGPoint(x: c+d-hl, y: c-hl), CGPoint(x: c+d, y: c)); line(CGPoint(x: c+d-hl, y: c+hl), CGPoint(x: c+d, y: c))
    ctx.strokePath()
    return ctx.makeImage()!
}

// MARK: Emit
let map: [(String, Int)] = [
    ("icon_16x16.png", 16), ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32), ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128), ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256), ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512), ("icon_512x512@2x.png", 1024)
]
try? FileManager.default.removeItem(at: tmpIconset)
try? FileManager.default.createDirectory(at: tmpIconset, withIntermediateDirectories: true)
var cache: [Int: CGImage] = [:]
for (name, s) in map {
    let img = cache[s] ?? darkIcon(s); cache[s] = img
    writePNG(img, to: tmpIconset.appendingPathComponent(name))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", tmpIconset.path,
                  "-o", resources.appendingPathComponent("AppIcon.icns").path]
try? task.run(); task.waitUntilExit()
try? FileManager.default.removeItem(at: tmpIconset)

writePNG(menuBarTemplate(256), to: resources.appendingPathComponent("MenuBarIcon.png"))
print("Wrote Resources/AppIcon.icns and Resources/MenuBarIcon.png")
