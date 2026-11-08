// Rendert Vorschläge für die Sprachsteuerung im Kochmodus („Hey nomi, weiter“).
// A: Pille im Kopf, B: Chefi hört mit, C: Leuchtrand. Je drei Bilder: bereit, zuhören, erledigt.
// Chefis Formen wie in design/cooking/render-timer-alarm.swift.
// Aufruf: swift design/cooking/render-voice-control.swift Nomi/Resources/Fonts design/cooking/sprachsteuerung.png
import AppKit
import CoreText

let args = CommandLine.arguments
for f in try! FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: args[1]), includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}

func c(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}

let ink: UInt32 = 0x262B28, inkMuted: UInt32 = 0x6E726F, brand: UInt32 = 0xCC335E, canvas: UInt32 = 0xF7F4EE
let cream: UInt32 = 0xFFF6E8, mint: UInt32 = 0xD3E9C8, wood: UInt32 = 0xE2A65A, white: UInt32 = 0xFFFFFF
let mouth: UInt32 = 0x8E1F3E, tongue: UInt32 = 0xF28CA6, blush: UInt32 = 0xF4A0B5, hairline: UInt32 = 0xE6E1D8
let ochre: UInt32 = 0xF2B33D

// MARK: - Chefi (wie render-mascots.swift)

struct Pen {
    let ctx: CGContext
    func shape(_ path: CGPath, _ fill: UInt32?, stroke: Bool = true, width: CGFloat = 4.5) {
        if let fill { ctx.addPath(path); ctx.setFillColor(c(fill)); ctx.fillPath() }
        if stroke {
            ctx.addPath(path); ctx.setStrokeColor(c(ink)); ctx.setLineWidth(width)
            ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath()
        }
    }
    func line(_ path: CGPath, width: CGFloat = 4.5, color: UInt32 = ink) {
        ctx.addPath(path); ctx.setStrokeColor(c(color)); ctx.setLineWidth(width)
        ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath()
    }
}

func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h), transform: nil)
}
func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath { ellipse(cx, cy, 2 * r, 2 * r) }

func bean(_ cx: CGFloat, _ b: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: cx, y: b))
    p.addCurve(to: CGPoint(x: cx + w / 2, y: b + h * 0.38), control1: CGPoint(x: cx + w * 0.42, y: b), control2: CGPoint(x: cx + w / 2, y: b + h * 0.12))
    p.addCurve(to: CGPoint(x: cx, y: b + h), control1: CGPoint(x: cx + w / 2, y: b + h * 0.78), control2: CGPoint(x: cx + w * 0.34, y: b + h))
    p.addCurve(to: CGPoint(x: cx - w / 2, y: b + h * 0.38), control1: CGPoint(x: cx - w * 0.34, y: b + h), control2: CGPoint(x: cx - w / 2, y: b + h * 0.78))
    p.addCurve(to: CGPoint(x: cx, y: b), control1: CGPoint(x: cx - w / 2, y: b + h * 0.12), control2: CGPoint(x: cx - w * 0.42, y: b))
    p.closeSubpath()
    return p
}

func curve(_ a: (CGFloat, CGFloat), _ ctrl: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: a.0, y: a.1))
    p.addQuadCurve(to: CGPoint(x: b.0, y: b.1), control: CGPoint(x: ctrl.0, y: ctrl.1))
    return p
}

