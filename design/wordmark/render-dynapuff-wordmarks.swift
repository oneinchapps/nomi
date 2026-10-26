// Wortmarke „nomi“ in DynaPuff: Varianten mit eigenem Detail – jeweils auf Himbeere, auf Creme und in Kopfzeilengröße.
// Aufruf: swift design/wordmark/render-dynapuff-wordmarks.swift <DynaPuff.ttf> Nomi/Resources/Fonts design/wordmark/dynapuff-vorschlaege.png
import AppKit
import CoreText

let fontURL = URL(fileURLWithPath: CommandLine.arguments[1])
for f in try! FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: CommandLine.arguments[2]), includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}

func c(_ h: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1)
}
let ink: UInt32 = 0x262B28, inkMuted: UInt32 = 0x6E726F, brand: UInt32 = 0xCC335E, canvas: UInt32 = 0xF7F4EE, white: UInt32 = 0xFFFFFF

struct Palette { let bg: UInt32; let text: UInt32; let accent: UInt32; let soft: UInt32; let leaf: UInt32 }
let onBrand = Palette(bg: brand, text: white, accent: 0xF2B33D, soft: 0xF6B3C4, leaf: 0x9CC48F)
let onCream = Palette(bg: canvas, text: brand, accent: 0xE8971C, soft: 0xE0587D, leaf: 0x6F8F6A)

// MARK: - DynaPuff als Pfade (Raster: Schriftgröße 100, Grundlinie 0)

func tag(_ s: String) -> Int { s.unicodeScalars.reduce(0) { $0 << 8 | Int($1.value) } }
let descriptor = CTFontDescriptorCreateCopyWithAttributes(
    (CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as! [CTFontDescriptor])[0],
    [kCTFontVariationAttribute: [NSNumber(value: tag("wght")): NSNumber(value: 650)]] as CFDictionary
)
let font = CTFontCreateWithFontDescriptor(descriptor, 100, nil)
let tracking: CGFloat = -2

/// Buchstaben als Pfade mit Position; „ı“ (ohne Punkt) für eigene i-Punkte
func letters(_ text: String) -> [CGPath] {
    var x: CGFloat = 0
    return text.map { ch in
        var unichar = Array(String(ch).utf16)
        var glyph = CGGlyph()
        CTFontGetGlyphsForCharacters(font, &unichar, &glyph, 1)
        var advance = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
        var t = CGAffineTransform(translationX: x, y: 0)
        let path = CTFontCreatePathForGlyph(font, glyph, &t) ?? CGMutablePath()
        x += advance.width + tracking
        return path
    }
}

let dotted = letters("nomi")
let plain = letters("nomı")
let xHeight = plain[0].boundingBox.maxY
/// i-Punkt: was „i“ mehr hat als „ı“
let iDot = CGRect(x: dotted[3].boundingBox.minX, y: plain[3].boundingBox.maxY, width: dotted[3].boundingBox.width, height: dotted[3].boundingBox.maxY - plain[3].boundingBox.maxY)
let dotCenter = CGPoint(x: dotted[3].boundingBox.midX, y: dotted[3].boundingBox.maxY - dotted[3].boundingBox.width / 2)
let oBox = plain[1].boundingBox

func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r), transform: nil) }
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
func leaf(_ x: CGFloat, _ y: CGFloat, _ len: CGFloat, deg: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: .zero)
    p.addQuadCurve(to: CGPoint(x: len, y: 0), control: CGPoint(x: len / 2, y: len * 0.45))
    p.addQuadCurve(to: .zero, control: CGPoint(x: len / 2, y: -len * 0.45))
    var t = CGAffineTransform(translationX: x, y: y).rotated(by: deg * .pi / 180)
    return p.copy(using: &t)!
}

/// Bissspur oben rechts im o: drei Zahnbögen nebeneinander
func biteMark() -> CGPath {
    let r = oBox.width * 0.17
    let corner = CGPoint(x: oBox.maxX - oBox.width * 0.08, y: oBox.maxY - oBox.height * 0.08)
    return [(-1.55, 0.55), (-0.35, -0.2), (0.5, -1.35)].map { circle(corner.x + $0.0 * r, corner.y + $0.1 * r, r) }
        .reduce(CGMutablePath() as CGPath) { $0.union($1) }
}

