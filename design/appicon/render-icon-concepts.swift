// App-Icon-Konzepte: Wortmarke „nomi“ (DynaPuff, angebissenes Ocker-o) zusammen mit Chefi.
// Bögen:  swift design/appicon/render-icon-concepts.swift design/fonts/DynaPuff.ttf Nomi/Resources/Fonts design/appicon/konzepte.png [design/appicon/konzept-d.png]
// Export: swift design/appicon/render-icon-concepts.swift design/fonts/DynaPuff.ttf Nomi/Resources/Fonts --export Nomi/Resources/Assets.xcassets
//         schreibt das App-Icon (Konzept D2) und die Wortmarke als Vektor-PDF in den Asset-Katalog.
import AppKit
import CoreText

let fontURL = URL(fileURLWithPath: CommandLine.arguments[1])
for f in try! FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: CommandLine.arguments[2]), includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}

func c(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}
let ink: UInt32 = 0x262B28, inkMuted: UInt32 = 0x6E726F, brand: UInt32 = 0xCC335E, canvas: UInt32 = 0xF7F4EE
let white: UInt32 = 0xFFFFFF, cream: UInt32 = 0xFFF6E8, ochre: UInt32 = 0xF2B33D, mint: UInt32 = 0xD3E9C8
let wood: UInt32 = 0xE2A65A, mouthColor: UInt32 = 0x8E1F3E, tongue: UInt32 = 0xF28CA6, blush: UInt32 = 0xF4A0B5

var ctx: CGContext!

// MARK: - Zeichenhilfen (Chefi: Raster 200 × 230, Ursprung unten links)

func shape(_ path: CGPath, _ fill: UInt32?, stroke: Bool = true, width: CGFloat = 4.5) {
    if let fill { ctx.addPath(path); ctx.setFillColor(c(fill)); ctx.fillPath() }
    if stroke {
        ctx.addPath(path); ctx.setStrokeColor(c(ink)); ctx.setLineWidth(width)
        ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath()
    }
}
func line(_ path: CGPath, width: CGFloat = 4.5) {
    ctx.addPath(path); ctx.setStrokeColor(c(ink)); ctx.setLineWidth(width)
    ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.strokePath()
}
func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h), transform: nil)
}
func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> CGPath { ellipse(cx, cy, 2 * r, 2 * r) }
func curve(_ a: (CGFloat, CGFloat), _ ctrl: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: a.0, y: a.1))
    p.addQuadCurve(to: CGPoint(x: b.0, y: b.1), control: CGPoint(x: ctrl.0, y: ctrl.1))
    return p
}
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

// MARK: - DynaPuff-Buchstaben

func tag(_ s: String) -> Int { s.unicodeScalars.reduce(0) { $0 << 8 | Int($1.value) } }
let font = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithAttributes(
    (CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as! [CTFontDescriptor])[0],
    [kCTFontVariationAttribute: [NSNumber(value: tag("wght")): NSNumber(value: 650)]] as CFDictionary
), 100, nil)

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
        x += advance.width - 2
        return path
    }
}
let wordLetters = letters("nomi")
let oBox = wordLetters[1].boundingBox
func biteMark() -> CGPath {
    let r = oBox.width * 0.17
    let corner = CGPoint(x: oBox.maxX - oBox.width * 0.08, y: oBox.maxY - oBox.height * 0.08)
    return [(-1.55, 0.55), (-0.35, -0.2), (0.5, -1.35)].map { circle(corner.x + $0.0 * r, corner.y + $0.1 * r, r) }
        .reduce(CGMutablePath() as CGPath) { $0.union($1) }
}
let bittenO = wordLetters[1].subtracting(biteMark())
let word = { () -> [(CGPath, UInt32)] in
    var w = wordLetters.map { ($0, white) }
    w[1] = (bittenO, ochre)
    return w
}()
let wordBounds = word.reduce(CGRect.null) { $0.union($1.0.boundingBox) }

/// Wortmarke in `rect` einpassen; optional mit Rand in Hintergrundfarbe (Sticker-Effekt über Chefi)
func drawWord(in rect: CGRect, outline: CGFloat = 0, text: UInt32 = white, o: UInt32 = ochre) {
    let s = min(rect.width / wordBounds.width, rect.height / wordBounds.height)
    ctx.saveGState()
    ctx.translateBy(x: rect.midX - wordBounds.midX * s, y: rect.midY - wordBounds.midY * s)
    ctx.scaleBy(x: s, y: s)
    if outline > 0 {
        for (p, _) in word {
            ctx.addPath(p); ctx.setStrokeColor(c(brand)); ctx.setLineWidth(outline / s); ctx.setLineJoin(.round); ctx.strokePath()
        }
    }
    for (i, (p, _)) in word.enumerated() { ctx.addPath(p); ctx.setFillColor(c(i == 1 ? o : text)); ctx.fillPath() }
    ctx.restoreGState()
}