func face(_ pen: Pen, cx: CGFloat, eyeY: CGFloat, spacing: CGFloat, mouthR: CGFloat, wink: Bool = false, surprised: Bool = false) {
    for side in [-1.0, 1.0] as [CGFloat] {
        let x = cx + side * spacing
        if wink && side > 0 {
            pen.line(curve((x - 5.5, eyeY - 1.5), (x, eyeY + 5), (x + 5.5, eyeY - 1.5)), width: 3.5)
        } else {
            pen.shape(circle(x, eyeY, 5.2), ink, stroke: false)
            pen.shape(circle(x + 1.6, eyeY + 1.9, 1.7), white, stroke: false)
        }
        pen.shape(ellipse(cx + side * spacing * 1.75, eyeY - 9, 15, 9), blush, stroke: false)
    }
    let top = eyeY - 4
    if surprised {
        // Rundes „Oh!“ beim Klopfen
        pen.shape(ellipse(cx, top - 6, 11, 13), mouth)
        return
    }
    let m = CGMutablePath()
    m.move(to: CGPoint(x: cx - mouthR, y: top))
    m.addLine(to: CGPoint(x: cx + mouthR, y: top))
    m.addArc(center: CGPoint(x: cx, y: top), radius: mouthR, startAngle: 0, endAngle: .pi, clockwise: true)
    m.closeSubpath()
    pen.shape(m, mouth, stroke: false)
    pen.ctx.saveGState()
    pen.ctx.addPath(m); pen.ctx.clip()
    pen.shape(ellipse(cx + 1, top - mouthR * 0.95, mouthR * 1.3, mouthR * 0.9), tongue, stroke: false)
    pen.ctx.restoreGState()
    pen.shape(m, nil, width: 3.5)
}

struct ChefiPose {
    var spoonTilt: CGFloat = -0.32
    var wink = false
    var waves = false
    /// Linke Pfote fehlt, weil sie gerade an der Scheibe klebt (wird separat davor gezeichnet)
    var pawOnGlass = false
    var surprised = false
}

func paw(_ pen: Pen, _ x: CGFloat, _ y: CGFloat) {
    pen.shape(ellipse(x, y, 22, 18), mint)
    pen.line(curve((x - 5, y + 3), (x, y - 1), (x + 5, y + 3)), width: 2.5)
}

func chefi(_ pen: Pen, _ pose: ChefiPose) {
    let cx: CGFloat = 100, b: CGFloat = 16, w: CGFloat = 130, h: CGFloat = 132
    for side in [-1.0, 1.0] as [CGFloat] { pen.shape(ellipse(cx + side * 30, b + 2, 34, 18), mint) }
    pen.shape(bean(cx, b, w, h), mint)
    pen.shape(ellipse(cx, b + h * 0.3, w * 0.62, h * 0.42), cream)
    if pose.waves {
        for (dx, dy) in [(-12.0, 4.0), (-10.0, 14.0)] as [(CGFloat, CGFloat)] {
            pen.line(curve((cx - 66 + dx, b + 96 + dy), (cx - 72 + dx, b + 102 + dy), (cx - 70 + dx, b + 110 + dy)), width: 3)
        }
        paw(pen, cx - 56, b + 96)
    } else if !pose.pawOnGlass {
        paw(pen, cx - 50, b + 50)
    }
    var hold = CGAffineTransform(translationX: cx + 40, y: b + 20).rotated(by: pose.spoonTilt)
    let handle = CGMutablePath()
    handle.addRoundedRect(in: CGRect(x: -4.5, y: 0, width: 9, height: 78), cornerWidth: 4.5, cornerHeight: 4.5)
    pen.shape(handle.copy(using: &hold)!, wood)
    pen.shape(ellipse(0, 92, 26, 34).copy(using: &hold)!, wood)
    pen.line(curve((-6, 84), (0, 80), (6, 84)).copy(using: &hold)!, width: 3)
    let hand = CGPoint(x: 0, y: 34).applying(hold)
    paw(pen, hand.x, hand.y)
    let top = b + h - 8
    for (x, y, r) in [(cx - 24, top + 30, 20.0), (cx + 24, top + 30, 20.0), (cx, top + 42, 24.0)] as [(CGFloat, CGFloat, CGFloat)] {
        pen.shape(circle(x, y, r), white)
    }
    let band = CGMutablePath()
    band.addRoundedRect(in: CGRect(x: cx - 34, y: top, width: 68, height: 22), cornerWidth: 6, cornerHeight: 6)
    pen.shape(band, brand)
    face(pen, cx: cx, eyeY: b + h * 0.62, spacing: 18, mouthR: 10, wink: pose.wink, surprised: pose.surprised)
}

