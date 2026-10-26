// Rendert Maskottchen-Entwürfe für nomi:
// - vorschlaege.png: vier Figuren, jeweils groß, als App-Icon und als Splashscreen
// - chefi-varianten.png: Ausarbeitung von Chefi (Farben, Icon-Ausschnitte, Ablauf des Splashscreens)
// Aufruf: swift design/mascot/render-mascots.swift Nomi/Resources/Fonts design/mascot
import AppKit
import CoreText

let fontDir = URL(fileURLWithPath: CommandLine.arguments[1])
for f in try! FileManager.default.contentsOfDirectory(at: fontDir, includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}

func c(_ h: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1)
}

// Palette aus Theme.swift plus Körpertöne
let ink: UInt32 = 0x262B28, inkMuted: UInt32 = 0x6E726F, brand: UInt32 = 0xCC335E, canvas: UInt32 = 0xF7F4EE
let cream: UInt32 = 0xFFF6E8, ochre: UInt32 = 0xF2B33D, sage: UInt32 = 0x8FB089, mouth: UInt32 = 0x8E1F3E
let tongue: UInt32 = 0xF28CA6, blush: UInt32 = 0xF4A0B5, white: UInt32 = 0xFFFFFF

// MARK: - Zeichenhilfen (Raster 200 × 230, Ursprung unten links)

struct Pen {
    let ctx: CGContext

    func shape(_ path: CGPath, _ fill: UInt32?, stroke: Bool = true, width: CGFloat = 4.5) {
        if let fill {
            ctx.addPath(path); ctx.setFillColor(c(fill)); ctx.fillPath()
        }
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

/// Plüsch-Bohne: unten breit und leicht abgeflacht, oben rund
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
    p.addQuadCurve(to: CGPoint(x: len, y: 0), control: CGPoint(x: len / 2, y: len * 0.42))
    p.addQuadCurve(to: .zero, control: CGPoint(x: len / 2, y: -len * 0.42))
    var t = CGAffineTransform(translationX: x, y: y).rotated(by: deg * .pi / 180)
    return p.copy(using: &t)!
}

func curve(_ a: (CGFloat, CGFloat), _ ctrl: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: a.0, y: a.1))
    p.addQuadCurve(to: CGPoint(x: b.0, y: b.1), control: CGPoint(x: ctrl.0, y: ctrl.1))
    return p
}

func steam(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let mid = (y0 + y1) / 2
    p.move(to: CGPoint(x: x, y: y0))
    p.addCurve(to: CGPoint(x: x, y: mid), control1: CGPoint(x: x - 9, y: y0 + 6), control2: CGPoint(x: x + 9, y: mid - 6))
    p.addCurve(to: CGPoint(x: x, y: y1), control1: CGPoint(x: x - 9, y: mid + 6), control2: CGPoint(x: x + 9, y: y1 - 6))
    return p
}

enum Cheeks { case oval(UInt32), heart(UInt32) }