/// Ein Teil der Wortmarke: Pfad + Farbe (Füllung oder Linie)
enum Paint { case fill(UInt32), stroke(UInt32, CGFloat) }
typealias Piece = (path: CGPath, paint: Paint)

struct Variant { let name: String; let note: String; let pieces: (Palette) -> [Piece] }

func word(_ paths: [CGPath], _ p: Palette) -> [Piece] { paths.map { ($0, .fill(p.text)) } }

let variants: [Variant] = [
    Variant(name: "Pur", note: "DynaPuff ohne Zusatz – schon recht eigen, aber eben eine Schrift.") { p in word(dotted, p) },
    Variant(name: "Biss", note: "Ins o ist reingebissen – „nom nom“. Der Keks-Biss macht die Marke sofort einzigartig.") { p in
        let bite = biteMark()
        var paths = plain
        paths[1] = paths[1].subtracting(bite)
        paths[3] = dotted[3]
        return word(paths, p)
    },
    Variant(name: "Himbeer-Punkt", note: "Der i-Punkt ist eine kleine Himbeere – die Markenfarbe als Frucht, mit Blättchen.") { p in
        let r = iDot.width * 0.24
        var pieces = word(Array(plain), p)
        let center = CGPoint(x: dotCenter.x, y: dotCenter.y + r * 0.6)
        pieces.append((leaf(center.x + r * 0.3, center.y + r * 2.1, r * 2.4, deg: 50), .fill(p.leaf)))
        pieces.append((leaf(center.x - r * 0.3, center.y + r * 2.1, r * 2.1, deg: 125), .fill(p.leaf)))
        for (dx, dy) in [(-1.0, 1.0), (0.0, 1.25), (1.0, 1.0), (-1.2, 0.0), (0.0, 0.1), (1.2, 0.0), (-0.6, -1.0), (0.6, -1.0), (0.0, -1.9)] as [(CGFloat, CGFloat)] {
            pieces.append((circle(center.x + dx * r, center.y + dy * r, r * 0.78), .fill(p.soft)))
        }
        return pieces
    },
    Variant(name: "Herz-Punkt", note: "Der i-Punkt als pummeliges Herz – „mit Liebe gekocht“. Dezent und sympathisch.") { p in
        word(plain, p) + [(heart(dotCenter.x, dotCenter.y + 2, iDot.width * 0.62), .fill(p.accent))]
    },
    Variant(name: "Dampf", note: "Über dem o dampft es – frisch gekocht. Funktioniert auch als kleines Signet allein.") { p in
        var pieces = word(dotted, p)
        for (i, dx) in [-0.24, 0.0, 0.24].enumerated() {
            let x = oBox.midX + oBox.width * dx
            let y0 = oBox.maxY + 6, y1 = oBox.maxY + (i == 1 ? 34 : 28)
            let s = CGMutablePath(), mid = (y0 + y1) / 2
            s.move(to: CGPoint(x: x, y: y0))
            s.addCurve(to: CGPoint(x: x, y: mid), control1: CGPoint(x: x - 5, y: y0 + 3), control2: CGPoint(x: x + 5, y: mid - 3))
            s.addCurve(to: CGPoint(x: x, y: y1), control1: CGPoint(x: x - 5, y: mid + 3), control2: CGPoint(x: x + 5, y: y1 - 3))
            pieces.append((s, .stroke(p.accent, 4.5)))
        }
        return pieces
    },
    Variant(name: "Gesichts-o", note: "Das o lächelt – nomi als freundlicher Assistent, wie Chefi im Tab-Symbol.") { p in
        var pieces = word(dotted.enumerated().filter { $0.offset != 1 }.map(\.element), p)
        let r = oBox.width / 2
        let center = CGPoint(x: oBox.midX, y: oBox.midY)
        pieces.append((circle(center.x, center.y, r), .fill(p.text)))
        let feature = p.bg
        pieces.append((circle(center.x - r * 0.34, center.y + r * 0.16, r * 0.13), .fill(feature)))
        pieces.append((circle(center.x + r * 0.34, center.y + r * 0.16, r * 0.13), .fill(feature)))
        let smile = CGMutablePath()
        smile.addArc(center: CGPoint(x: center.x, y: center.y + r * 0.02), radius: r * 0.42, startAngle: -0.45, endAngle: -.pi + 0.45, clockwise: true)
        pieces.append((smile, .stroke(feature, r * 0.14)))
        pieces.append((CGPath(ellipseIn: CGRect(x: center.x - r * 0.78, y: center.y - r * 0.32, width: r * 0.32, height: r * 0.18), transform: nil), .fill(p.soft)))
        pieces.append((CGPath(ellipseIn: CGRect(x: center.x + r * 0.46, y: center.y - r * 0.32, width: r * 0.32, height: r * 0.18), transform: nil), .fill(p.soft)))
        return pieces
    },
    Variant(name: "Mützen-i", note: "Chefis Kochmütze sitzt auf dem i – Wortmarke und Maskottchen in einem.") { p in
        let w = iDot.width * 1.25
        let base = CGPoint(x: dotCenter.x, y: iDot.minY + 4)
        let puffs = [circle(base.x - w * 0.32, base.y + w * 0.62, w * 0.3), circle(base.x + w * 0.32, base.y + w * 0.62, w * 0.3), circle(base.x, base.y + w * 0.8, w * 0.36)]
            .reduce(CGPath(roundedRect: CGRect(x: base.x - w * 0.5, y: base.y + w * 0.3, width: w, height: w * 0.4), cornerWidth: 3, cornerHeight: 3, transform: nil)) { $0.union($1) }
        let band = CGPath(roundedRect: CGRect(x: base.x - w * 0.5, y: base.y, width: w, height: w * 0.32), cornerWidth: 4, cornerHeight: 4, transform: nil)
        return word(plain, p) + [(puffs, .fill(p.text)), (band, .fill(p.accent))]
    },
    Variant(name: "Hüpfen", note: "Die Buchstaben hüpfen leicht – wie Chefi im Splashscreen. Lebendig, ohne Zusatzform.") { p in
        let moves: [(dy: CGFloat, deg: CGFloat)] = [(0, -7), (11, 6), (-2, -4), (9, 8)]
        return dotted.enumerated().map { i, path in
            let b = path.boundingBox
            var t = CGAffineTransform(translationX: b.midX, y: b.midY + moves[i].dy)
                .rotated(by: moves[i].deg * .pi / 180)
                .translatedBy(x: -b.midX, y: -b.midY)
            return (path.copy(using: &t)!, .fill(p.text))
        }
    },
    Variant(name: "Biss + Herz", note: "Kombination: angebissenes o und Herz als i-Punkt. Am meisten Charakter.") { p in
        let bite = biteMark()
        var paths = plain
        paths[1] = paths[1].subtracting(bite)
        return word(paths, p) + [(heart(dotCenter.x, dotCenter.y + 2, iDot.width * 0.62), .fill(p.accent))]
    },
]

