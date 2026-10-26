// Rendert Vorschläge für die Wortmarke „nomi“: sechs Varianten, jeweils auf Himbeere und auf Creme.
// Aufruf: swift design/wordmark/render-wordmarks.swift Nomi/Resources/Fonts design/wordmark/vorschlaege.png
import AppKit
import CoreText

let fontDir = URL(fileURLWithPath: CommandLine.arguments[1])
for f in try! FileManager.default.contentsOfDirectory(at: fontDir, includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}

func c(_ h: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1)
}
let ink: UInt32 = 0x262B28, inkMuted: UInt32 = 0x6E726F, brand: UInt32 = 0xCC335E, canvas: UInt32 = 0xF7F4EE
let ochre: UInt32 = 0xF2B33D, white: UInt32 = 0xFFFFFF, cream: UInt32 = 0xFFF6E8, blush: UInt32 = 0xF4A0B5

struct Palette { let text: UInt32; let accent: UInt32; let face: UInt32; let bg: UInt32 }
let onBrand = Palette(text: white, accent: ochre, face: cream, bg: brand)
let onCream = Palette(text: ink, accent: brand, face: brand, bg: canvas)

let size: CGFloat = 120
let font = CTFontCreateWithName("BricolageGrotesque96pt-ExtraBold" as CFString, size, nil)
let xHeight = CTFontGetXHeight(font)
let kern = -0.045 * size

var ctx: CGContext!

/// Zeichnet ein Zeichen und gibt seine Breite zurück
@discardableResult
func glyph(_ s: String, x: CGFloat, baseline: CGFloat, color: UInt32) -> CGFloat {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: c(color)]))
    ctx.textPosition = CGPoint(x: x, y: baseline)
    CTLineDraw(line, ctx)
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) + kern
}
func advance(_ s: String) -> CGFloat {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font]))
    return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil)) + kern
}
func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r), transform: nil) }
func fill(_ p: CGPath, _ color: UInt32) { ctx.addPath(p); ctx.setFillColor(c(color)); ctx.fillPath() }
func heart(_ cx: CGFloat, _ cy: CGFloat, _ s: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: cx, y: cy - 0.9 * s))
    p.addCurve(to: CGPoint(x: cx - s, y: cy + 0.15 * s), control1: CGPoint(x: cx - 0.35 * s, y: cy - 0.45 * s), control2: CGPoint(x: cx - s, y: cy - 0.3 * s))
    p.addCurve(to: CGPoint(x: cx, y: cy + 0.35 * s), control1: CGPoint(x: cx - s, y: cy + 0.75 * s), control2: CGPoint(x: cx - 0.2 * s, y: cy + 0.8 * s))
    p.addCurve(to: CGPoint(x: cx + s, y: cy + 0.15 * s), control1: CGPoint(x: cx + 0.2 * s, y: cy + 0.8 * s), control2: CGPoint(x: cx + s, y: cy + 0.75 * s))
    p.addCurve(to: CGPoint(x: cx, y: cy - 0.9 * s), control1: CGPoint(x: cx + s, y: cy - 0.3 * s), control2: CGPoint(x: cx + 0.35 * s, y: cy - 0.45 * s))
    p.closeSubpath()
    return p
}

/// Breite des Wortes ohne i-Punkt (dotless i), für die Zentrierung
let wordWidth = advance("n") + advance("o") + advance("m") + advance("ı") - kern

/// Position des i-Punkts: Mitte über dem dotless i
func iDotCenter(start x: CGFloat, baseline: CGFloat) -> CGPoint {
    let ix = x + advance("n") + advance("o") + advance("m")
    let iw = advance("ı") - kern
    return CGPoint(x: ix + iw / 2, y: baseline + xHeight + size * 0.2)
}

struct Variant {
    let name: String
    let note: String
    let draw: (CGFloat, CGFloat, Palette) -> Void   // x, baseline, Farben
}