/// Gesicht: Knopfaugen mit Glanzpunkt, offenes D-Lächeln mit Zunge, Bäckchen
func face(_ pen: Pen, cx: CGFloat, eyeY: CGFloat, spacing: CGFloat, mouthR: CGFloat, cheeks: Cheeks, wink: Bool = false) {
    for side in [-1.0, 1.0] as [CGFloat] {
        let x = cx + side * spacing
        if wink && side > 0 {
            pen.line(curve((x - 5.5, eyeY - 1.5), (x, eyeY + 5), (x + 5.5, eyeY - 1.5)), width: 3.5)
        } else {
            pen.shape(circle(x, eyeY, 5.2), ink, stroke: false)
            pen.shape(circle(x + 1.6, eyeY + 1.9, 1.7), white, stroke: false)
        }
        let cheekX = cx + side * spacing * 1.75, cheekY = eyeY - 9
        switch cheeks {
        case .oval(let color): pen.shape(ellipse(cheekX, cheekY, 15, 9), color, stroke: false)
        case .heart(let color): pen.shape(heart(cheekX, cheekY, 6.5), color, stroke: false)
        }
    }
    let top = eyeY - 4
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

// MARK: - Figuren

struct Mascot {
    let name: String
    let pitch: String
    let draw: (Pen) -> Void
}

let raspberryBody: UInt32 = 0xE0587D
let plushPink: UInt32 = 0xF7C8D3
let mint: UInt32 = 0xD3E9C8
let wood: UInt32 = 0xE2A65A

let mascots: [Mascot] = [
    Mascot(name: "Himbi", pitch: "Eine kleine Himbeere – die Markenfarbe als Figur. Noppen auf dem Kopf, Blätterkrone, cremiger Bauch.") { pen in
        let cx: CGFloat = 100, b: CGFloat = 18, w: CGFloat = 132, h: CGFloat = 150
        for side in [-1.0, 1.0] as [CGFloat] { pen.shape(ellipse(cx + side * 30, b + 2, 34, 18), raspberryBody) }
        // Noppen: Kreise auf der oberen Kante, der Körper deckt ihre untere Hälfte
        for deg in stride(from: 22.0, through: 158.0, by: 17.0) {
            let a = deg * .pi / 180
            pen.shape(circle(cx + w * 0.47 * cos(a), b + h * 0.6 + h * 0.4 * sin(a), 9), raspberryBody)
        }
        pen.shape(bean(cx, b, w, h), raspberryBody)
        pen.shape(ellipse(cx, b + h * 0.3, w * 0.62, h * 0.42), cream)
        pen.line(curve((cx - 46, b + 66), (cx - 44, b + 52), (cx - 32, b + 52)), width: 4)
        pen.line(curve((cx + 46, b + 66), (cx + 44, b + 52), (cx + 32, b + 52)), width: 4)
        for deg in [20.0, 58.0, 122.0, 160.0] as [CGFloat] { pen.shape(leaf(cx, b + h - 2, 30, deg: deg), sage) }
        pen.shape(leaf(cx, b + h - 2, 24, deg: 90), sage)
        face(pen, cx: cx, eyeY: b + h * 0.66, spacing: 18, mouthR: 10, cheeks: .heart(blush))
    },
    Mascot(name: "Knödel", pitch: "Ein dampfender Teigknödel. Hell und rund – auf Himbeere besonders kräftig, mit Falten statt Haaren.") { pen in
        let cx: CGFloat = 100, b: CGFloat = 22
        for x in [cx - 26, cx, cx + 26] { pen.line(steam(x, b + 140, b + 182), width: 4) }
        let bun = CGMutablePath()
        bun.move(to: CGPoint(x: cx - 76, y: b + 26))
        bun.addCurve(to: CGPoint(x: cx, y: b + 128), control1: CGPoint(x: cx - 80, y: b + 92), control2: CGPoint(x: cx - 42, y: b + 126))
        bun.addCurve(to: CGPoint(x: cx + 76, y: b + 26), control1: CGPoint(x: cx + 42, y: b + 126), control2: CGPoint(x: cx + 80, y: b + 92))
        bun.addCurve(to: CGPoint(x: cx - 76, y: b + 26), control1: CGPoint(x: cx + 70, y: b - 6), control2: CGPoint(x: cx - 70, y: b - 6))
        bun.closeSubpath()
        pen.shape(bun, cream)
        for dx in [-34.0, -16.0, 16.0, 34.0] as [CGFloat] {
            pen.line(curve((cx + dx * 0.22, b + 124), (cx + dx * 0.95, b + 118), (cx + dx * 1.35, b + 96)), width: 3.5)
        }
        pen.shape(ellipse(cx, b + 128, 24, 15), cream)
        pen.line(curve((cx - 62, b + 30), (cx - 56, b + 18), (cx - 44, b + 22)), width: 4)
        pen.line(curve((cx + 62, b + 30), (cx + 56, b + 18), (cx + 44, b + 22)), width: 4)
        face(pen, cx: cx, eyeY: b + 66, spacing: 20, mouthR: 10, cheeks: .oval(brand))
    },
    Mascot(name: "Löffi", pitch: "Am nächsten an deinem Plüsch-Vorbild: rosa Bohne mit Öhrchen – das Einhorn-Horn ist ein Kochlöffel.") { pen in
        let cx: CGFloat = 100, b: CGFloat = 18, w: CGFloat = 130, h: CGFloat = 150
        for side in [-1.0, 1.0] as [CGFloat] { pen.shape(ellipse(cx + side * 30, b + 2, 34, 18), plushPink) }
        // Löffel-Horn
        let handle = CGMutablePath()
        handle.addRoundedRect(in: CGRect(x: -4.5, y: 0, width: 9, height: 40), cornerWidth: 4.5, cornerHeight: 4.5)
        var t = CGAffineTransform(translationX: cx + 2, y: b + h - 12).rotated(by: -0.18)
        pen.shape(handle.copy(using: &t)!, ochre)
        pen.shape(ellipse(cx + 10, b + h + 34, 22, 28), ochre)
        // Mähne in Puffs, Öhrchen
        for (x, y, color) in [(cx + 50, b + 132, ochre), (cx + 60, b + 112, 0xBFE0D2 as UInt32), (cx + 62, b + 90, blush)] as [(CGFloat, CGFloat, UInt32)] {
            pen.shape(circle(x, y, 12), color)
        }
        for side in [-1.0, 1.0] as [CGFloat] {
            pen.shape(ellipse(cx + side * 40, b + h - 6, 26, 34), plushPink)
            pen.shape(ellipse(cx + side * 40, b + h - 4, 12, 20), blush, stroke: false)
        }
        pen.shape(bean(cx, b, w, h), plushPink)
        pen.shape(ellipse(cx, b + h * 0.3, w * 0.62, h * 0.42), cream)
        for (x, y) in [(cx - 18, b + 56), (cx, b + 58), (cx + 18, b + 56), (cx - 9, b + 42), (cx + 9, b + 42)] as [(CGFloat, CGFloat)] {
            pen.line(curve((x - 5, y + 2), (x, y - 3), (x + 5, y + 2)), width: 2.5, color: 0xD9A441)
        }
        pen.line(curve((cx - 46, b + 66), (cx - 44, b + 52), (cx - 32, b + 52)), width: 4)
        pen.line(curve((cx + 46, b + 66), (cx + 44, b + 52), (cx + 32, b + 52)), width: 4)
        face(pen, cx: cx, eyeY: b + h * 0.66, spacing: 18, mouthR: 10, cheeks: .heart(brand))
    },
    Mascot(name: "Chefi", pitch: "Kleiner Koch mit Mütze im Himbeer-Band und Kochlöffel in der Pfote. Mintgrün wie die Gemüse-Illustrationen.") { pen in
        chefi(pen, ChefiPose())
    },
]

// MARK: - Chefi

struct ChefiPose {
    var body: UInt32 = mint
    /// Neigung des Löffels (Bogenmaß, negativ = nach außen)
    var spoonTilt: CGFloat = -0.32
    /// Löffel samt Pfote anheben
    var spoonLift: CGFloat = 0
    var wink = false
    /// Linke Pfote winkt neben dem Kopf statt am Bauch zu liegen
    var waves = false
}

func paw(_ pen: Pen, _ x: CGFloat, _ y: CGFloat, _ color: UInt32) {
    pen.shape(ellipse(x, y, 22, 18), color)
    pen.line(curve((x - 5, y + 3), (x, y - 1), (x + 5, y + 3)), width: 2.5)
}

func chefi(_ pen: Pen, _ pose: ChefiPose) {
    let cx: CGFloat = 100, b: CGFloat = 16, w: CGFloat = 130, h: CGFloat = 132
    for side in [-1.0, 1.0] as [CGFloat] { pen.shape(ellipse(cx + side * 30, b + 2, 34, 18), pose.body) }
    pen.shape(bean(cx, b, w, h), pose.body)
    pen.shape(ellipse(cx, b + h * 0.3, w * 0.62, h * 0.42), cream)
    // Linke Pfote: am Bauch oder winkend neben dem Kopf
    if pose.waves {
        for (dx, dy) in [(-12.0, 4.0), (-10.0, 14.0)] as [(CGFloat, CGFloat)] {
            pen.line(curve((cx - 66 + dx, b + 96 + dy), (cx - 72 + dx, b + 102 + dy), (cx - 70 + dx, b + 110 + dy)), width: 3)
        }
        paw(pen, cx - 56, b + 96, pose.body)
    } else {
        paw(pen, cx - 50, b + 50, pose.body)
    }
    // Kochlöffel in der rechten Pfote
    var hold = CGAffineTransform(translationX: cx + 40, y: b + 20 + pose.spoonLift).rotated(by: pose.spoonTilt)
    let handle = CGMutablePath()
    handle.addRoundedRect(in: CGRect(x: -4.5, y: 0, width: 9, height: 78), cornerWidth: 4.5, cornerHeight: 4.5)
    pen.shape(handle.copy(using: &hold)!, wood)
    pen.shape(ellipse(0, 92, 26, 34).copy(using: &hold)!, wood)
    pen.line(curve((-6, 84), (0, 80), (6, 84)).copy(using: &hold)!, width: 3)
    let hand = CGPoint(x: 0, y: 34).applying(hold)
    paw(pen, hand.x, hand.y, pose.body)
    // Kochmütze
    let top = b + h - 8
    for (x, y, r) in [(cx - 24, top + 30, 20.0), (cx + 24, top + 30, 20.0), (cx, top + 42, 24.0)] as [(CGFloat, CGFloat, CGFloat)] {
        pen.shape(circle(x, y, r), white)
    }
    let band = CGMutablePath()
    band.addRoundedRect(in: CGRect(x: cx - 34, y: top, width: 68, height: 22), cornerWidth: 6, cornerHeight: 6)
    pen.shape(band, brand)
    face(pen, cx: cx, eyeY: b + h * 0.62, spacing: 18, mouthR: 10, cheeks: .oval(blush), wink: pose.wink)
}

// MARK: - Bogen 1: Vorschläge

let outDir = URL(fileURLWithPath: CommandLine.arguments[2])

func sheet(width: Int, height: Int) -> CGContext {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.setFillColor(c(canvas)); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return ctx
}

func save(_ ctx: CGContext, _ name: String) {
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
}

var ctx = sheet(width: 1800, height: 1000)
var pen = Pen(ctx: ctx)

func text(_ s: String, font: String, size: CGFloat, color: UInt32, at p: CGPoint) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c(color)]))
    ctx.textPosition = p; CTLineDraw(line, ctx)
}