// MARK: - Bogen

var ctx: CGContext!

func draw(_ pieces: [Piece], in rect: CGRect, width: CGFloat) {
    let bounds = pieces.reduce(CGRect.null) { $0.union($1.path.boundingBox) }
    let scale = min(width / bounds.width, rect.height * 0.72 / bounds.height)
    ctx.saveGState()
    ctx.translateBy(x: rect.midX - bounds.midX * scale, y: rect.midY - bounds.midY * scale)
    ctx.scaleBy(x: scale, y: scale)
    for piece in pieces {
        ctx.addPath(piece.path)
        switch piece.paint {
        case .fill(let color):
            ctx.setFillColor(c(color)); ctx.fillPath()
        case .stroke(let color, let width):
            ctx.setStrokeColor(c(color)); ctx.setLineWidth(width); ctx.setLineCap(.round); ctx.strokePath()
        }
    }
    ctx.restoreGState()
}

func text(_ s: String, font: String, size: CGFloat, color: UInt32, at p: CGPoint, width: CGFloat? = nil) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let attr = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c(color)])
    if let width {
        let frame = CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attr), CFRange(), CGPath(rect: CGRect(x: p.x, y: p.y - 44, width: width, height: 48), transform: nil), nil)
        CTFrameDraw(frame, ctx)
    } else {
        ctx.textPosition = p; CTLineDraw(CTLineCreateWithAttributedString(attr), ctx)
    }
}