/// Angebissener Keks (das o) mit Mitte in `center`, Breite `width` – im aktuellen Koordinatensystem
func cookie(center: CGPoint, width: CGFloat, outlined: Bool) {
    let s = width / oBox.width
    var t = CGAffineTransform(translationX: center.x, y: center.y).scaledBy(x: s, y: s).translatedBy(x: -oBox.midX, y: -oBox.midY)
    let p = bittenO.copy(using: &t)!
    shape(p, ochre, stroke: outlined, width: 4)
}

// MARK: - Chefi

struct Pose {
    var spoon = true
    var cookie = false
    var waves = false
    var lookRight = false
    var hat = true
}

func paw(_ x: CGFloat, _ y: CGFloat) {
    shape(ellipse(x, y, 22, 18), mint)
    line(curve((x - 5, y + 3), (x, y - 1), (x + 5, y + 3)), width: 2.5)
}

func face(cx: CGFloat, eyeY: CGFloat, lookRight: Bool) {
    let look: CGFloat = lookRight ? 3 : 0
    for side in [-1.0, 1.0] as [CGFloat] {
        let x = cx + side * 18 + look
        shape(circle(x, eyeY, 5.2), ink, stroke: false)
        shape(circle(x + 1.6, eyeY + 1.9, 1.7), white, stroke: false)
        shape(ellipse(cx + side * 31.5, eyeY - 9, 15, 9), blush, stroke: false)
    }
    let top = eyeY - 4, r: CGFloat = 10
    let m = CGMutablePath()
    m.move(to: CGPoint(x: cx - r + look, y: top))
    m.addLine(to: CGPoint(x: cx + r + look, y: top))
    m.addArc(center: CGPoint(x: cx + look, y: top), radius: r, startAngle: 0, endAngle: .pi, clockwise: true)
    m.closeSubpath()
    shape(m, mouthColor, stroke: false)
    ctx.saveGState(); ctx.addPath(m); ctx.clip()
    shape(ellipse(cx + 1 + look, top - r * 0.95, r * 1.3, r * 0.9), tongue, stroke: false)
    ctx.restoreGState()
    shape(m, nil, width: 3.5)
}

func chefi(_ pose: Pose = Pose()) {
    let cx: CGFloat = 100, b: CGFloat = 16, w: CGFloat = 130, h: CGFloat = 132
    for side in [-1.0, 1.0] as [CGFloat] { shape(ellipse(cx + side * 30, b + 2, 34, 18), mint) }
    shape(bean(cx, b, w, h), mint)
    shape(ellipse(cx, b + h * 0.3, w * 0.62, h * 0.42), cream)
    if pose.waves {
        paw(cx - 56, b + 96)
    } else {
        paw(cx - 50, b + 50)
    }
    if pose.spoon {
        var hold = CGAffineTransform(translationX: cx + 40, y: b + 20).rotated(by: -0.32)
        let handle = CGMutablePath()
        handle.addRoundedRect(in: CGRect(x: -4.5, y: 0, width: 9, height: 78), cornerWidth: 4.5, cornerHeight: 4.5)
        shape(handle.copy(using: &hold)!, wood)
        shape(ellipse(0, 92, 26, 34).copy(using: &hold)!, wood)
        let hand = CGPoint(x: 0, y: 34).applying(hold)
        paw(hand.x, hand.y)
    }
    if pose.cookie {
        // Angebissener Keks in der rechten Pfote, Krümel daneben
        cookie(center: CGPoint(x: cx + 58, y: b + 74), width: 58, outlined: true)
        paw(cx + 46, b + 50)
        for (x, y, r) in [(cx + 92.0, b + 104.0, 3.2), (cx + 98.0, b + 90.0, 2.4), (cx + 86.0, b + 116.0, 2.0)] as [(CGFloat, CGFloat, CGFloat)] {
            shape(circle(x, y, r), ochre, stroke: true, width: 2)
        }
    }
    let top = b + h - 8
    if pose.hat {
        for (x, y, r) in [(cx - 24, top + 30, 20.0), (cx + 24, top + 30, 20.0), (cx, top + 42, 24.0)] as [(CGFloat, CGFloat, CGFloat)] {
            shape(circle(x, y, r), white)
        }
        shape(CGPath(roundedRect: CGRect(x: cx - 34, y: top, width: 68, height: 22), cornerWidth: 6, cornerHeight: 6, transform: nil), brand)
    }
    face(cx: cx, eyeY: b + h * 0.62, lookRight: pose.lookRight)
}

