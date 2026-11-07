// Rendert das Storyboard für den Abschluss im Kochmodus: Chefi freut sich, wenn ein Rezept fertig ist.
// A: Jubel-Sprung mit Konfetti, B: Glückstanz mit Herzen.
// Chefis Formen wie in design/mascot/render-mascots.swift, ergänzt um Lachaugen, Herzaugen, großes Lachen und Arme hoch.
// Aufruf: swift design/cooking/render-cooking-done.swift Nomi/Resources/Fonts design/cooking/rezept-fertig.png
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

func paw(_ pen: Pen, _ x: CGFloat, _ y: CGFloat) {
    pen.shape(ellipse(x, y, 22, 18), mint)
    pen.line(curve((x - 5, y + 3), (x, y - 1), (x + 5, y + 3)), width: 2.5)
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

enum Eyes { case open, happy, hearts }

/// Glückliches Gesicht: Lachaugen ^^ oder Herzaugen, großes offenes Lachen
func happyFace(_ pen: Pen, cx: CGFloat, eyeY: CGFloat, eyes: Eyes, laugh: Bool) {
    let spacing: CGFloat = 18
    for side in [-1.0, 1.0] as [CGFloat] {
        let x = cx + side * spacing
        switch eyes {
        case .open:
            pen.shape(circle(x, eyeY, 5.2), ink, stroke: false)
            pen.shape(circle(x + 1.6, eyeY + 1.9, 1.7), white, stroke: false)
        case .happy:
            pen.line(curve((x - 6, eyeY - 2), (x, eyeY + 7), (x + 6, eyeY - 2)), width: 3.8)
        case .hearts:
            pen.shape(heart(x, eyeY + 1, 6.5), brand, stroke: false)
        }
        pen.shape(heart(cx + side * spacing * 1.8, eyeY - 10, 6), blush, stroke: false)
    }
    let r: CGFloat = laugh ? 15 : 10
    let top = eyeY - 4
    let m = CGMutablePath()
    m.move(to: CGPoint(x: cx - r, y: top))
    m.addLine(to: CGPoint(x: cx + r, y: top))
    m.addArc(center: CGPoint(x: cx, y: top), radius: r, startAngle: 0, endAngle: .pi, clockwise: true)
    m.closeSubpath()
    pen.shape(m, mouth, stroke: false)
    pen.ctx.saveGState(); pen.ctx.addPath(m); pen.ctx.clip()
    pen.shape(ellipse(cx + 1, top - r * 0.95, r * 1.3, r * 0.9), tongue, stroke: false)
    pen.ctx.restoreGState()
    pen.shape(m, nil, width: 3.5)
}

struct HappyPose {
    var eyes: Eyes = .happy
    var laugh = true
    /// Beide Arme hoch statt Pfote am Bauch
    var armsUp = false
    /// Löffel in der Pfote (sonst fliegt er gerade)
    var holdsSpoon = true
    var spoonTilt: CGFloat = -0.32
    var hat: CGFloat = 0
}

func spoon(_ pen: Pen, at t: CGAffineTransform) {
    var hold = t
    let handle = CGMutablePath()
    handle.addRoundedRect(in: CGRect(x: -4.5, y: 0, width: 9, height: 78), cornerWidth: 4.5, cornerHeight: 4.5)
    pen.shape(handle.copy(using: &hold)!, wood)
    pen.shape(ellipse(0, 92, 26, 34).copy(using: &hold)!, wood)
    pen.line(curve((-6, 84), (0, 80), (6, 84)).copy(using: &hold)!, width: 3)
}

func happyChefi(_ pen: Pen, _ pose: HappyPose) {
    let cx: CGFloat = 100, b: CGFloat = 16, w: CGFloat = 130, h: CGFloat = 132
    for side in [-1.0, 1.0] as [CGFloat] { pen.shape(ellipse(cx + side * 30, b + 2, 34, 18), mint) }
    pen.shape(bean(cx, b, w, h), mint)
    pen.shape(ellipse(cx, b + h * 0.3, w * 0.62, h * 0.42), cream)
    if pose.armsUp {
        for side in [-1.0, 1.0] as [CGFloat] {
            for (dx, dy) in [(-12.0, 4.0), (-10.0, 14.0)] as [(CGFloat, CGFloat)] {
                pen.line(curve((cx + side * (66 - dx), b + 112 + dy), (cx + side * (72 - dx), b + 118 + dy), (cx + side * (70 - dx), b + 126 + dy)), width: 3)
            }
            paw(pen, cx + side * 60, b + 112)
        }
    } else {
        paw(pen, cx - 50, b + 50)
    }
    if pose.holdsSpoon && !pose.armsUp {
        let hold = CGAffineTransform(translationX: cx + 40, y: b + 20).rotated(by: pose.spoonTilt)
        spoon(pen, at: hold)
        let hand = CGPoint(x: 0, y: 34).applying(hold)
        paw(pen, hand.x, hand.y)
    }
    let top = b + h - 8 + pose.hat
    for (x, y, r) in [(cx - 24, top + 30, 20.0), (cx + 24, top + 30, 20.0), (cx, top + 42, 24.0)] as [(CGFloat, CGFloat, CGFloat)] {
        pen.shape(circle(x, y, r), white)
    }
    let band = CGMutablePath()
    band.addRoundedRect(in: CGRect(x: cx - 34, y: top, width: 68, height: 22), cornerWidth: 6, cornerHeight: 6)
    pen.shape(band, brand)
    happyFace(pen, cx: cx, eyeY: b + h * 0.62, eyes: pose.eyes, laugh: pose.laugh)
}

// MARK: - Bogen

let W = 1900, H = 1360
let ctx = CGContext(data: nil, width: W * 2, height: H * 2, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.scaleBy(x: 2, y: 2)
ctx.setFillColor(c(0xEFEBE3)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))
let pen = Pen(ctx: ctx)

func text(_ s: String, _ font: String, _ size: CGFloat, _ color: UInt32, _ x: CGFloat, _ y: CGFloat, centered: Bool = false) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c(color)]))
    var px = x
    if centered { px -= CTLineGetTypographicBounds(line, nil, nil, nil) / 2 }
    ctx.textPosition = CGPoint(x: px, y: y); CTLineDraw(line, ctx)
}