let cols = 3
let tileW: CGFloat = 480, tileH: CGFloat = 180, gap: CGFloat = 26
let blockH = 70 + tileH * 2 + gap + 74 + 60
let W = Int(CGFloat(cols) * (tileW + gap) + 60), H = Int(CGFloat((variants.count + cols - 1) / cols) * blockH + 130)
ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(c(canvas)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

text("Wortmarke DynaPuff: Details", font: "BricolageGrotesque96pt-ExtraBold", size: 44, color: ink, at: CGPoint(x: 30, y: CGFloat(H) - 76))
for (i, v) in variants.enumerated() {
    let x = 30 + CGFloat(i % cols) * (tileW + gap)
    let top = CGFloat(H) - 120 - CGFloat(i / cols) * blockH
    text("\(i + 1) · \(v.name)", font: "BricolageGrotesque96pt-ExtraBold", size: 24, color: ink, at: CGPoint(x: x, y: top - 26))
    text(v.note, font: "DMSans-Regular", size: 15, color: inkMuted, at: CGPoint(x: x, y: top - 38), width: tileW)
    for (j, palette) in [onBrand, onCream].enumerated() {
        let tile = CGRect(x: x, y: top - 92 - tileH - CGFloat(j) * (tileH + gap), width: tileW, height: tileH)
        ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 22, cornerHeight: 22, transform: nil))
        ctx.setFillColor(c(palette.bg)); ctx.fillPath()
        if palette.bg == canvas {
            ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 22, cornerHeight: 22, transform: nil))
            ctx.setStrokeColor(c(0xE6E1D8)); ctx.setLineWidth(1.5); ctx.strokePath()
        }
        draw(v.pieces(palette), in: tile, width: tileW * 0.6)
    }
    let bar = CGRect(x: x, y: top - 92 - tileH * 2 - gap - 74, width: tileW, height: 58)
    ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.setFillColor(c(brand)); ctx.fillPath()
    draw(v.pieces(onBrand), in: CGRect(x: bar.minX + 14, y: bar.minY + 6, width: 120, height: 46), width: 92)
    ctx.setFillColor(c(white)); ctx.setAlpha(0.18)
    ctx.fillEllipse(in: CGRect(x: bar.maxX - 54, y: bar.midY - 18, width: 36, height: 36))
    ctx.setAlpha(1)
    text("KOPFZEILE", font: "DMMono-Regular", size: 12, color: inkMuted, at: CGPoint(x: bar.minX, y: bar.minY - 18))
}

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))

// MARK: - Biss mit gelbem o (zweiter Bogen, wenn ein vierter Pfad übergeben wird)