func paragraph(_ s: String, font: String, size: CGFloat, color: UInt32, in rect: CGRect) {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    let style = NSMutableParagraphStyle(); style.lineSpacing = 4
    let attr = NSAttributedString(string: s, attributes: [.font: f, .foregroundColor: c(color), .paragraphStyle: style])
    let frame = CTFramesetterCreateFrame(CTFramesetterCreateWithAttributedString(attr), CFRange(), CGPath(rect: rect, transform: nil), nil)
    CTFrameDraw(frame, ctx)
}

func drawFigure(x: CGFloat, y: CGFloat, scale: CGFloat, _ draw: (Pen) -> Void) {
    ctx.saveGState()
    ctx.translateBy(x: x, y: y); ctx.scaleBy(x: scale, y: scale)
    draw(pen)
    ctx.restoreGState()
}

func drawMascot(_ m: Mascot, x: CGFloat, y: CGFloat, scale: CGFloat) {
    drawFigure(x: x, y: y, scale: scale, m.draw)
}

func wordmark(_ size: CGFloat, centerX: CGFloat, baseline: CGFloat) {
    let f = CTFontCreateWithName("BricolageGrotesque96pt-ExtraBold" as CFString, size, nil)
    let word = CTLineCreateWithAttributedString(NSAttributedString(string: "nomi", attributes: [.font: f, .foregroundColor: c(white), .kern: -0.045 * size]))
    let ww = CTLineGetImageBounds(word, ctx).width
    ctx.textPosition = CGPoint(x: centerX - ww / 2, y: baseline); CTLineDraw(word, ctx)
}