// MARK: - Bogen

let W = 1900, H = 2040
let ctx = CGContext(data: nil, width: W * 2, height: H * 2, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.scaleBy(x: 2, y: 2)
ctx.setFillColor(c(0xEFEBE3)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
let pen = Pen(ctx: ctx)
let mist: UInt32 = 0xE9EEE8, surface: UInt32 = 0xFCFAF6, sage: UInt32 = 0x7FA77A

func text(_ s: String, _ font: String, _ size: CGFloat, _ color: UInt32, _ x: CGFloat, _ y: CGFloat, alpha: CGFloat = 1, centered: Bool = false) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c(color, alpha)]))
    var px = x
    if centered { px -= CTLineGetTypographicBounds(line, nil, nil, nil) / 2 }
    ctx.textPosition = CGPoint(x: px, y: y); CTLineDraw(line, ctx)
}
func width(_ s: String, _ font: String, _ size: CGFloat) -> CGFloat {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: CTFontCreateWithName(font as CFString, size, nil)]))
    return CTLineGetTypographicBounds(line, nil, nil, nil)
}
func paragraph(_ s: String, _ font: String, _ size: CGFloat, _ color: UInt32, _ rect: CGRect, spacing: CGFloat = 5) {
    let style = NSMutableParagraphStyle(); style.lineSpacing = spacing
    let attr = NSAttributedString(string: s, attributes: [.font: CTFontCreateWithName(font as CFString, size, nil), .foregroundColor: c(color), .paragraphStyle: style])
    CTFrameDraw(CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attr), CFRange(), CGPath(rect: rect, transform: nil), nil), ctx)
}
func rounded(_ r: CGRect, _ radius: CGFloat, _ fill: UInt32, alpha: CGFloat = 1) {
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(c(fill, alpha)); ctx.fillPath()
}

func drawChefi(_ pose: ChefiPose, cx: CGFloat, bottom: CGFloat, s: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: cx - 100 * s, y: bottom); ctx.scaleBy(x: s, y: s)
    chefi(pen, pose)
    ctx.restoreGState()
}

/// Mikrofon-Symbol, Mitte (x, y), Höhe h
func mic(_ x: CGFloat, _ y: CGFloat, _ h: CGFloat, _ color: UInt32) {
    let w = h * 0.42
    rounded(CGRect(x: x - w / 2, y: y - h * 0.05, width: w, height: h * 0.55), w / 2, color)
    ctx.setStrokeColor(c(color)); ctx.setLineWidth(h * 0.1); ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: x, y: y + h * 0.15), radius: h * 0.34, startAngle: .pi * 1.05, endAngle: .pi * 1.95, clockwise: false)
    ctx.strokePath()
    ctx.move(to: CGPoint(x: x, y: y - h * 0.2)); ctx.addLine(to: CGPoint(x: x, y: y - h * 0.4)); ctx.strokePath()
}

/// Pegel: kleine Balken
func levels(_ x: CGFloat, _ y: CGFloat, _ heights: [CGFloat], _ color: UInt32) {
    for (i, h) in heights.enumerated() {
        rounded(CGRect(x: x + CGFloat(i) * 6, y: y - h / 2, width: 3.5, height: h), 1.75, color)
    }
}

/// Sprechblase mit Spitze nach unten links (tail = Punkt der Spitze)
func bubble(_ r: CGRect, tail: CGPoint, fill: UInt32 = white, lines: [(String, String, CGFloat, UInt32)]) {
    let p = CGMutablePath()
    p.addRoundedRect(in: r, cornerWidth: 18, cornerHeight: 18)
    let t = CGMutablePath()
    t.move(to: CGPoint(x: tail.x + 6, y: r.minY + 2)); t.addLine(to: tail); t.addLine(to: CGPoint(x: tail.x + 26, y: r.minY + 2)); t.closeSubpath()
    ctx.addPath(p); ctx.addPath(t); ctx.setFillColor(c(fill)); ctx.fillPath()
    var y = r.maxY - 26
    for (s, font, size, color) in lines {
        text(s, font, size, color, r.minX + 14, y)
        y -= size + 8
    }
}