let variants: [Variant] = [
    Variant(name: "Klar", note: "Wie heute: Bricolage ExtraBold, eng gesetzt. Ruhig, funktioniert überall.") { x, b, p in
        var x = x
        for ch in ["n", "o", "m", "i"] { x += glyph(ch, x: x, baseline: b, color: p.text) }
    },
    Variant(name: "Herz-Punkt", note: "Der i-Punkt wird ein Herz – „mit Liebe gekocht“, klein auch als App-Detail nutzbar.") { x, b, p in
        var cx = x
        for ch in ["n", "o", "m", "ı"] { cx += glyph(ch, x: cx, baseline: b, color: p.text) }
        let d = iDotCenter(start: x, baseline: b)
        fill(heart(d.x, d.y + size * 0.03, size * 0.135), p.accent)
    },
    Variant(name: "Mützen-i", note: "Chefis Kochmütze sitzt auf dem i. Verbindet Wortmarke und Maskottchen.") { x, b, p in
        var cx = x
        for ch in ["n", "o", "m", "ı"] { cx += glyph(ch, x: cx, baseline: b, color: p.text) }
        let d = iDotCenter(start: x, baseline: b)
        let r = size * 0.075
        for (dx, dy, rr) in [(-r * 1.15, 0.0, r), (r * 1.15, 0.0, r), (0.0, r * 0.55, r * 1.2)] as [(CGFloat, CGFloat, CGFloat)] {
            fill(circle(d.x + dx, d.y + r * 0.6 + dy, rr), p.text)
        }
        fill(CGPath(roundedRect: CGRect(x: d.x - r * 1.9, y: d.y - r * 0.95, width: r * 3.8, height: r * 1.35), cornerWidth: r * 0.4, cornerHeight: r * 0.4, transform: nil), p.accent)
    },
    Variant(name: "Teller-o", note: "Das o wird ein Teller mit Rand. Sofort „Essen“, ohne verspielt zu wirken.") { x, b, p in
        var cx = x
        cx += glyph("n", x: cx, baseline: b, color: p.text)
        let ow = advance("o") - kern
        let center = CGPoint(x: cx + ow / 2, y: b + xHeight / 2)
        let r = xHeight / 2
        ctx.setStrokeColor(c(p.text)); ctx.setLineWidth(size * 0.105)
        ctx.addPath(circle(center.x, center.y, r - size * 0.052)); ctx.strokePath()
        ctx.setStrokeColor(c(p.accent)); ctx.setLineWidth(size * 0.03)
        ctx.addPath(circle(center.x, center.y, r * 0.42)); ctx.strokePath()
        cx += advance("o")
        for ch in ["m", "i"] { cx += glyph(ch, x: cx, baseline: b, color: p.text) }
    },
    Variant(name: "Gesichts-o", note: "Das o lächelt: nomi als freundlicher Assistent, passend zu Chefi und dem Tab-Symbol.") { x, b, p in
        var cx = x
        cx += glyph("n", x: cx, baseline: b, color: p.text)
        let ow = advance("o") - kern
        let center = CGPoint(x: cx + ow / 2, y: b + xHeight / 2)
        let r = xHeight / 2 + size * 0.01
        fill(circle(center.x, center.y, r), p.face)
        let featureColor = p.bg == brand ? ink : white
        fill(circle(center.x - r * 0.36, center.y + r * 0.18, r * 0.12), featureColor)
        fill(circle(center.x + r * 0.36, center.y + r * 0.18, r * 0.12), featureColor)
        let smile = CGMutablePath()
        smile.addArc(center: CGPoint(x: center.x, y: center.y + r * 0.02), radius: r * 0.42, startAngle: -0.45, endAngle: -.pi + 0.45, clockwise: true)
        ctx.addPath(smile); ctx.setStrokeColor(c(featureColor)); ctx.setLineWidth(r * 0.13); ctx.setLineCap(.round); ctx.strokePath()
        cx += advance("o")
        for ch in ["m", "i"] { cx += glyph(ch, x: cx, baseline: b, color: p.text) }
    },
    Variant(name: "Lächeln", note: "Ein Löffel-Lächeln unter „nom“ in Akzentfarbe. Warm, bleibt aber Schrift.") { x, b, p in
        var cx = x
        for ch in ["n", "o", "m", "i"] { cx += glyph(ch, x: cx, baseline: b, color: p.text) }
        let from = x + size * 0.06, to = x + advance("n") + advance("o") + advance("m") - size * 0.08
        let smile = CGMutablePath()
        smile.move(to: CGPoint(x: from, y: b - size * 0.09))
        smile.addQuadCurve(to: CGPoint(x: to, y: b - size * 0.09), control: CGPoint(x: (from + to) / 2, y: b - size * 0.3))
        ctx.addPath(smile); ctx.setStrokeColor(c(p.accent)); ctx.setLineWidth(size * 0.07); ctx.setLineCap(.round); ctx.strokePath()
        // Löffelmulde am rechten Ende
        fill(CGPath(ellipseIn: CGRect(x: to - size * 0.02, y: b - size * 0.14, width: size * 0.16, height: size * 0.11), transform: nil), p.accent)
    },
]

// MARK: - Bogen

let tileW: CGFloat = 520, tileH: CGFloat = 230, gap: CGFloat = 30, cols = 3
let rowsCount = Int(ceil(Double(variants.count) / Double(cols)))
let rowH = tileH * 2 + gap + 110
let W = Int(CGFloat(cols) * (tileW + gap) + gap + 30), H = Int(CGFloat(rowsCount) * rowH + 130)
ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(c(canvas)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

func label(_ s: String, font name: String, size: CGFloat, color: UInt32, at p: CGPoint, width: CGFloat? = nil) {
    let f = CTFontCreateWithName(name as CFString, size, nil)
    let attr = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c(color)])
    if let width {
        let frame = CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attr), CFRange(), CGPath(rect: CGRect(x: p.x, y: p.y - 50, width: width, height: 60), transform: nil), nil)
        CTFrameDraw(frame, ctx)
    } else {
        ctx.textPosition = p; CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
    }
}

label("Wortmarke: Vorschläge", font: "BricolageGrotesque96pt-ExtraBold", size: 46, color: ink, at: CGPoint(x: 40, y: CGFloat(H) - 80))
for (i, v) in variants.enumerated() {
    let col = i % cols, row = i / cols
    let x0 = 40 + CGFloat(col) * (tileW + gap)
    let top = CGFloat(H) - 130 - CGFloat(row) * rowH
    label("\(i + 1) · \(v.name)", font: "BricolageGrotesque96pt-ExtraBold", size: 26, color: ink, at: CGPoint(x: x0, y: top - 30))
    label(v.note, font: "DMSans-Regular", size: 17, color: inkMuted, at: CGPoint(x: x0, y: top - 56), width: tileW)
    for (j, palette) in [onBrand, onCream].enumerated() {
        let tile = CGRect(x: x0, y: top - 110 - tileH - CGFloat(j) * (tileH + gap), width: tileW, height: tileH)
        ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 24, cornerHeight: 24, transform: nil))
        ctx.setFillColor(c(palette.bg)); ctx.fillPath()
        if palette.bg == canvas {
            ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 24, cornerHeight: 24, transform: nil))
            ctx.setStrokeColor(c(0xE6E1D8)); ctx.setLineWidth(1.5); ctx.strokePath()
        }
        ctx.saveGState()
        v.draw(tile.midX - wordWidth / 2, tile.midY - xHeight / 2 - 4, palette)
        ctx.restoreGState()
    }
}

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
