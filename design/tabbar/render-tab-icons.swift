// Rendert Vorschläge für die Tab-Leiste: vier Icon-Richtungen, jeweils als Leiste in Hell und Dunkel.
// Aufruf: swift design/tabbar/render-tab-icons.swift Nomi/Resources/Fonts design/tabbar/vorschlaege.png
import AppKit
import CoreText

let fontDir = URL(fileURLWithPath: CommandLine.arguments[1])
for f in try! FileManager.default.contentsOfDirectory(at: fontDir, includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}

func c(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}
let ink: UInt32 = 0x262B28, inkMuted: UInt32 = 0x6E726F, brand: UInt32 = 0xCC335E, brandDark: UInt32 = 0xE0587D
let canvas: UInt32 = 0xF7F4EE, canvasDark: UInt32 = 0x161816, inkDark: UInt32 = 0xF3EFE7

let tabs = ["nomi", "Heute", "Rezepte", "Einkauf", "Woche"]

// MARK: - Eigene Formen (Raster 24 × 24, Ursprung unten links)

func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r), transform: nil) }
func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}
func line(_ pts: (CGFloat, CGFloat)...) -> CGPath {
    let p = CGMutablePath(); p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
    for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
    return p
}
func squiggle(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> CGPath {
    let p = CGMutablePath(), mid = (y0 + y1) / 2
    p.move(to: CGPoint(x: x, y: y0))
    p.addCurve(to: CGPoint(x: x, y: mid), control1: CGPoint(x: x - 2, y: y0 + 1.2), control2: CGPoint(x: x + 2, y: mid - 1.2))
    p.addCurve(to: CGPoint(x: x, y: y1), control1: CGPoint(x: x - 2, y: mid + 1.2), control2: CGPoint(x: x + 2, y: y1 - 1.2))
    return p
}
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

/// Teile eines Icons: Umriss (`outline`), Details als Linie, Akzent-Flächen (nur aktiv in Himbeere)
struct Glyph {
    var outline: [CGPath]
    var details: [CGPath] = []
    var accent: [CGPath] = []
}

func glyph(_ tab: String) -> Glyph {
    switch tab {
    case "nomi":
        let puffs = [circle(7.4, 13.4, 3.6), circle(12, 15.7, 4.6), circle(16.6, 13.4, 3.6), rrect(6.4, 10.5, 11.2, 4, 1)]
        let hat = puffs.dropFirst().reduce(puffs[0]) { $0.union($1) }
        let band = rrect(6.4, 4.5, 11.2, 4.6, 1.4)
        return Glyph(outline: [hat, band], accent: [band])
    case "Heute":
        let bowl = CGMutablePath()
        bowl.move(to: CGPoint(x: 3.5, y: 11))
        bowl.addLine(to: CGPoint(x: 20.5, y: 11))
        bowl.addArc(center: CGPoint(x: 12, y: 11), radius: 8.5, startAngle: 0, endAngle: .pi, clockwise: true)
        bowl.closeSubpath()
        return Glyph(outline: [bowl], details: [squiggle(9, 13.8, 21.5), squiggle(15, 13.8, 21.5)], accent: [bowl])
    case "Rezepte":
        let card = rrect(5, 2.8, 14, 18.4, 3.2)
        return Glyph(outline: [card], details: [line((8.5, 10.5), (15.5, 10.5)), line((8.5, 7), (13.5, 7))], accent: [heart(12, 15.6, 2.6)])
    case "Einkauf":
        let body = CGMutablePath()
        body.move(to: CGPoint(x: 6.2, y: 14.5))
        body.addLine(to: CGPoint(x: 17.8, y: 14.5))
        body.addLine(to: CGPoint(x: 19, y: 4.5))
        body.addQuadCurve(to: CGPoint(x: 17.5, y: 3), control: CGPoint(x: 19.2, y: 3))
        body.addLine(to: CGPoint(x: 6.5, y: 3))
        body.addQuadCurve(to: CGPoint(x: 5, y: 4.5), control: CGPoint(x: 4.8, y: 3))
        body.closeSubpath()
        let handle = CGMutablePath()
        handle.addArc(center: CGPoint(x: 12, y: 14.5), radius: 3.6, startAngle: .pi, endAngle: 0, clockwise: true)
        return Glyph(outline: [body], details: [handle], accent: [leaf(17, 14.2, 6.5, deg: 72)])
    default: // Woche
        let cal = rrect(3.5, 3.5, 17, 15.5, 3.4)
        var dots: [CGPath] = []
        for (x, y) in [(8.3, 11), (12, 11), (15.7, 11), (8.3, 7.2), (12, 7.2)] as [(CGFloat, CGFloat)] { dots.append(circle(x, y, 1.15)) }
        return Glyph(outline: [cal], details: [line((3.5, 14.6), (20.5, 14.6)), line((8, 17), (8, 21)), line((16, 17), (16, 21))] , accent: [circle(15.7, 7.2, 2.1)] + dots)
    }
}

enum Style { case current, sfFresh, line, bold }

let sfNames: [Style: [String]] = [
    .current: ["", "fork.knife", "book.closed", "basket", "calendar"],
    .sfFresh: ["", "frying.pan", "book.pages", "bag", "calendar.badge.checkmark"],
]

/// Zeichnet ein Icon (Kantenlänge `size`) mit Mitte in `center`.
func drawIcon(_ ctx: CGContext, tab: String, index: Int, style: Style, selected: Bool, dark: Bool, center: CGPoint, size: CGFloat) {
    let color = selected ? (dark ? brandDark : brand) : (dark ? inkDark : ink)
    let rect = CGRect(x: center.x - size / 2, y: center.y - size / 2, width: size, height: size)

    // SF Symbols (Chefi-Mütze bleibt in jeder Richtung eigen)
    if let names = sfNames[style], index > 0 {
        let config = NSImage.SymbolConfiguration(pointSize: size * 0.78, weight: selected ? .semibold : .regular)
            .applying(.init(paletteColors: [NSColor(cgColor: c(color))!]))
        let name = selected ? names[index] + ".fill" : names[index]
        guard let image = (NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage(systemSymbolName: names[index], accessibilityDescription: nil))?
            .withSymbolConfiguration(config) else { print("fehlt:", name); return }
        let s = image.size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        image.draw(in: CGRect(x: center.x - s.width / 2, y: center.y - s.height / 2, width: s.width, height: s.height))
        NSGraphicsContext.restoreGraphicsState()
        return
    }

    let g = glyph(tab)
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.minY)
    ctx.scaleBy(x: size / 24, y: size / 24)
    ctx.setLineCap(.round); ctx.setLineJoin(.round)
    switch style {
    case .bold:
        // Gefüllte, runde Formen; Details ausgespart
        ctx.setFillColor(c(color))
        for p in g.outline { ctx.addPath(p); ctx.fillPath() }
        ctx.setBlendMode(.clear)
        ctx.setLineWidth(1.9)
        for p in g.details { ctx.addPath(p); ctx.strokePath() }
        if tab == "Rezepte" { ctx.addPath(heart(12, 15.6, 2.6)); ctx.fillPath() }
        if tab == "nomi" { ctx.fill(CGRect(x: 5, y: 9.1, width: 14, height: 1.4)) }
        if tab == "Woche" { for p in g.accent.dropFirst() { ctx.addPath(p); ctx.fillPath() } }
        ctx.setBlendMode(.normal)
        if tab == "Einkauf" { ctx.setStrokeColor(c(color)); ctx.setLineWidth(1.9); for p in g.details { ctx.addPath(p); ctx.strokePath() } }
    default:
        // Linie wie die Illustrationen; aktiv bekommen Akzente eine Himbeer-Füllung
        let width: CGFloat = 1.8
        if selected {
            ctx.setFillColor(c(dark ? brandDark : brand, tab == "Heute" || tab == "nomi" ? 0.28 : 1))
            let accents = tab == "Woche" ? [g.accent[0]] : g.accent
            for p in accents { ctx.addPath(p); ctx.fillPath() }
        }
        ctx.setStrokeColor(c(color)); ctx.setLineWidth(width)
        for p in g.outline + g.details { ctx.addPath(p); ctx.strokePath() }
        ctx.setFillColor(c(color))
        if tab == "Woche" { for p in g.accent.dropFirst() { ctx.addPath(p); ctx.fillPath() } }
        if !selected, tab == "Rezepte" { ctx.addPath(heart(12, 15.6, 2.6)); ctx.strokePath() }
        if tab == "Einkauf" { ctx.addPath(g.accent[0]); selected ? () : ctx.strokePath() }
    }
    ctx.restoreGState()
}

