// Rendert das Storyboard für den Timer-Alarm im Kochmodus: Chefi klopft von innen ans Display und winkt.
// A: Vollbild hinter der Scheibe, B: Fenster unten über dem Schritt.
// Chefis Formen sind aus design/mascot/render-mascots.swift übernommen (Raster 200 × 230, Ursprung unten links).
// Aufruf: swift design/cooking/render-timer-alarm.swift Nomi/Resources/Fonts design/cooking/timer-alarm.png
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

let W = 1900, H = 1360
let ctx = CGContext(data: nil, width: W * 2, height: H * 2, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.scaleBy(x: 2, y: 2)
ctx.setFillColor(c(0xEFEBE3)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
let pen = Pen(ctx: ctx)

func text(_ s: String, _ font: String, _ size: CGFloat, _ color: UInt32, _ x: CGFloat, _ y: CGFloat, alpha: CGFloat = 1, centered: Bool = false) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c(color, alpha)]))
    var px = x
    if centered { px -= CTLineGetTypographicBounds(line, nil, nil, nil) / 2 }
    ctx.textPosition = CGPoint(x: px, y: y); CTLineDraw(line, ctx)
}

/// Chefi in Größe `s`, Füße bei (cx, bottom)
func drawChefi(_ pose: ChefiPose, cx: CGFloat, bottom: CGFloat, s: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: cx - 100 * s, y: bottom); ctx.scaleBy(x: s, y: s)
    chefi(pen, pose)
    ctx.restoreGState()
}

/// Pfote platt an der Scheibe: helle Fläche mit rosa Ballen, wie eine Katzenpfote am Fenster
func glassPaw(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
    pen.shape(ellipse(x, y, r * 2.1, r * 1.8), 0xE6F3DF, width: 3.5)
    pen.shape(ellipse(x, y - r * 0.2, r * 0.95, r * 0.75), blush, stroke: false)
    for (dx, dy) in [(-0.62, 0.45), (-0.2, 0.68), (0.22, 0.68), (0.62, 0.45)] as [(CGFloat, CGFloat)] {
        pen.shape(ellipse(x + dx * r, y + dy * r, r * 0.38, r * 0.32), blush, stroke: false)
    }
}

/// Klopf-Ringe um die Pfote
func knockRings(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) {
    for (i, extra) in [16.0, 32.0, 48.0].enumerated() {
        ctx.setStrokeColor(c(white, 0.9 - CGFloat(i) * 0.25)); ctx.setLineWidth(3.5); ctx.setLineCap(.round)
        for start in [CGFloat.pi * 0.15, CGFloat.pi * 1.15] {
            ctx.addArc(center: CGPoint(x: x, y: y), radius: r + extra, startAngle: start, endAngle: start + .pi * 0.55, clockwise: false)
            ctx.strokePath()
        }
    }
}

/// Spiegelung auf dem Glas
func glassShine(_ rect: CGRect) {
    ctx.saveGState()
    ctx.setFillColor(c(white, 0.13))
    for (offset, width) in [(0.18, 34.0), (0.32, 12.0)] as [(CGFloat, CGFloat)] {
        let p = CGMutablePath()
        let x0 = rect.minX + rect.width * offset
        p.move(to: CGPoint(x: x0, y: rect.maxY))
        p.addLine(to: CGPoint(x: x0 + width, y: rect.maxY))
        p.addLine(to: CGPoint(x: x0 + width - rect.height * 0.5, y: rect.minY))
        p.addLine(to: CGPoint(x: x0 - rect.height * 0.5, y: rect.minY))
        p.closeSubpath()
        ctx.addPath(p); ctx.fillPath()
    }
    ctx.restoreGState()
}

