// Rendert Stil-Vorschläge für nomnom-Illustrationen: sechs Motive in vier Stilen.
// Aufruf: swift design/illustrations/render-styles.swift NomNom/Resources/Fonts design/illustrations
import AppKit
import CoreText

let fontDir = URL(fileURLWithPath: CommandLine.arguments[1])
for f in try! FileManager.default.contentsOfDirectory(at: fontDir, includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}
let outDir = URL(fileURLWithPath: CommandLine.arguments[2])

func c(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}

// MARK: - Palette

let ink: UInt32 = 0x262B28, brand: UInt32 = 0xCC335E, canvas: UInt32 = 0xF7F4EE
let ochre: UInt32 = 0xF2B33D, tomato: UInt32 = 0xE8603C, sage: UInt32 = 0x7FA36B, leaf: UInt32 = 0x4F7D45
let cream: UInt32 = 0xFFF4E2, pinkCream: UInt32 = 0xF6C3D0, fishBlue: UInt32 = 0x86AFC9, white: UInt32 = 0xFFFFFF
let soup: UInt32 = 0xE0913C, choc: UInt32 = 0x7A4A3A, pumpkin: UInt32 = 0xEE8A2E, teal: UInt32 = 0x2C7C86

// MARK: - Motive (200×200, Ursprung unten links), von hinten nach vorne

enum Role { case fill, accent, line, dot }
struct Part { let path: CGPath; let role: Role; let color: UInt32 }
struct Motif { let name: String; let tint: UInt32; let parts: [Part] }

func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: x, y: y, width: w, height: h), transform: nil) }
func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath { ellipse(x - r, y - r, 2 * r, 2 * r) }
func poly(_ pts: [(CGFloat, CGFloat)]) -> CGPath {
    let p = CGMutablePath(); p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
    for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
    p.closeSubpath(); return p
}
func wave(from x0: CGFloat, to x1: CGFloat, y: CGFloat, amp: CGFloat, waves: Int) -> CGPath {
    let p = CGMutablePath(); p.move(to: CGPoint(x: x0, y: y))
    let step = (x1 - x0) / CGFloat(waves * 2)
    for i in 0..<(waves * 2) {
        let x = x0 + CGFloat(i) * step
        p.addQuadCurve(to: CGPoint(x: x + step, y: y), control: CGPoint(x: x + step / 2, y: y + (i % 2 == 0 ? amp : -amp)))
    }
    return p
}
func steam(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> CGPath {
    let p = CGMutablePath(); p.move(to: CGPoint(x: x, y: y0))
    let mid = (y0 + y1) / 2
    p.addCurve(to: CGPoint(x: x, y: mid), control1: CGPoint(x: x - 12, y: y0 + 8), control2: CGPoint(x: x + 12, y: mid - 8))
    p.addCurve(to: CGPoint(x: x, y: y1), control1: CGPoint(x: x - 12, y: mid + 8), control2: CGPoint(x: x + 12, y: y1 - 8))
    return p
}
func leafShape(_ x: CGFloat, _ y: CGFloat, _ len: CGFloat, angle: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: .zero)
    p.addQuadCurve(to: CGPoint(x: len, y: 0), control: CGPoint(x: len / 2, y: len * 0.45))
    p.addQuadCurve(to: .zero, control: CGPoint(x: len / 2, y: -len * 0.45))
    var t = CGAffineTransform(translationX: x, y: y).rotated(by: angle)
    return p.copy(using: &t)!
}
func line(_ a: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) -> CGPath {
    let p = CGMutablePath(); p.move(to: CGPoint(x: a.0, y: a.1)); p.addLine(to: CGPoint(x: b.0, y: b.1)); return p
}