/// Rundes App-Icon in Himbeere; `visible` ist der Ausschnitt im Raster (unten, oben), der das Icon füllt.
func appIcon(_ rect: CGRect, visible: (CGFloat, CGFloat), background: UInt32 = brand, _ draw: (Pen) -> Void) {
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)); ctx.clip()
    ctx.setFillColor(c(background)); ctx.fill(rect)
    let s = rect.height / (visible.1 - visible.0)
    drawFigure(x: rect.midX - 100 * s, y: rect.minY - visible.0 * s, scale: s, draw)
    ctx.restoreGState()
}

for (i, m) in mascots.enumerated() {
    let col = CGFloat(i) * 450
    drawMascot(m, x: col + 25, y: 520, scale: 2)
    text(m.name, font: "BricolageGrotesque96pt-ExtraBold", size: 40, color: ink, at: CGPoint(x: col + 40, y: 466))
    paragraph(m.pitch, font: "DMSans-Regular", size: 19, color: inkMuted, in: CGRect(x: col + 40, y: 368, width: 370, height: 84))

    // App-Icon: Figur schaut von unten ins Bild
    let icon = CGRect(x: col + 40, y: 150, width: 180, height: 180)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: icon, cornerWidth: 40, cornerHeight: 40, transform: nil)); ctx.clip()
    ctx.setFillColor(c(brand)); ctx.fill(icon)
    let s: CGFloat = 1.05
    drawMascot(m, x: icon.midX - 100 * s, y: icon.minY - 22 * s, scale: s)
    ctx.restoreGState()
    text("APP-ICON", font: "DMMono-Regular", size: 14, color: inkMuted, at: CGPoint(x: col + 40, y: 122))

    // Splashscreen: Himbeere, Figur, Wortmarke
    let phone = CGRect(x: col + 255, y: 40, width: 150, height: 300)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: phone, cornerWidth: 26, cornerHeight: 26, transform: nil)); ctx.clip()
    ctx.setFillColor(c(brand)); ctx.fill(phone)
    let ps: CGFloat = 0.62
    drawMascot(m, x: phone.midX - 100 * ps, y: phone.midY - 30, scale: ps)
    wordmark(34, centerX: phone.midX, baseline: phone.midY - 72)
    ctx.restoreGState()
    text("SPLASH", font: "DMMono-Regular", size: 14, color: inkMuted, at: CGPoint(x: col + 255, y: 14))
}