/// Chefi mit Squash & Stretch: Füße bleiben bei (cx, bottom)
func drawHappy(_ pose: HappyPose, cx: CGFloat, bottom: CGFloat, s: CGFloat, sx: CGFloat = 1, sy: CGFloat = 1, rotate: CGFloat = 0) {
    ctx.saveGState()
    ctx.translateBy(x: cx, y: bottom); ctx.rotate(by: rotate); ctx.scaleBy(x: s * sx, y: s * sy); ctx.translateBy(x: -100, y: 0)
    happyChefi(pen, pose)
    ctx.restoreGState()
}

func flyingSpoon(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ angle: CGFloat) {
    ctx.saveGState()
    ctx.translateBy(x: x, y: y); ctx.scaleBy(x: s, y: s)
    spoon(pen, at: CGAffineTransform(rotationAngle: angle).translatedBy(x: 0, y: -50))
    ctx.restoreGState()
    // Wirbel-Striche
    ctx.setStrokeColor(c(ink, 0.5)); ctx.setLineWidth(2.5); ctx.setLineCap(.round)
    ctx.addArc(center: CGPoint(x: x, y: y), radius: 52 * s, startAngle: 0.3, endAngle: 1.4, clockwise: false); ctx.strokePath()
    ctx.addArc(center: CGPoint(x: x, y: y), radius: 52 * s, startAngle: 3.4, endAngle: 4.5, clockwise: false); ctx.strokePath()
}