let soupBowl: Motif = {
    let bowl = CGMutablePath()
    bowl.addArc(center: CGPoint(x: 100, y: 108), radius: 72, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
    bowl.closeSubpath()
    return Motif(name: "Suppe", tint: 0xF6DCC2, parts: [
        Part(path: steam(72, 132, 178), role: .line, color: ink),
        Part(path: steam(100, 138, 188), role: .line, color: ink),
        Part(path: steam(128, 132, 178), role: .line, color: ink),
        Part(path: poly([(76, 30), (124, 30), (118, 42), (82, 42)]), role: .fill, color: brand),
        Part(path: bowl, role: .fill, color: brand),
        Part(path: ellipse(30, 98, 140, 22), role: .accent, color: soup),
        Part(path: circle(78, 110, 5), role: .dot, color: sage),
        Part(path: circle(112, 106, 4), role: .dot, color: sage),
    ])
}()

let pasta: Motif = Motif(name: "Nudeln", tint: 0xF9E7B8, parts: [
    Part(path: ellipse(18, 36, 164, 64), role: .fill, color: white),
    Part(path: wave(from: 52, to: 148, y: 72, amp: 9, waves: 3), role: .line, color: ochre),
    Part(path: wave(from: 46, to: 154, y: 86, amp: 9, waves: 3), role: .line, color: ochre),
    Part(path: wave(from: 58, to: 142, y: 100, amp: 9, waves: 3), role: .line, color: ochre),
    Part(path: circle(82, 108, 13), role: .accent, color: tomato),
    Part(path: circle(118, 104, 11), role: .accent, color: tomato),
    Part(path: leafShape(96, 118, 34, angle: 0.5), role: .fill, color: leaf),
])

let fish: Motif = {
    let body = CGMutablePath()
    body.move(to: CGPoint(x: 34, y: 100))
    body.addCurve(to: CGPoint(x: 150, y: 100), control1: CGPoint(x: 72, y: 156), control2: CGPoint(x: 128, y: 150))
    body.addCurve(to: CGPoint(x: 34, y: 100), control1: CGPoint(x: 128, y: 52), control2: CGPoint(x: 72, y: 46))
    let gill = CGMutablePath(); gill.move(to: CGPoint(x: 78, y: 124)); gill.addQuadCurve(to: CGPoint(x: 78, y: 78), control: CGPoint(x: 92, y: 100))
    return Motif(name: "Fisch", tint: 0xDCE6EA, parts: [
        Part(path: poly([(146, 100), (184, 134), (176, 100), (184, 66)]), role: .accent, color: brand),
        Part(path: poly([(92, 136), (118, 158), (124, 134)]), role: .fill, color: fishBlue),
        Part(path: body, role: .fill, color: fishBlue),
        Part(path: gill, role: .line, color: ink),
        Part(path: circle(58, 108, 6), role: .dot, color: ink),
        Part(path: wave(from: 96, to: 136, y: 96, amp: 5, waves: 2), role: .line, color: white),
    ])
}()

let taco: Motif = {
    let shell = CGMutablePath()
    shell.addArc(center: CGPoint(x: 100, y: 52), radius: 80, startAngle: 0, endAngle: .pi, clockwise: false)
    shell.closeSubpath()
    var fillings: [Part] = []
    for (i, deg) in stride(from: 32.0, through: 148.0, by: 23.2).enumerated() {
        let a = deg * .pi / 180
        let color = [sage, tomato, sage, pinkCream, tomato, sage][i % 6]
        fillings.append(Part(path: circle(100 + 82 * cos(a), 52 + 82 * sin(a), 17), role: i % 2 == 0 ? .fill : .accent, color: color))
    }
    return Motif(name: "Taco", tint: 0xF9E7B8, parts: fillings + [
        Part(path: shell, role: .fill, color: ochre),
        Part(path: circle(70, 80, 3.5), role: .dot, color: choc),
        Part(path: circle(104, 98, 3.5), role: .dot, color: choc),
        Part(path: circle(134, 74, 3.5), role: .dot, color: choc),
    ])
}()

let cake: Motif = Motif(name: "Kuchen", tint: 0xF6D5DD, parts: [
    Part(path: line((150, 152), (162, 176)), role: .line, color: leaf),
    Part(path: poly([(28, 44), (172, 44), (172, 118), (28, 78)]), role: .fill, color: cream),
    Part(path: poly([(28, 78), (172, 118), (172, 134), (28, 92)]), role: .fill, color: pinkCream),
    Part(path: line((28, 62), (172, 84)), role: .line, color: brand),
    Part(path: circle(150, 142, 12), role: .accent, color: brand),
])

let pumpkinMotif: Motif = Motif(name: "Kürbis", tint: 0xF6DCC2, parts: [
    Part(path: leafShape(108, 140, 42, angle: 0.35), role: .fill, color: leaf),
    Part(path: ellipse(30, 38, 84, 96), role: .fill, color: pumpkin),
    Part(path: ellipse(86, 38, 84, 96), role: .fill, color: pumpkin),
    Part(path: ellipse(64, 34, 72, 104), role: .accent, color: pumpkin),
    Part(path: poly([(93, 132), (107, 132), (110, 158), (96, 158)]), role: .fill, color: choc),
])

let motifs = [soupBowl, pasta, fish, taco, cake, pumpkinMotif]

// MARK: - Stile

typealias Style = (name: String, subtitle: String, draw: (CGContext, Motif) -> Void)

func fill(_ ctx: CGContext, _ p: CGPath, _ color: CGColor) { ctx.addPath(p); ctx.setFillColor(color); ctx.fillPath() }
func stroke(_ ctx: CGContext, _ p: CGPath, _ color: CGColor, _ width: CGFloat) {
    ctx.addPath(p); ctx.setStrokeColor(color); ctx.setLineWidth(width); ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath()
}

let styles: [Style] = [
    ("1 · Linie", "Feine Tintenzeichnung, ein Akzent in Himbeere", { ctx, m in
        for part in m.parts {
            switch part.role {
            case .accent: fill(ctx, part.path, c(brand)); stroke(ctx, part.path, c(ink), 4.5)
            case .dot: fill(ctx, part.path, c(ink))
            case .fill: fill(ctx, part.path, c(m.tint)); stroke(ctx, part.path, c(ink), 4.5)
            case .line: stroke(ctx, part.path, c(ink), 4.5)
            }
        }
    }),
    ("2 · Flach & geometrisch", "Reduzierte Formen in warmer Palette, ohne Konturen", { ctx, m in
        for part in m.parts {
            switch part.role {
            case .fill, .accent, .dot: fill(ctx, part.path, c(part.color))
            case .line: stroke(ctx, part.path, c(part.color == ink ? 0x8C8F8B : part.color), 7)
            }
        }
    }),
    ("3 · Sticker", "Satte Farben, dunkle Kontur, weißer Rand, leicht schief", { ctx, m in
        ctx.saveGState()
        ctx.translateBy(x: 100, y: 100); ctx.rotate(by: -7 * .pi / 180); ctx.translateBy(x: -100, y: -100)
        // Weißer Sticker-Rand mit Schatten hinter allem
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -5), blur: 10, color: c(0x000000, 0.25))
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        for part in m.parts {
            if part.role == .line { stroke(ctx, part.path, c(white), 22) } else { stroke(ctx, part.path, c(white), 22); fill(ctx, part.path, c(white)) }
        }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
        for part in m.parts {
            switch part.role {
            case .fill, .accent: fill(ctx, part.path, c(part.color)); stroke(ctx, part.path, c(ink), 4)
            case .dot: fill(ctx, part.path, c(ink))
            case .line: stroke(ctx, part.path, c(part.color == white ? white : ink), 5)
            }
        }
        ctx.restoreGState()
    }),
    ("4 · Risograph", "Zwei Druckfarben versetzt übereinander, mit Körnung", { ctx, m in
        // Erste Farbe (Himbeere), leicht versetzt
        ctx.saveGState()
        ctx.translateBy(x: 6, y: -5)
        ctx.setBlendMode(.multiply)
        for part in m.parts where part.role != .line {
            fill(ctx, part.path, c(brand, part.role == .accent ? 0.85 : 0.38))
        }
        ctx.restoreGState()
        // Zweite Farbe (Petrol) für Form und Linien
        ctx.saveGState()
        ctx.setBlendMode(.multiply)
        for part in m.parts {
            switch part.role {
            case .fill: fill(ctx, part.path, c(teal, 0.32))
            case .accent: fill(ctx, part.path, c(teal, 0.12))
            case .dot: fill(ctx, part.path, c(teal, 0.95))
            case .line: stroke(ctx, part.path, c(teal, 0.9), 6)
            }
        }
        ctx.restoreGState()
        // Körnung
        var rng = SystemRandomNumberGenerator()
        for _ in 0..<1400 {
            let x = CGFloat.random(in: 0...200, using: &rng), y = CGFloat.random(in: 0...200, using: &rng)
            ctx.setFillColor(c(Bool.random(using: &rng) ? 0xFFFFFF : 0x000000, CGFloat.random(in: 0.04...0.14, using: &rng)))
            ctx.fill(CGRect(x: x, y: y, width: 1.4, height: 1.4))
        }
    }),
]