/// Kochmodus-Schritt als Hintergrund
func stepScreen(_ r: CGRect) {
    ctx.setFillColor(c(canvas)); ctx.fill(r)
    let head = CGRect(x: r.minX, y: r.maxY - 118, width: r.width, height: 118)
    ctx.addPath(CGPath(roundedRect: head.insetBy(dx: 0, dy: -30).offsetBy(dx: 0, dy: 30), cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.setFillColor(c(brand)); ctx.fillPath()
    text("Pasta Aglio e Olio", "BricolageGrotesque24pt-Bold", 17, white, r.minX + 18, r.maxY - 78)
    ctx.setFillColor(c(white, 0.3)); ctx.fill(CGRect(x: r.minX + 18, y: r.maxY - 100, width: r.width - 36, height: 4))
    ctx.setFillColor(c(white)); ctx.fill(CGRect(x: r.minX + 18, y: r.maxY - 100, width: (r.width - 36) * 0.4, height: 4))
    text("SCHRITT 2 VON 4", "DMMono-Regular", 10, inkMuted, r.minX + 18, r.maxY - 150)
    text("Spaghetti in", "BricolageGrotesque96pt-ExtraBold", 26, ink, r.minX + 18, r.maxY - 182)
    text("Salzwasser kochen.", "BricolageGrotesque96pt-ExtraBold", 26, ink, r.minX + 18, r.maxY - 210)
    let card = CGRect(x: r.minX + 18, y: r.maxY - 330, width: r.width - 36, height: 90)
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: 18, cornerHeight: 18, transform: nil))
    ctx.setFillColor(c(0xFCFAF6)); ctx.fillPath()
    text("0:00", "BricolageGrotesque96pt-ExtraBold", 34, brand, card.minX + 18, card.minY + 30)
}

func phone(_ i: Int, row: CGFloat, shake: CGFloat = 0, _ draw: (CGRect) -> Void) -> CGRect {
    let r = CGRect(x: 60 + CGFloat(i) * 320, y: row, width: 270, height: 500)
    ctx.saveGState()
    ctx.translateBy(x: r.midX, y: r.midY); ctx.rotate(by: shake * .pi / 180); ctx.translateBy(x: -r.midX, y: -r.midY)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 36, cornerHeight: 36, transform: nil)); ctx.clip()
    draw(r)
    ctx.restoreGState()
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 36, cornerHeight: 36, transform: nil))
    ctx.setStrokeColor(c(ink, 0.85)); ctx.setLineWidth(5); ctx.strokePath()
    ctx.restoreGState()
    return r
}

func caption(_ r: CGRect, _ n: String, _ title: String, _ note: String) {
    text(n, "BricolageGrotesque96pt-ExtraBold", 20, brand, r.minX, r.minY - 34)
    text(title, "DMSans-SemiBold", 16, ink, r.minX + 30, r.minY - 32)
    text(note, "DMSans-Regular", 13, inkMuted, r.minX + 30, r.minY - 52)
}

/// Shake-Striche neben dem Telefon
func shakeMarks(_ r: CGRect) {
    ctx.setStrokeColor(c(ink, 0.5)); ctx.setLineWidth(3); ctx.setLineCap(.round)
    for (x, dir) in [(r.minX - 14, -1.0), (r.maxX + 14, 1.0)] as [(CGFloat, CGFloat)] {
        for dy in [-26.0, 0.0, 26.0] {
            ctx.move(to: CGPoint(x: x, y: r.midY + 120 + dy)); ctx.addLine(to: CGPoint(x: x + dir * 12, y: r.midY + 120 + dy)); ctx.strokePath()
        }
    }
}