/// Chefi zeichnen: `visible` = sichtbarer Rasterbereich (unten, oben), zentriert auf `centerX`
func drawChefi(in rect: CGRect, visible: (CGFloat, CGFloat), centerX: CGFloat = 100, offsetX: CGFloat = 0, pose: Pose = Pose()) {
    let s = rect.height / (visible.1 - visible.0)
    ctx.saveGState()
    ctx.translateBy(x: rect.midX - centerX * s + offsetX, y: rect.minY - visible.0 * s)
    ctx.scaleBy(x: s, y: s)
    chefi(pose)
    ctx.restoreGState()
}

// MARK: - Konzepte (1024 × 1024)

struct Concept { let name: String; let note: String; let draw: (CGRect) -> Void }

let concepts: [Concept] = [
    Concept(name: "A · Chefi über dem Schriftzug", note: "Chefi schaut von oben, die Wortmarke liegt wie ein Aufkleber davor.") { r in
        drawChefi(in: CGRect(x: r.minX, y: r.minY + r.height * 0.18, width: r.width, height: r.height * 0.9), visible: (40, 214), centerX: 104)
        drawWord(in: CGRect(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.07, width: r.width * 0.8, height: r.height * 0.3), outline: r.width * 0.035)
    },
    Concept(name: "B · Chefi mit Keks", note: "Chefi hält das angebissene o als Keks – ohne Schrift, die Marke steckt im Keks.") { r in
        drawChefi(in: r, visible: (-10, 226), centerX: 112, pose: Pose(spoon: false, cookie: true))
    },
    Concept(name: "C · Chefi knabbert", note: "Chefi hat gerade in den großen Keks gebissen – Krümel fliegen, der Biss ist das Logo.") { r in
        drawChefi(in: CGRect(x: r.minX, y: r.minY - r.height * 0.02, width: r.width, height: r.height * 0.92), visible: (-6, 226), centerX: 100, offsetX: -r.width * 0.2, pose: Pose(spoon: false, lookRight: true))
        // Großer Keks rechts, Biss zeigt zu Chefi (gespiegelt)
        ctx.saveGState()
        let s = r.width * 0.5 / oBox.width
        ctx.translateBy(x: r.maxX - r.width * 0.24, y: r.minY + r.height * 0.36)
        ctx.scaleBy(x: -s, y: s)
        ctx.translateBy(x: -oBox.midX, y: -oBox.midY)
        ctx.addPath(bittenO); ctx.setStrokeColor(c(ink)); ctx.setLineWidth(4.5 * 200 / (r.width * 0.92) * r.width / (s * 230) ); ctx.setLineJoin(.round); ctx.strokePath()
        ctx.addPath(bittenO); ctx.setFillColor(c(ochre)); ctx.fillPath()
        ctx.restoreGState()
        // Pfote am Keks, Krümel
        let k = r.width / 1024
        ctx.saveGState()
        ctx.translateBy(x: r.minX, y: r.minY); ctx.scaleBy(x: k * 4.2, y: k * 4.2)
        paw(146, 72)
        for (x, y, rr) in [(150.0, 132.0, 3.4), (160.0, 146.0, 2.6), (140.0, 150.0, 2.2), (168.0, 128.0, 2.0)] as [(CGFloat, CGFloat, CGFloat)] {
            shape(circle(x, y, rr), ochre, stroke: true, width: 1.8)
        }
        ctx.restoreGState()
    },
    Concept(name: "D · Chefi lugt von unten", note: "Der Schriftzug steht oben, Chefi schaut über die Kante und hält sich an den Buchstaben fest.") { r in
        drawChefi(in: CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height * 0.7), visible: (62, 214), centerX: 100, pose: Pose(spoon: false))
        drawWord(in: CGRect(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.62, width: r.width * 0.8, height: r.height * 0.26), outline: r.width * 0.035)
    },
    Concept(name: "D2 · ohne Mütze, minimal größer", note: "Chefi ohne Mütze, rund 15 % größer – der Kopf rutscht knapp unter den Schriftzug.") { r in
        drawChefi(in: CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height * 0.66), visible: (62, 160), centerX: 100, pose: Pose(spoon: false, hat: false))
        drawWord(in: CGRect(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.64, width: r.width * 0.8, height: r.height * 0.24), outline: r.width * 0.035)
    },
    Concept(name: "D3 · ohne Mütze, etwas größer", note: "Noch ein Stück näher: Gesicht und Bäckchen werden zum Blickfang, der Bauch ist angeschnitten.") { r in
        drawChefi(in: CGRect(x: r.minX, y: r.minY, width: r.width, height: r.height * 0.7), visible: (72, 158), centerX: 100, pose: Pose(spoon: false, hat: false))
        drawWord(in: CGRect(x: r.minX + r.width * 0.1, y: r.minY + r.height * 0.66, width: r.width * 0.8, height: r.height * 0.23), outline: r.width * 0.035)
    },
]