save(ctx, "vorschlaege.png")

// MARK: - Bogen 2: Chefi ausgearbeitet

ctx = sheet(width: 1800, height: 1560)
pen = Pen(ctx: ctx)

func heading(_ s: String, y: CGFloat) {
    text(s, font: "DMMono-Regular", size: 18, color: inkMuted, at: CGPoint(x: 60, y: y))
}

text("Chefi", font: "BricolageGrotesque96pt-ExtraBold", size: 56, color: ink, at: CGPoint(x: 60, y: 1480))

// Farben
heading("1 · KÖRPERFARBE", y: 1430)
let sand: UInt32 = 0xF1D9B5, rose: UInt32 = 0xF6C3CF
let colors: [(String, String, UInt32)] = [
    ("Mint", "frisch, „Küche & Gemüse“; klarer Abstand zur Himbeere", mint),
    ("Teig", "warm wie Brot und Knödel, harmoniert am stärksten mit Creme", sand),
    ("Rosé", "ganz in der Markenwelt – aber nah an der Himbeere", rose),
]
for (i, (name, note, color)) in colors.enumerated() {
    let x = 60 + CGFloat(i) * 580
    drawFigure(x: x + 40, y: 1000, scale: 1.75) { chefi($0, ChefiPose(body: color)) }
    text(name, font: "BricolageGrotesque96pt-ExtraBold", size: 30, color: ink, at: CGPoint(x: x + 40, y: 960))
    paragraph(note, font: "DMSans-Regular", size: 19, color: inkMuted, in: CGRect(x: x + 40, y: 880, width: 440, height: 70))
}