func alarmCard(_ r: CGRect, compact: Bool = false) {
    let card = CGRect(x: r.minX + 14, y: r.minY + 16, width: r.width - 28, height: compact ? 104 : 120)
    ctx.addPath(CGPath(roundedRect: card, cornerWidth: 22, cornerHeight: 22, transform: nil))
    ctx.setFillColor(c(canvas)); ctx.fillPath()
    text("TIMER FERTIG", "DMMono-Regular", 10, inkMuted, card.minX + 16, card.maxY - 24)
    text("Spaghetti abgießen!", "BricolageGrotesque24pt-Bold", 18, ink, card.minX + 16, card.maxY - 48)
    let button = CGRect(x: card.minX + 12, y: card.minY + 12, width: card.width - 24, height: 40)
    ctx.addPath(CGPath(roundedRect: button, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.setFillColor(c(ink)); ctx.fillPath()
    text("Alles klar", "DMSans-SemiBold", 15, canvas, button.midX, button.minY + 14, centered: true)
}

text("Timer-Alarm mit Chefi", "BricolageGrotesque96pt-ExtraBold", 40, ink, 60, CGFloat(H) - 70)
text("Läuft ein Timer ab, klopft Chefi von innen ans Display und winkt. Tippen auf „Alles klar“ stoppt den Ton (auch den System-Timer).",
     "DMSans-Regular", 17, inkMuted, 60, CGFloat(H) - 104)

// A · Vollbild
let rowA: CGFloat = 720
text("A · VOLLBILD HINTER DER SCHEIBE", "DMMono-Regular", 13, ink, 60, rowA + 518)
var r = phone(0, row: rowA) { r in
    stepScreen(r)
    ctx.setFillColor(c(ink, 0.55)); ctx.fill(r)
    drawChefi(ChefiPose(spoonTilt: -0.5), cx: r.midX, bottom: r.minY - 150, s: 2.1)
    for x in [-100.0, 100.0] { pen.line(curve((r.midX + x, r.minY + 20), (r.midX + x + 4, r.minY + 45), (r.midX + x, r.minY + 70)), width: 3, color: white) }
}
caption(r, "1", "Chefi hüpft hoch", "Bild dimmt, Chefi riesig von unten")

r = phone(1, row: rowA, shake: -2.5) { r in
    stepScreen(r)
    ctx.setFillColor(c(ink, 0.55)); ctx.fill(r)
    drawChefi(ChefiPose(pawOnGlass: true, surprised: true), cx: r.midX + 10, bottom: r.minY - 60, s: 2.0)
    glassPaw(r.midX - 62, r.midY + 60, 34)
    knockRings(r.midX - 62, r.midY + 60, 34)
    glassShine(r)
    text("KLOPF", "DMMono-Medium", 20, white, r.midX + 30, r.maxY - 150)
    text("KLOPF", "DMMono-Medium", 20, white, r.midX + 52, r.maxY - 178)
}
shakeMarks(r)
caption(r, "2", "Klopf, klopf!", "Pfote an der Scheibe, Display wackelt, Haptik")

r = phone(2, row: rowA) { r in
    stepScreen(r)
    ctx.setFillColor(c(ink, 0.55)); ctx.fill(r)
    drawChefi(ChefiPose(pawOnGlass: true), cx: r.midX, bottom: r.minY - 210, s: 2.9)
    glassPaw(r.midX - 92, r.midY + 40, 38)
    glassPaw(r.midX + 92, r.midY + 60, 38)
    glassShine(r)
}
caption(r, "3", "Nase an der Scheibe", "beide Pfoten am Glas, ganz nah")

r = phone(3, row: rowA) { r in
    stepScreen(r)
    ctx.setFillColor(c(ink, 0.55)); ctx.fill(r)
    drawChefi(ChefiPose(spoonTilt: -0.08, wink: true, waves: true), cx: r.midX, bottom: r.minY + 150, s: 1.35)
    glassShine(r)
    alarmCard(r)
}
caption(r, "4", "Winkt und zwinkert", "Karte mit Schritt, „Alles klar“ stoppt")

// B · Fenster unten
let rowB: CGFloat = 90
text("B · FENSTER UNTEN, SCHRITT BLEIBT SICHTBAR", "DMMono-Regular", 13, ink, 60, rowB + 518)
r = phone(0, row: rowB) { r in
    stepScreen(r)
    let win = CGRect(x: r.minX + 12, y: r.minY + 12, width: r.width - 24, height: 210)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: win, cornerWidth: 26, cornerHeight: 26, transform: nil)); ctx.clip()
    ctx.setFillColor(c(brand)); ctx.fill(win)
    drawChefi(ChefiPose(), cx: win.midX, bottom: win.minY - 120, s: 1.3)
    ctx.restoreGState()
}
caption(r, "1", "Fenster fährt hoch", "Chefi guckt über die Kante")