/// Kochmodus-Schritt mit Kopf, Text und Leiste unten
func stepScreen(_ r: CGRect, step: Int = 2, title: [String] = ["Spaghetti in", "Salzwasser kochen."], stepLabelX: CGFloat = 108, headExtra: ((CGRect) -> Void)? = nil) {
    ctx.setFillColor(c(canvas)); ctx.fill(r)
    let head = CGRect(x: r.minX, y: r.maxY - 112, width: r.width, height: 112)
    ctx.addPath(CGPath(roundedRect: head.insetBy(dx: 0, dy: -30).offsetBy(dx: 0, dy: 30), cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.setFillColor(c(brand)); ctx.fillPath()
    // Leiste: Schließen links, Fortschritt rechts
    pen.shape(circle(r.minX + 30, r.maxY - 46, 13), nil, stroke: false)
    rounded(CGRect(x: r.minX + 17, y: r.maxY - 59, width: 26, height: 26), 13, white, alpha: 0.2)
    text("×", "DMSans-SemiBold", 17, white, r.minX + 30, r.maxY - 52, centered: true)
    text("SCHRITT \(step) VON 4", "DMMono-Regular", 9, white, r.maxX - stepLabelX, r.maxY - 50, alpha: 0.9)
    text("Pasta Aglio e Olio", "BricolageGrotesque24pt-Bold", 16, white, r.minX + 18, r.maxY - 84)
    ctx.setFillColor(c(white, 0.3)); ctx.fill(CGRect(x: r.minX + 18, y: r.maxY - 100, width: r.width - 36, height: 4))
    ctx.setFillColor(c(white)); ctx.fill(CGRect(x: r.minX + 18, y: r.maxY - 100, width: (r.width - 36) * CGFloat(step) / 5, height: 4))
    headExtra?(head)
    text("\(step)", "BricolageGrotesque96pt-ExtraBold", 52, brand, r.minX + 18, r.maxY - 180)
    var y = r.maxY - 214
    for line in title { text(line, "DMSans-Regular", 19, ink, r.minX + 18, y); y -= 26 }
    // Unten: Zurück / Weiter
    let back = CGRect(x: r.minX + 14, y: r.minY + 16, width: 82, height: 40)
    ctx.addPath(CGPath(roundedRect: back, cornerWidth: 20, cornerHeight: 20, transform: nil))
    ctx.setStrokeColor(c(ink)); ctx.setLineWidth(1.5); ctx.strokePath()
    text("Zurück", "DMSans-SemiBold", 13, ink, back.midX, back.minY + 14, centered: true)
    let next = CGRect(x: r.minX + 104, y: r.minY + 16, width: r.width - 118, height: 40)
    rounded(next, 20, ink)
    text("Weiter", "DMSans-SemiBold", 13, canvas, next.midX, next.minY + 14, centered: true)
}

let phoneW: CGFloat = 250, phoneH: CGFloat = 470
func phone(_ i: Int, row: CGFloat, _ draw: (CGRect) -> Void) -> CGRect {
    let r = CGRect(x: 60 + CGFloat(i) * 300, y: row, width: phoneW, height: phoneH)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 34, cornerHeight: 34, transform: nil)); ctx.clip()
    draw(r)
    ctx.restoreGState()
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 34, cornerHeight: 34, transform: nil))
    ctx.setStrokeColor(c(ink, 0.85)); ctx.setLineWidth(5); ctx.strokePath()
    return r
}

func caption(_ r: CGRect, _ n: String, _ title: String, _ note: String) {
    text(n, "BricolageGrotesque96pt-ExtraBold", 19, brand, r.minX, r.minY - 32)
    text(title, "DMSans-SemiBold", 15, ink, r.minX + 26, r.minY - 30)
    text(note, "DMSans-Regular", 12.5, inkMuted, r.minX + 26, r.minY - 49)
}