// MARK: - Bogen

let W = 1600, rowH: CGFloat = 330
let styles: [(Style, String, String)] = [
    (.current, "Aktuell", "SF Symbols wie jetzt, aktiv gefüllt. Funktioniert, wirkt aber generisch."),
    (.sfFresh, "A · SF Symbols, frischer", "Pfanne, Rezeptbuch mit Seiten, Tasche, Kalender mit Haken. Systemtreu, aktiv gefüllt."),
    (.line, "B · Eigene Linie", "Gezeichnet wie die Illustrationen: runde Linien, aktiv mit Himbeer-Akzent (Herz, Blatt, Punkt)."),
    (.bold, "C · Eigene, kräftig gefüllt", "Runde, gefüllte Formen mit ausgesparten Details. Verspielt, sehr präsent."),
]
let H = Int(130 + rowH * CGFloat(styles.count))
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(c(canvas)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

func text(_ s: String, font: String, size: CGFloat, color: UInt32, at p: CGPoint, center: Bool = false) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let l = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c(color)]))
    let w = center ? CTLineGetTypographicBounds(l, nil, nil, nil) : 0
    ctx.textPosition = CGPoint(x: p.x - w / 2, y: p.y); CTLineDraw(l, ctx)
}

func tabBar(style: Style, dark: Bool, origin: CGPoint, selected: Int) {
    let bar = CGRect(x: origin.x, y: origin.y, width: 620, height: 92)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -4), blur: 18, color: c(0x000000, dark ? 0.5 : 0.12))
    ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 46, cornerHeight: 46, transform: nil))
    ctx.setFillColor(c(dark ? 0x26292A : 0xFFFFFF, 0.97)); ctx.fillPath()
    ctx.restoreGState()
    let slot = bar.width / 5
    for (i, tab) in tabs.enumerated() {
        let cx = bar.minX + slot * (CGFloat(i) + 0.5)
        if i == selected {
            ctx.addPath(CGPath(roundedRect: CGRect(x: cx - slot / 2 + 6, y: bar.minY + 8, width: slot - 12, height: bar.height - 16), cornerWidth: 38, cornerHeight: 38, transform: nil))
            ctx.setFillColor(c(dark ? 0x3A3D3E : 0xEFEAE2)); ctx.fillPath()
        }
        drawIcon(ctx, tab: tab, index: i, style: style, selected: i == selected, dark: dark, center: CGPoint(x: cx, y: bar.minY + 58), size: 38)
        let labelColor = i == selected ? (dark ? brandDark : brand) : (dark ? inkDark : ink)
        text(tab, font: "DMSans-Medium", size: 15, color: labelColor, at: CGPoint(x: cx, y: bar.minY + 16), center: true)
    }
}

text("Tab-Leiste: Icon-Vorschläge", font: "BricolageGrotesque96pt-ExtraBold", size: 48, color: ink, at: CGPoint(x: 50, y: CGFloat(H) - 80))
for (row, (style, title, note)) in styles.enumerated() {
    let top = CGFloat(H) - 130 - rowH * CGFloat(row)
    text(title, font: "BricolageGrotesque96pt-ExtraBold", size: 30, color: ink, at: CGPoint(x: 50, y: top - 40))
    text(note, font: "DMSans-Regular", size: 19, color: inkMuted, at: CGPoint(x: 50, y: top - 72))
    // Hell
    tabBar(style: style, dark: false, origin: CGPoint(x: 50, y: top - 210), selected: 1)
    // Dunkel auf dunklem Grund
    let darkArea = CGRect(x: 700, y: top - 250, width: 720, height: 170)
    ctx.addPath(CGPath(roundedRect: darkArea, cornerWidth: 24, cornerHeight: 24, transform: nil))
    ctx.setFillColor(c(canvasDark)); ctx.fillPath()
    tabBar(style: style, dark: true, origin: CGPoint(x: 750, y: top - 210), selected: 0)
}

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