r = phone(1, row: rowB, shake: -1.5) { r in
    stepScreen(r)
    let win = CGRect(x: r.minX + 12, y: r.minY + 12, width: r.width - 24, height: 210)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: win, cornerWidth: 26, cornerHeight: 26, transform: nil)); ctx.clip()
    ctx.setFillColor(c(brand)); ctx.fill(win)
    drawChefi(ChefiPose(pawOnGlass: true, surprised: true), cx: win.midX + 20, bottom: win.minY - 40, s: 1.3)
    glassPaw(win.midX - 50, win.midY + 30, 24)
    knockRings(win.midX - 50, win.midY + 30, 22)
    glassShine(win)
    ctx.restoreGState()
}
shakeMarks(r)
caption(r, "2", "Klopft ans Fenster", "kleiner, Schritt oben bleibt lesbar")

r = phone(2, row: rowB) { r in
    stepScreen(r)
    let win = CGRect(x: r.minX + 12, y: r.minY + 12, width: r.width - 24, height: 250)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: win, cornerWidth: 26, cornerHeight: 26, transform: nil)); ctx.clip()
    ctx.setFillColor(c(brand)); ctx.fill(win)
    drawChefi(ChefiPose(spoonTilt: -0.08, wink: true, waves: true), cx: win.maxX - 62, bottom: win.minY + 108, s: 0.62)
    text("TIMER FERTIG", "DMMono-Regular", 10, white, win.minX + 16, win.maxY - 30, alpha: 0.85)
    text("Spaghetti", "BricolageGrotesque24pt-Bold", 19, white, win.minX + 16, win.maxY - 56)
    text("abgießen!", "BricolageGrotesque24pt-Bold", 19, white, win.minX + 16, win.maxY - 78)
    let button = CGRect(x: win.minX + 12, y: win.minY + 12, width: win.width - 24, height: 40)
    ctx.addPath(CGPath(roundedRect: button, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.setFillColor(c(white)); ctx.fillPath()
    text("Alles klar", "DMSans-SemiBold", 15, ink, button.midX, button.minY + 14, centered: true)
    ctx.restoreGState()
}
caption(r, "3", "Winkt im Fenster", "„Alles klar“ stoppt, Fenster fährt runter")

// Empfehlung
let noteX: CGFloat = 1020
text("★", "DMSans-SemiBold", 22, ochre, noteX, rowB + 420)
let rec = "Empfehlung: A. Ein Alarm darf groß sein – man steht am Herd, das Handy liegt etwas weg. Chefi riesig hinter der Scheibe ist aus zwei Metern zu sehen und macht das Klopfen glaubwürdig. B ist dezenter, wirkt aber eher wie ein Hinweis als wie ein Alarm."
let style = NSMutableParagraphStyle(); style.lineSpacing = 5
let attr = NSAttributedString(string: rec, attributes: [.font: CTFontCreateWithName("DMSans-Medium" as CFString, 17, nil), .foregroundColor: c(ink), .paragraphStyle: style])
CTFrameDraw(CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attr), CFRange(), CGPath(rect: CGRect(x: noteX + 30, y: rowB + 250, width: 760, height: 190), transform: nil), nil), ctx)
let flow = "Ablauf: etwa 2,5 s, dann bleibt Bild 4 stehen, bis „Alles klar“ getippt wird. Klopfen mit Haptik im Takt, Ton von AlarmKit bzw. eigenem Ton. Weitere abgelaufene Timer klopfen erneut."
let attr2 = NSAttributedString(string: flow, attributes: [.font: CTFontCreateWithName("DMSans-Regular" as CFString, 15, nil), .foregroundColor: c(inkMuted), .paragraphStyle: style])
CTFrameDraw(CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attr2), CFRange(), CGPath(rect: CGRect(x: noteX + 30, y: rowB + 130, width: 760, height: 110), transform: nil), nil), ctx)

let out = URL(fileURLWithPath: args[2])
try! FileManager.default.createDirectory(at: out.deletingLastPathComponent(), withIntermediateDirectories: true)
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: out)
print("geschrieben: \(args[2])")