/// Gesagtes neben dem Telefon, als Zitat
func said(_ r: CGRect, _ s: String, y: CGFloat) {
    let w = width(s, "DMSans-Medium", 13) + 24
    let b = CGRect(x: r.maxX - w + 18, y: y, width: w, height: 28)
    rounded(b, 14, ochre)
    text(s, "DMSans-Medium", 13, ink, b.minX + 12, b.minY + 9)
}

/// Pille im Kopf: Mikro + „Hey nomi“
func headPill(_ head: CGRect, active: Bool) {
    let pill = CGRect(x: head.maxX - 104, y: head.maxY - 59, width: 90, height: 26)
    rounded(pill, 13, white, alpha: active ? 1 : 0.22)
    mic(pill.minX + 15, pill.midY, 13, active ? brand : white)
    if active {
        levels(pill.minX + 28, pill.midY, [6, 12, 16, 9, 13, 5], brand)
        text("hört", "DMMono-Medium", 9, brand, pill.minX + 66, pill.minY + 9)
    } else {
        text("Hey nomi", "DMMono-Regular", 9, white, pill.minX + 28, pill.minY + 9)
    }
}

/// Leuchtrand in Himbeere, innen am Display
func glow(_ r: CGRect, strength: CGFloat) {
    for i in 0..<14 {
        let inset = CGFloat(i) * 2.2
        ctx.addPath(CGPath(roundedRect: r.insetBy(dx: inset, dy: inset), cornerWidth: max(34 - inset, 4), cornerHeight: max(34 - inset, 4), transform: nil))
        ctx.setStrokeColor(c(i < 3 ? ochre : brand, strength * (1 - CGFloat(i) / 14) * 0.75)); ctx.setLineWidth(4.4); ctx.strokePath()
    }
}

text("Sprachsteuerung im Kochmodus", "BricolageGrotesque96pt-ExtraBold", 40, ink, 60, CGFloat(H) - 70)
text("Hände voller Teig? „Hey nomi, weiter“ blättert um. Läuft nur im Kochmodus und nur, wenn ihr das Mikro dort einschaltet – erkannt wird auf dem Gerät.",
     "DMSans-Regular", 17, inkMuted, 60, CGFloat(H) - 104)

// MARK: A · Pille im Kopf
let rowA: CGFloat = 1360
text("A · PILLE IM KOPF", "DMMono-Regular", 13, ink, 60, rowA + phoneH + 22)
var r = phone(0, row: rowA) { r in stepScreen(r, stepLabelX: 198) { headPill($0, active: false) } }
caption(r, "1", "Bereit", "Pille „Hey nomi“ oben rechts, Mikro an")
r = phone(1, row: rowA) { r in
    stepScreen(r, stepLabelX: 198) { headPill($0, active: true) }
    let bar = CGRect(x: r.minX + 12, y: r.minY + 66, width: r.width - 24, height: 58)
    rounded(bar, 18, ink)
    text("HÖRT ZU", "DMMono-Regular", 9, white, bar.minX + 14, bar.maxY - 20, alpha: 0.7)
    text("„Wie viel Salz …“", "DMSans-Medium", 15, white, bar.minX + 14, bar.minY + 12)
}
said(r, "Hey nomi, wie viel Salz?", y: r.maxY - 150)
caption(r, "2", "Zuhören", "Pille pulsiert, Text erscheint unten")
r = phone(2, row: rowA) { r in
    stepScreen(r, stepLabelX: 198) { headPill($0, active: false) }
    let bar = CGRect(x: r.minX + 12, y: r.minY + 66, width: r.width - 24, height: 58)
    rounded(bar, 18, sage)
    text("1 EL SALZ", "DMMono-Medium", 11, white, bar.minX + 14, bar.maxY - 22)
    text("auf 3 Liter Wasser", "DMSans-Medium", 14, white, bar.minX + 14, bar.minY + 12)
}
caption(r, "3", "Antwort", "steht kurz da, nomi liest vor")