/// Konfetti in Markenfarben, deterministisch verteilt
func confetti(_ r: CGRect, count: Int, seed: Int, spread: CGFloat = 1) {
    var g = UInt64(seed)
    func rnd() -> CGFloat { g = g &* 6364136223846793005 &+ 1442695040888963407; return CGFloat((g >> 33) % 1000) / 1000 }
    let colors = [brand, ochre, mint, 0x9FD3E8, blush]
    for i in 0..<count {
        let x = r.minX + rnd() * r.width, y = r.minY + r.height * (1 - rnd() * spread)
        ctx.saveGState()
        ctx.translateBy(x: x, y: y); ctx.rotate(by: rnd() * 3)
        ctx.setFillColor(c(colors[i % colors.count]))
        if i % 3 == 0 { ctx.fillEllipse(in: CGRect(x: -4, y: -4, width: 8, height: 8)) } else { ctx.fill(CGRect(x: -6, y: -3, width: 12, height: 6)) }
        ctx.restoreGState()
    }
}

func sparkle(_ x: CGFloat, _ y: CGFloat, _ s: CGFloat, _ color: UInt32 = ochre) {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: x, y: y + s))
    p.addQuadCurve(to: CGPoint(x: x + s, y: y), control: CGPoint(x: x, y: y))
    p.addQuadCurve(to: CGPoint(x: x, y: y - s), control: CGPoint(x: x, y: y))
    p.addQuadCurve(to: CGPoint(x: x - s, y: y), control: CGPoint(x: x, y: y))
    p.addQuadCurve(to: CGPoint(x: x, y: y + s), control: CGPoint(x: x, y: y))
    ctx.addPath(p); ctx.setFillColor(c(color)); ctx.fillPath()
}

/// Fertig-Seite des Kochmodus als Hintergrund
func doneScreen(_ r: CGRect, showsText: Bool) {
    ctx.setFillColor(c(canvas)); ctx.fill(r)
    let head = CGRect(x: r.minX, y: r.maxY - 118, width: r.width, height: 118)
    ctx.addPath(CGPath(roundedRect: head.insetBy(dx: 0, dy: -30).offsetBy(dx: 0, dy: 30), cornerWidth: 26, cornerHeight: 26, transform: nil))
    ctx.setFillColor(c(brand)); ctx.fillPath()
    text("Pasta Aglio e Olio", "BricolageGrotesque24pt-Bold", 17, white, r.minX + 18, r.maxY - 78)
    ctx.setFillColor(c(white)); ctx.fill(CGRect(x: r.minX + 18, y: r.maxY - 100, width: r.width - 36, height: 4))
    text("FERTIG", "DMMono-Regular", 10, white, r.maxX - 62, r.maxY - 42)
    if showsText {
        text("Guten Appetit!", "BricolageGrotesque96pt-ExtraBold", 30, ink, r.midX, r.minY + 150, centered: true)
        text("Lasst es euch schmecken.", "DMSans-Regular", 14, inkMuted, r.midX, r.minY + 126, centered: true)
    }
    let button = CGRect(x: r.minX + 18, y: r.minY + 22, width: r.width - 36, height: 44)
    ctx.addPath(CGPath(roundedRect: button, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.setFillColor(c(ink)); ctx.fillPath()
    text("Fertig", "DMSans-SemiBold", 15, canvas, r.minX + 36, button.minY + 15)
}

func phone(_ i: Int, row: CGFloat, _ draw: (CGRect) -> Void) -> CGRect {
    let r = CGRect(x: 60 + CGFloat(i) * 320, y: row, width: 270, height: 500)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 36, cornerHeight: 36, transform: nil)); ctx.clip()
    draw(r)
    ctx.restoreGState()
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 36, cornerHeight: 36, transform: nil))
    ctx.setStrokeColor(c(ink, 0.85)); ctx.setLineWidth(5); ctx.strokePath()
    return r
}