if CommandLine.arguments.count > 4 {
    /// Wortmarke mit angebissenem o in eigener Farbe
    func bittenWord(text: UInt32, o: UInt32) -> [Piece] {
        var paths = plain
        paths[1] = paths[1].subtracting(biteMark())
        paths[3] = dotted[3]
        return paths.enumerated().map { ($0.element, .fill($0.offset == 1 ? o : text)) }
    }
    let yellows: [(name: String, onBrand: UInt32, onCream: UInt32)] = [
        ("Ocker", 0xF2B33D, 0xE8971C),
        ("Keksgold", 0xF5C26B, 0xD9962E),
        ("Buttergelb", 0xFFD54A, 0xF0B400),
    ]
    let colW: CGFloat = 470, tileH2: CGFloat = 190
    let W2 = Int(CGFloat(yellows.count) * (colW + 26) + 60), H2 = 1170
    ctx = CGContext(data: nil, width: W2, height: H2, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(c(canvas)); ctx.fill(CGRect(x: 0, y: 0, width: W2, height: H2))
    text("Biss mit gelbem o", font: "BricolageGrotesque96pt-ExtraBold", size: 44, color: ink, at: CGPoint(x: 30, y: CGFloat(H2) - 76))
    for (i, y) in yellows.enumerated() {
        let x = 30 + CGFloat(i) * (colW + 26)
        let top = CGFloat(H2) - 120
        text("\(i + 1) · \(y.name)", font: "BricolageGrotesque96pt-ExtraBold", size: 26, color: ink, at: CGPoint(x: x, y: top - 28))
        // Himbeere und Creme
        for (j, (bg, fg, o)) in [(brand, white, y.onBrand), (canvas, brand, y.onCream)].enumerated() {
            let tile = CGRect(x: x, y: top - 70 - tileH2 - CGFloat(j) * (tileH2 + 22), width: colW, height: tileH2)
            ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 22, cornerHeight: 22, transform: nil))
            ctx.setFillColor(c(bg)); ctx.fillPath()
            if bg == canvas {
                ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 22, cornerHeight: 22, transform: nil))
                ctx.setStrokeColor(c(0xE6E1D8)); ctx.setLineWidth(1.5); ctx.strokePath()
            }
            draw(bittenWord(text: fg, o: o), in: tile, width: colW * 0.6)
        }
        // Kopfzeile
        let bar = CGRect(x: x, y: top - 70 - tileH2 * 2 - 22 - 82, width: colW, height: 58)
        ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 14, cornerHeight: 14, transform: nil))
        ctx.setFillColor(c(brand)); ctx.fillPath()
        draw(bittenWord(text: white, o: y.onBrand), in: CGRect(x: bar.minX + 14, y: bar.minY + 6, width: 120, height: 46), width: 92)
        ctx.setFillColor(c(white)); ctx.setAlpha(0.18)
        ctx.fillEllipse(in: CGRect(x: bar.maxX - 54, y: bar.midY - 18, width: 36, height: 36))
        ctx.setAlpha(1)
        text("KOPFZEILE", font: "DMMono-Regular", size: 12, color: inkMuted, at: CGPoint(x: bar.minX, y: bar.minY - 18))
        // App-Icon und das o allein als Mini-Signet
        let icon = CGRect(x: x, y: 60, width: 200, height: 200)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: icon, cornerWidth: 45, cornerHeight: 45, transform: nil)); ctx.clip()
        ctx.setFillColor(c(brand)); ctx.fill(icon)
        draw(bittenWord(text: white, o: y.onBrand), in: icon.insetBy(dx: 18, dy: 40), width: 160)
        ctx.restoreGState()
        let signet = CGRect(x: x + 240, y: 60, width: 200, height: 200)
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: signet, cornerWidth: 45, cornerHeight: 45, transform: nil)); ctx.clip()
        ctx.setFillColor(c(brand)); ctx.fill(signet)
        var o = plain[1].subtracting(biteMark())
        let ob = o.boundingBox
        let s = 120 / max(ob.width, ob.height)
        var t = CGAffineTransform(translationX: signet.midX, y: signet.midY).scaledBy(x: s, y: s).translatedBy(x: -oBox.midX, y: -oBox.midY)
        o = o.copy(using: &t)!
        ctx.addPath(o); ctx.setFillColor(c(y.onBrand)); ctx.fillPath()
        ctx.restoreGState()
        text("APP-ICON", font: "DMMono-Regular", size: 12, color: inkMuted, at: CGPoint(x: icon.minX, y: 38))
        text("SIGNET", font: "DMMono-Regular", size: 12, color: inkMuted, at: CGPoint(x: signet.minX, y: 38))
    }
    try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
        .write(to: URL(fileURLWithPath: CommandLine.arguments[4]))
}