// MARK: B · Chefi hört mit
let rowB: CGFloat = 740
text("B · CHEFI HÖRT MIT", "DMMono-Regular", 13, ink, 60, rowB + phoneH + 22)
r = phone(0, row: rowB) { r in
    stepScreen(r)
    // Chefi lugt unten links über die Leiste, kleiner Mikro-Punkt an der Mütze
    ctx.saveGState()
    ctx.clip(to: CGRect(x: r.minX, y: r.minY + 62, width: r.width, height: r.height))
    drawChefi(ChefiPose(spoonTilt: -0.2), cx: r.maxX - 44, bottom: r.minY + 30, s: 0.58)
    ctx.restoreGState()
    pen.shape(circle(r.maxX - 90, r.minY + 150, 11), brand, width: 2.5)
    mic(r.maxX - 90, r.minY + 150, 11, white)
}
caption(r, "1", "Bereit", "Chefi lugt in der Ecke, Mikro-Punkt")
r = phone(1, row: rowB) { r in
    stepScreen(r)
    ctx.setFillColor(c(canvas, 0.75)); ctx.fill(r)
    drawChefi(ChefiPose(spoonTilt: -0.5, surprised: true), cx: r.minX + 74, bottom: r.minY + 4, s: 0.95)
    bubble(CGRect(x: r.minX + 74, y: r.minY + 190, width: r.width - 88, height: 92), tail: CGPoint(x: r.minX + 96, y: r.minY + 168),
           lines: [("JA?", "DMMono-Medium", 10, brand), ("„Timer starten …“", "DMSans-Medium", 15, ink)])
    levels(r.minX + 160, r.minY + 214, [6, 12, 18, 10, 14, 6], brand)
    glow(r, strength: 1)
}
said(r, "Hey nomi, Timer starten", y: r.maxY - 150)
caption(r, "2", "Zuhören", "Chefi springt hoch, Rand leuchtet")
r = phone(2, row: rowB) { r in
    stepScreen(r, step: 2)
    // Timer-Karte läuft
    let card = CGRect(x: r.minX + 14, y: r.minY + 152, width: r.width - 28, height: 64)
    rounded(card, 18, surface)
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: 18, cornerHeight: 18, transform: nil)); ctx.setStrokeColor(c(brand)); ctx.setLineWidth(2); ctx.strokePath()
    text("LÄUFT", "DMMono-Regular", 9, inkMuted, card.minX + 14, card.maxY - 20)
    text("9:58", "DMMono-Medium", 26, ink, card.minX + 14, card.minY + 10)
    drawChefi(ChefiPose(spoonTilt: -0.08, wink: true), cx: r.maxX - 46, bottom: r.minY + 60, s: 0.38)
    bubble(CGRect(x: r.minX + 14, y: r.minY + 88, width: 146, height: 40), tail: CGPoint(x: r.minX + 150, y: r.minY + 78),
           lines: [("Läuft! 10 Minuten.", "DMSans-Medium", 13, ink)])
}
caption(r, "3", "Erledigt", "Chefi zwinkert, nomi sagt es kurz an")

// MARK: C · Leuchtrand
let rowC: CGFloat = 120
text("C · LEUCHTRAND WIE SIRI", "DMMono-Regular", 13, ink, 60, rowC + phoneH + 22)
r = phone(0, row: rowC) { r in
    stepScreen(r) { head in
        mic(head.maxX - 26, head.maxY - 76, 15, white)
    }
}
caption(r, "1", "Bereit", "nur ein Mikro-Symbol oben rechts")
r = phone(1, row: rowC) { r in
    stepScreen(r)
    glow(r, strength: 1)
    text("„Zurück …“", "BricolageGrotesque24pt-Bold", 24, brand, r.midX, r.minY + 86, centered: true)
}
said(r, "Hey nomi, zurück", y: r.maxY - 150)
caption(r, "2", "Zuhören", "ganzer Rand leuchtet, Text groß unten")
r = phone(2, row: rowC) { r in
    stepScreen(r, step: 1, title: ["Knoblauch in dünne", "Scheiben schneiden."])
    glow(r, strength: 0.35)
}
caption(r, "3", "Erledigt", "Rand verglimmt, Seite blättert")