func caption(_ r: CGRect, _ n: String, _ title: String, _ note: String) {
    text(n, "BricolageGrotesque96pt-ExtraBold", 20, brand, r.minX, r.minY - 34)
    text(title, "DMSans-SemiBold", 16, ink, r.minX + 30, r.minY - 32)
    text(note, "DMSans-Regular", 13, inkMuted, r.minX + 30, r.minY - 52)
}

func motion(_ x: CGFloat, _ y: CGFloat) {
    ctx.setStrokeColor(c(ink, 0.45)); ctx.setLineWidth(3); ctx.setLineCap(.round)
    for dx in [-26.0, 0.0, 26.0] { ctx.move(to: CGPoint(x: x + dx, y: y)); ctx.addLine(to: CGPoint(x: x + dx, y: y - 22)); ctx.strokePath() }
}

text("Rezept fertig: Chefi freut sich", "BricolageGrotesque96pt-ExtraBold", 40, ink, 60, CGFloat(H) - 70)
text("Auf der letzten Seite des Kochmodus statt der ruhigen Illustration. Etwa 2 s, danach hüpft Chefi leise weiter, bis „Fertig“ getippt wird.",
     "DMSans-Regular", 17, inkMuted, 60, CGFloat(H) - 104)

// A · Jubel-Sprung
let rowA: CGFloat = 720
text("A · JUBEL-SPRUNG MIT KONFETTI", "DMMono-Regular", 13, ink, 60, rowA + 518)
var r = phone(0, row: rowA) { r in
    doneScreen(r, showsText: false)
    drawHappy(HappyPose(eyes: .happy, laugh: false), cx: r.midX, bottom: r.minY + 140, s: 1.05, sx: 1.18, sy: 0.82)
}
caption(r, "1", "In die Knie", "Chefi duckt sich, Augen zu vor Vorfreude")

r = phone(1, row: rowA) { r in
    doneScreen(r, showsText: false)
    confetti(r.insetBy(dx: 10, dy: 60), count: 46, seed: 3)
    drawHappy(HappyPose(eyes: .happy, armsUp: true, holdsSpoon: false, hat: 14), cx: r.midX, bottom: r.minY + 210, s: 0.95, sx: 0.9, sy: 1.12)
    flyingSpoon(r.midX + 78, r.maxY - 150, 0.7, 0.8)
    motion(r.midX, r.minY + 196)
}
caption(r, "2", "Jubelsprung!", "Arme hoch, Konfetti, Löffel fliegt")

r = phone(2, row: rowA) { r in
    doneScreen(r, showsText: false)
    confetti(r.insetBy(dx: 10, dy: 40), count: 34, seed: 9, spread: 0.7)
    drawHappy(HappyPose(eyes: .hearts, armsUp: true, holdsSpoon: false), cx: r.midX, bottom: r.minY + 160, s: 1.0)
    flyingSpoon(r.midX - 70, r.maxY - 170, 0.7, -1.9)
    sparkle(r.minX + 40, r.maxY - 200, 12); sparkle(r.maxX - 44, r.maxY - 240, 9, brand)
}
caption(r, "3", "Herzaugen", "landet, Löffel wirbelt noch, Funkeln")

r = phone(3, row: rowA) { r in
    doneScreen(r, showsText: true)
    confetti(CGRect(x: r.minX + 10, y: r.minY + 80, width: r.width - 20, height: 40), count: 22, seed: 5)
    drawHappy(HappyPose(eyes: .happy, spoonTilt: -0.05), cx: r.midX, bottom: r.minY + 190, s: 0.95)
    sparkle(r.minX + 46, r.maxY - 180, 11); sparkle(r.maxX - 50, r.maxY - 210, 8, brand); sparkle(r.maxX - 70, r.minY + 300, 7)
}
caption(r, "4", "Guten Appetit!", "fängt den Löffel, Konfetti liegt am Boden, leises Hüpfen")