// MARK: - Export in den Asset-Katalog

if let flag = CommandLine.arguments.firstIndex(of: "--export") {
    let assets = URL(fileURLWithPath: CommandLine.arguments[flag + 1])

    // App-Icon: D2, eckig (iOS rundet selbst ab)
    ctx = CGContext(data: nil, width: 1024, height: 1024, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    let full = CGRect(x: 0, y: 0, width: 1024, height: 1024)
    ctx.setFillColor(c(brand)); ctx.fill(full)
    concepts.first { $0.name.hasPrefix("D2") }!.draw(full)
    try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
        .write(to: assets.appendingPathComponent("AppIcon.appiconset/AppIcon.png"))

    // Wortmarke als PDF mit 100 pt Höhe: weiß auf Himbeere, Himbeere auf hellem Grund
    for (name, text, o) in [("Wordmark", white, ochre), ("WordmarkOnLight", brand, 0xE8971C as UInt32)] {
        let height: CGFloat = 100
        var box = CGRect(x: 0, y: 0, width: height * wordBounds.width / wordBounds.height, height: height)
        let dir = assets.appendingPathComponent("\(name).imageset")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        ctx = CGContext(dir.appendingPathComponent("wordmark.pdf") as CFURL, mediaBox: &box, nil)!
        ctx.beginPDFPage(nil)
        drawWord(in: box, text: text, o: o)
        ctx.endPDFPage()
        ctx.closePDF()
        try! """
        {
          "images" : [ { "filename" : "wordmark.pdf", "idiom" : "universal" } ],
          "info" : { "author" : "xcode", "version" : 1 },
          "properties" : { "preserves-vector-representation" : true, "template-rendering-intent" : "original" }
        }

        """.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    }
    exit(0)
}

// Optional nur die D-Varianten (vierter Pfad)
let shown = CommandLine.arguments.count > 4 ? concepts.filter { $0.name.hasPrefix("D") } : Array(concepts.prefix(4))

// MARK: - Bogen

let iconSize: CGFloat = 400
let W = Int(CGFloat(shown.count) * (iconSize + 40) + 60), H = 820
ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(c(canvas)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

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

func icon(_ concept: Concept, in rect: CGRect) {
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: rect, cornerWidth: rect.width * 0.225, cornerHeight: rect.width * 0.225, transform: nil)); ctx.clip()
    ctx.setFillColor(c(brand)); ctx.fill(rect)
    concept.draw(rect)
    ctx.restoreGState()
}

text("App-Icon: Wortmarke + Chefi", font: "BricolageGrotesque96pt-ExtraBold", size: 44, color: ink, at: CGPoint(x: 30, y: CGFloat(H) - 76))
for (i, concept) in shown.enumerated() {
    let x = 30 + CGFloat(i) * (iconSize + 40)
    text(concept.name, font: "BricolageGrotesque96pt-ExtraBold", size: 22, color: ink, at: CGPoint(x: x, y: CGFloat(H) - 130))
    text(concept.note, font: "DMSans-Regular", size: 15, color: inkMuted, at: CGPoint(x: x, y: CGFloat(H) - 142), width: iconSize)
    icon(concept, in: CGRect(x: x, y: 180, width: iconSize, height: iconSize))
    // Homescreen-Größen
    icon(concept, in: CGRect(x: x, y: 40, width: 120, height: 120))
    icon(concept, in: CGRect(x: x + 140, y: 70, width: 60, height: 60))
    icon(concept, in: CGRect(x: x + 220, y: 80, width: 40, height: 40))
    text("HOMESCREEN", font: "DMMono-Regular", size: 12, color: inkMuted, at: CGPoint(x: x + 140, y: 50))
}

try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: CommandLine.arguments[CommandLine.arguments.count > 4 ? 4 : 3]))