// MARK: - Rechte Spalte: Befehle und Empfehlung
let colX: CGFloat = 1000
let card = CGRect(x: colX, y: 1040, width: 840, height: 800)
rounded(card, 28, white)
text("Was nomi im Kochmodus versteht", "BricolageGrotesque24pt-Bold", 24, ink, card.minX + 32, card.maxY - 54)
text("Erst „Hey nomi“, dann der Befehl – auch in einem Satz. Alles auf dem Gerät, ohne Kosten.", "DMSans-Regular", 14, inkMuted, card.minX + 32, card.maxY - 82)
let commands: [(String, String)] = [
    ("„Weiter“ · „Nächster Schritt“", "blättert um"),
    ("„Zurück“", "vorheriger Schritt"),
    ("„Nochmal“ · „Vorlesen“", "liest den Schritt vor"),
    ("„Was brauch ich?“", "liest die Zutaten des Schritts"),
    ("„Wie viel Salz?“", "Menge aus dem Rezept, passend zu den Portionen"),
    ("„Timer starten“ · „Timer stopp“", "Timer des Schritts"),
    ("„Wie lange noch?“", "Restzeit der laufenden Timer"),
    ("„Alles klar“ · „Stopp“", "beendet den Alarm"),
    ("„Fertig“", "zur letzten Seite – Chefi tanzt"),
]
var y = card.maxY - 132
for (cmd, what) in commands {
    text(cmd, "DMSans-SemiBold", 16, ink, card.minX + 32, y)
    text(what, "DMSans-Regular", 14, inkMuted, card.minX + 400, y + 1)
    ctx.setFillColor(c(hairline)); ctx.fill(CGRect(x: card.minX + 32, y: y - 16, width: card.width - 64, height: 1))
    y -= 50
}
text("Optional", "DMMono-Regular", 11, brand, card.minX + 32, y - 6)
paragraph("Andere Fragen („Kann ich Sahne durch Milch ersetzen?“) gehen an nomi in der Cloud – mit dem Rezept als Kontext, Antwort wird vorgelesen. Kostet wie eine Chat-Frage.",
          "DMSans-Regular", 14, inkMuted, CGRect(x: card.minX + 32, y: card.minY + 24, width: card.width - 64, height: y - card.minY - 34))

text("★", "DMSans-SemiBold", 22, ochre, colX, 960)
paragraph("Empfehlung: B, mit dem Leuchtrand aus C beim Zuhören. Chefi passt zu nomi und gibt eine klare Rückmeldung („Ja?“, Zwinkern), der Rand ist aus zwei Metern am Herd zu sehen. A ist sauber, aber zu klein für die Entfernung; C allein wirkt wie Siri und nicht wie nomi.",
          "DMSans-Medium", 17, ink, CGRect(x: colX + 30, y: 800, width: 810, height: 180))
paragraph("Technik: Spracherkennung von iOS 26 (SpeechAnalyzer) läuft durchgehend auf dem Gerät und hört nur auf „nomi“. Während nomi spricht oder ein Alarm klingelt, wird das Gehörte ignoriert, damit nomi sich nicht selbst antwortet. Das Mikro-Licht von iOS ist an, solange zugehört wird. Mit lauter Dunstabzugshaube wird es schwerer – dann hilft ein Tipp aufs Display wie bisher.",
          "DMSans-Regular", 15, inkMuted, CGRect(x: colX + 30, y: 590, width: 810, height: 200))

let out = URL(fileURLWithPath: args[2])
try! FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: out)
print("geschrieben: \(args[2])")