// B · Glückstanz
let rowB: CGFloat = 90
text("B · GLÜCKSTANZ MIT HERZEN", "DMMono-Regular", 13, ink, 60, rowB + 518)
r = phone(0, row: rowB) { r in
    doneScreen(r, showsText: true)
    drawHappy(HappyPose(eyes: .happy, laugh: true, spoonTilt: -0.6), cx: r.midX, bottom: r.minY + 190, s: 0.95, rotate: 0.12)
    for (dx, dy, s) in [(-80.0, 300.0, 8.0), (70.0, 330.0, 10.0)] as [(CGFloat, CGFloat, CGFloat)] { pen.shape(heart(r.midX + dx, r.minY + dy, s), brand, stroke: false) }
}
caption(r, "1", "Wippt nach links", "Löffel schwingt mit, erstes Herz steigt")

r = phone(1, row: rowB) { r in
    doneScreen(r, showsText: true)
    drawHappy(HappyPose(eyes: .happy, laugh: true, spoonTilt: 0.1), cx: r.midX, bottom: r.minY + 190, s: 0.95, rotate: -0.12)
    for (dx, dy, s) in [(-80.0, 340.0, 9.0), (70.0, 370.0, 11.0), (-30.0, 395.0, 7.0), (95.0, 290.0, 7.0)] as [(CGFloat, CGFloat, CGFloat)] { pen.shape(heart(r.midX + dx, r.minY + dy, s), brand, stroke: false) }
}
caption(r, "2", "Wippt nach rechts", "Herzen steigen auf und verblassen")

r = phone(2, row: rowB) { r in
    doneScreen(r, showsText: true)
    drawHappy(HappyPose(eyes: .hearts, laugh: true, spoonTilt: -0.3), cx: r.midX, bottom: r.minY + 190, s: 0.95)
    for (dx, dy, s) in [(-90.0, 330.0, 10.0), (80.0, 350.0, 12.0), (-10.0, 372.0, 8.0)] as [(CGFloat, CGFloat, CGFloat)] { pen.shape(heart(r.midX + dx, r.minY + dy, s), brand, stroke: false) }
}
caption(r, "3", "Herzaugen", "bleibt verliebt stehen")

// Empfehlung
let noteX: CGFloat = 1020
text("★", "DMSans-SemiBold", 22, ochre, noteX, rowB + 420)
let style = NSMutableParagraphStyle(); style.lineSpacing = 5
let rec = "Empfehlung: A. Fertig gekocht ist ein kleiner Erfolg – ein Sprung mit Konfetti und fliegendem Löffel fühlt sich nach Feiern an, und das Ende (Löffel gefangen, Konfetti am Boden) ist ein ruhiges Bild, das stehen bleiben kann. B ist niedlich, aber leiser."
let attr = NSAttributedString(string: rec, attributes: [.font: CTFontCreateWithName("DMSans-Medium" as CFString, 17, nil), .foregroundColor: c(ink), .paragraphStyle: style])
CTFrameDraw(CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attr), CFRange(), CGPath(rect: CGRect(x: noteX + 30, y: rowB + 250, width: 760, height: 190), transform: nil), nil), ctx)
let flow = "Dazu: Haptik beim Sprung (.success), mit „Bewegung reduzieren“ nur Bild 4. Neue Ausdrücke für ChefiView: Lachaugen ^^, Herzaugen, großes Lachen, beide Arme hoch."
let attr2 = NSAttributedString(string: flow, attributes: [.font: CTFontCreateWithName("DMSans-Regular" as CFString, 15, nil), .foregroundColor: c(inkMuted), .paragraphStyle: style])
CTFrameDraw(CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attr2), CFRange(), CGPath(rect: CGRect(x: noteX + 30, y: rowB + 130, width: 760, height: 110), transform: nil), nil), ctx)

let out = URL(fileURLWithPath: args[2])
try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: out)
print("geschrieben: \(args[2])")