// MARK: - Blatt zusammensetzen

func text(_ ctx: CGContext, _ s: String, font: String, size: CGFloat, color: UInt32, x: CGFloat, y: CGFloat, kern: CGFloat = 0) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let l = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c(color), .kern: kern]))
    ctx.textPosition = CGPoint(x: x, y: y); CTLineDraw(l, ctx)
}

let tile: CGFloat = 230, gap: CGFloat = 22, rowHead: CGFloat = 78
let width = Int(CGFloat(motifs.count) * tile + CGFloat(motifs.count + 1) * gap)
let height = Int(CGFloat(styles.count) * (tile + rowHead + gap) + gap + 40)
let sheet = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
sheet.setFillColor(c(canvas)); sheet.fill(CGRect(x: 0, y: 0, width: width, height: height))

for (row, style) in styles.enumerated() {
    let top = CGFloat(height) - 30 - CGFloat(row) * (tile + rowHead + gap)
    text(sheet, style.name, font: "BricolageGrotesque96pt-ExtraBold", size: 34, color: ink, x: gap, y: top - 40, kern: -0.6)
    text(sheet, style.subtitle.uppercased(), font: "DMMono-Regular", size: 15, color: 0x6E726F, x: gap, y: top - 66, kern: 1.6)
    for (col, motif) in motifs.enumerated() {
        let origin = CGPoint(x: gap + CGFloat(col) * (tile + gap), y: top - rowHead - tile)
        sheet.saveGState()
        sheet.addPath(CGPath(roundedRect: CGRect(origin: origin, size: CGSize(width: tile, height: tile)), cornerWidth: 26, cornerHeight: 26, transform: nil))
        sheet.clip()
        // Hintergrund: Linie/Flach auf Pastell, Sticker kräftiger, Riso auf Papier
        let bg: UInt32 = row == 3 ? 0xF3EEE3 : (row == 2 ? 0xF2E2E7 : motif.tint)
        sheet.setFillColor(c(bg)); sheet.fill(CGRect(origin: origin, size: CGSize(width: tile, height: tile)))
        sheet.translateBy(x: origin.x + 15, y: origin.y + 15)
        sheet.scaleBy(x: (tile - 30) / 200, y: (tile - 30) / 200)
        style.draw(sheet, motif)
        sheet.restoreGState()
        if row == 0 {
            text(sheet, motif.name.uppercased(), font: "DMMono-Regular", size: 13, color: 0x6E726F, x: origin.x + 12, y: origin.y - 18, kern: 1.4)
        }
    }
}
let rep = NSBitmapImageRep(cgImage: sheet.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("styles.png"))
print("ok")