// Icon-Ausschnitte
heading("2 · APP-ICON-AUSSCHNITT", y: 850)
let iconSize: CGFloat = 220
let icons: [(String, (CGFloat, CGFloat), UInt32)] = [
    ("Ganze Figur", (-6, 226), mint),
    ("Nah dran (Mint)", (34, 214), mint),
    ("Nah dran (Teig)", (34, 214), sand),
    ("Nah dran (Rosé)", (34, 214), rose),
]
for (i, (name, visible, color)) in icons.enumerated() {
    let x = 60 + CGFloat(i) * 300
    appIcon(CGRect(x: x, y: 580, width: iconSize, height: iconSize), visible: visible) { chefi($0, ChefiPose(body: color)) }
    text(name, font: "DMSans-Medium", size: 19, color: ink, at: CGPoint(x: x, y: 548))
}
// Homescreen-Größe zum Vergleich
for (i, color) in [mint, sand, rose].enumerated() {
    let x = 1290 + CGFloat(i) * 150
    appIcon(CGRect(x: x, y: 680, width: 120, height: 120), visible: (34, 214)) { chefi($0, ChefiPose(body: color)) }
    appIcon(CGRect(x: x + 30, y: 600, width: 60, height: 60), visible: (34, 214)) { chefi($0, ChefiPose(body: color)) }
}
text("Homescreen-Größen", font: "DMSans-Medium", size: 19, color: ink, at: CGPoint(x: 1290, y: 548))

// Splashscreen-Ablauf
heading("3 · SPLASHSCREEN, ETWA 1 SEKUNDE", y: 490)
let frames: [(String, ChefiPose, CGFloat, CGFloat, Bool)] = [
    ("Chefi hüpft herein", ChefiPose(spoonTilt: -0.5), 0.9, 1.08, false),
    ("hebt den Löffel und zwinkert", ChefiPose(spoonTilt: -0.08, spoonLift: 20, wink: true), 1, 1, false),
    ("winkt – „nomi“ erscheint", ChefiPose(waves: true), 1, 1, true),
]
for (i, (caption, pose, sx, sy, showsWord)) in frames.enumerated() {
    let phone = CGRect(x: 60 + CGFloat(i) * 300, y: 70, width: 200, height: 400)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: phone, cornerWidth: 34, cornerHeight: 34, transform: nil)); ctx.clip()
    ctx.setFillColor(c(brand)); ctx.fill(phone)
    // Squash & Stretch: Breite sx, Höhe sy, Füße bleiben am Boden
    let s: CGFloat = 0.8
    ctx.saveGState()
    ctx.translateBy(x: phone.midX, y: phone.midY - 50)
    ctx.scaleBy(x: sx * s, y: sy * s)
    ctx.translateBy(x: -100, y: 0)
    chefi(pen, pose)
    ctx.restoreGState()
    if showsWord { wordmark(44, centerX: phone.midX, baseline: phone.midY - 110) }
    ctx.restoreGState()
    text("\(i + 1)", font: "BricolageGrotesque96pt-ExtraBold", size: 26, color: brand, at: CGPoint(x: phone.minX, y: 34))
    text(caption, font: "DMSans-Regular", size: 18, color: inkMuted, at: CGPoint(x: phone.minX + 24, y: 36))
}
paragraph("Danach blendet der Splash in den Heute-Tab über. Beim Laden ohne Netz bleibt Chefi im letzten Bild und rührt langsam weiter.",
          font: "DMSans-Regular", size: 19, color: inkMuted, in: CGRect(x: 980, y: 300, width: 560, height: 120))

save(ctx, "chefi-varianten.png")
