// Setzt die rohen Screenshots in Store-Bilder: Himbeere, Überschrift oben, darunter das Gerät leicht in 3D geneigt,
// und Chefi schaut von der Seite herein (Formen wie in design/mascot/render-mascots.swift).
// Größen nach Apple: iPhone 6,9″ 1320 × 2868, iPad 13″ quer 2752 × 2064.
//
// Aufruf (im Repo-Ordner):
//   swift store/render-store-frames.swift            alle Bilder im gewählten Stil (Standard: b)
//   swift store/render-store-frames.swift a|b        Stil a: immer gleich geneigt, Chefi rechts; b: abwechselnd
//   swift store/render-store-frames.swift vorschlag  Bogen mit beiden Stilen nach store/vorschlag-dynamisch.png
import AppKit
import CoreImage
import CoreText

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
for f in try! FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Nomi/Resources/Fonts"), includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}

func c(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}

let ink: UInt32 = 0x262B28, brand: UInt32 = 0xCC335E, cream: UInt32 = 0xFFF6E8, mint: UInt32 = 0xD3E9C8
let wood: UInt32 = 0xE2A65A, white: UInt32 = 0xFFFFFF, mouth: UInt32 = 0x8E1F3E, tongue: UInt32 = 0xF28CA6, blush: UInt32 = 0xF4A0B5

// MARK: - Texte

/// Überschrift und Unterzeile je Bildschirm
let captions: [String: (String, String)] = [
    "01-heute": ("Was gibt's heute?", "Mittag und Abend im Blick – zu zweit geplant."),
    "02-vorschlaege": ("Swipt euch zum Abendessen", "Mögt ihr beide dieselbe Karte, ist es ein Match."),
    "03-rezepte": ("Alle Rezepte an einem Ort", "Aus Links, Social Posts, Fotos und Handschrift."),
    "04-rezept": ("Portionen? Rechnet nomi um.", "Einkaufen, einplanen oder gleich loskochen."),
    "05-woche": ("Die Woche auf einen Blick", "Gerichte auf Tage ziehen, Zutaten mit einem Tipp auf die Liste."),
    "06-einkaufen": ("Live einkaufen, zu zweit", "Was Sam abhakt, siehst du sofort."),
    "07-kochen": ("Kochen Schritt für Schritt", "Mit Timern, die auch bei stummem iPhone klingeln."),
    "08-nomi": ("Frag einfach nomi", "Per Text oder Sprache: planen, vorschlagen, Liste füllen."),
]

// MARK: - Chefi

struct Pen {
    let ctx: CGContext
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
}

func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: cx - w / 2, y: cy - h / 2, width: w, height: h), transform: nil)
}

func curve(_ a: (CGFloat, CGFloat), _ ctrl: (CGFloat, CGFloat), _ b: (CGFloat, CGFloat)) -> CGPath {
    let p = CGMutablePath()
    p.move(to: CGPoint(x: a.0, y: a.1))
    p.addQuadCurve(to: CGPoint(x: b.0, y: b.1), control: CGPoint(x: ctrl.0, y: ctrl.1))
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

struct Pose {
    enum Eyes { case open, wink, happy, hearts }
    enum Mouth { case smile, laugh, oh }
    var eyes: Eyes = .open
    var mouth: Mouth = .smile
    /// Linke Pfote winkt neben dem Kopf
    var waves = false
    /// Löffel nach oben gereckt
    var spoonUp = false
}

func paw(_ pen: Pen, _ x: CGFloat, _ y: CGFloat) {
    pen.shape(ellipse(x, y, 22, 18), mint)
    pen.line(curve((x - 5, y + 3), (x, y - 1), (x + 5, y + 3)), width: 2.5)
}

/// Chefi im Raster 200 × 230, Füße unten bei y = 16
func chefi(_ pen: Pen, _ pose: Pose) {
    let cx: CGFloat = 100, b: CGFloat = 16, w: CGFloat = 130, h: CGFloat = 132
    for side in [-1.0, 1.0] as [CGFloat] { pen.shape(ellipse(cx + side * 30, b + 2, 34, 18), mint) }
    pen.shape(bean(cx, b, w, h), mint)
    pen.shape(ellipse(cx, b + h * 0.3, w * 0.62, h * 0.42), cream)
    if pose.waves {
        for (dx, dy) in [(-12.0, 4.0), (-10.0, 14.0)] as [(CGFloat, CGFloat)] {
            pen.line(curve((cx - 66 + dx, b + 96 + dy), (cx - 72 + dx, b + 102 + dy), (cx - 70 + dx, b + 110 + dy)), width: 3)
        }
        paw(pen, cx - 56, b + 96)
    } else {
        paw(pen, cx - 50, b + 50)
    }
    var hold = CGAffineTransform(translationX: cx + 40, y: b + 20 + (pose.spoonUp ? 22 : 0)).rotated(by: pose.spoonUp ? -0.05 : -0.32)
    let handle = CGMutablePath()
    handle.addRoundedRect(in: CGRect(x: -4.5, y: 0, width: 9, height: 78), cornerWidth: 4.5, cornerHeight: 4.5)
    pen.shape(handle.copy(using: &hold)!, wood)
    pen.shape(ellipse(0, 92, 26, 34).copy(using: &hold)!, wood)
    pen.line(curve((-6, 84), (0, 80), (6, 84)).copy(using: &hold)!, width: 3)
    let hand = CGPoint(x: 0, y: 34).applying(hold)
    paw(pen, hand.x, hand.y)
    let top = b + h - 8
    for (x, y, r) in [(cx - 24, top + 30, 20.0), (cx + 24, top + 30, 20.0), (cx, top + 42, 24.0)] as [(CGFloat, CGFloat, CGFloat)] {
        pen.shape(ellipse(x, y, 2 * r, 2 * r), white)
    }
    let band = CGMutablePath()
    band.addRoundedRect(in: CGRect(x: cx - 34, y: top, width: 68, height: 22), cornerWidth: 6, cornerHeight: 6)
    pen.shape(band, brand)
    // Gesicht
    let eyeY = b + h * 0.62, spacing: CGFloat = 18
    for side in [-1.0, 1.0] as [CGFloat] {
        let x = cx + side * spacing
        switch pose.eyes {
        case .happy:
            pen.line(curve((x - 6, eyeY - 2), (x, eyeY + 7), (x + 6, eyeY - 2)), width: 3.8)
        case .hearts:
            pen.shape(heart(x, eyeY + 1, 6.5), brand, stroke: false)
        case .wink where side > 0:
            pen.line(curve((x - 5.5, eyeY - 1.5), (x, eyeY + 5), (x + 5.5, eyeY - 1.5)), width: 3.5)
        default:
            pen.shape(ellipse(x, eyeY, 10.4, 10.4), ink, stroke: false)
            pen.shape(ellipse(x + 1.6, eyeY + 1.9, 3.4, 3.4), white, stroke: false)
        }
        if pose.eyes == .happy || pose.eyes == .hearts {
            pen.shape(heart(cx + side * spacing * 1.8, eyeY - 10, 6), blush, stroke: false)
        } else {
            pen.shape(ellipse(cx + side * spacing * 1.75, eyeY - 9, 15, 9), blush, stroke: false)
        }
    }
    let mouthTop = eyeY - 4
    if pose.mouth == .oh {
        pen.shape(ellipse(cx, mouthTop - 6, 11, 13), mouth)
        return
    }
    let r: CGFloat = pose.mouth == .laugh ? 15 : 10
    let m = CGMutablePath()
    m.move(to: CGPoint(x: cx - r, y: mouthTop))
    m.addLine(to: CGPoint(x: cx + r, y: mouthTop))
    m.addArc(center: CGPoint(x: cx, y: mouthTop), radius: r, startAngle: 0, endAngle: .pi, clockwise: true)
    m.closeSubpath()
    pen.shape(m, mouth, stroke: false)
    pen.ctx.saveGState(); pen.ctx.addPath(m); pen.ctx.clip()
    pen.shape(ellipse(cx + 1, mouthTop - r * 0.95, r * 1.3, r * 0.9), tongue, stroke: false)
    pen.ctx.restoreGState()
    pen.shape(m, nil, width: 3.5)
}

// MARK: - Gestaltung je Bild

/// Wie ein Bild aussieht: Neigung, Seite und Höhe, aus der Chefi hereinschaut, seine Pose
struct Look {
    /// +1: rechte Kante weiter weg (Gerät dreht nach rechts), −1: links
    var tilt: CGFloat
    /// Seite, an der Chefi hereinschaut
    var chefiRight: Bool
    /// Höhe von Chefis Kopf, Anteil der Gerätehöhe von unten
    var chefiHeight: CGFloat
    var pose: Pose
}

/// Stil a: immer gleich geneigt, Chefi rechts; b: Neigung und Seite wechseln, Chefi auf verschiedenen Höhen
func look(style: String, index: Int) -> Look {
    let poses: [Pose] = [
        Pose(eyes: .open, waves: true),
        Pose(eyes: .hearts, mouth: .laugh),
        Pose(eyes: .wink, spoonUp: true),
        Pose(eyes: .open, mouth: .oh),
        Pose(eyes: .happy, mouth: .laugh),
        Pose(eyes: .wink, waves: true),
        Pose(eyes: .open, mouth: .laugh, spoonUp: true),
        Pose(eyes: .happy, waves: true),
    ]
    let pose = poses[index % poses.count]
    if style == "a" {
        return Look(tilt: 1, chefiRight: true, chefiHeight: 0.42, pose: pose)
    }
    let right = index % 2 == 0
    return Look(tilt: right ? 1 : -1, chefiRight: right, chefiHeight: [0.5, 0.32, 0.62, 0.4][index % 4], pose: pose)
}

// MARK: - Zeichnen

struct Device {
    let folder: String
    let size: CGSize
    let titleSize: CGFloat
    let subSize: CGFloat
    let top: CGFloat
    /// Anteil der Bildbreite fürs Gerät
    let shotWidth: CGFloat
    let radius: CGFloat
    let bezel: CGFloat
    /// Chefi-Größe als Anteil der Bildbreite
    let chefiWidth: CGFloat
}

let devices = [
    Device(folder: "iphone", size: CGSize(width: 1320, height: 2868), titleSize: 104, subSize: 46, top: 190, shotWidth: 0.78, radius: 110, bezel: 22, chefiWidth: 0.36),
    Device(folder: "ipad", size: CGSize(width: 2752, height: 2064), titleSize: 112, subSize: 48, top: 150, shotWidth: 0.74, radius: 56, bezel: 20, chefiWidth: 0.16),
]

let ciContext = CIContext()

/// Screenshot mit dunklem Rahmen und runden Ecken als eigenes Bild (mit Transparenz)
func framedScreen(_ shot: CGImage, size: CGSize, radius: CGFloat, bezel: CGFloat) -> CGImage {
    let ctx = CGContext(data: nil, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let outer = CGRect(origin: .zero, size: size)
    ctx.addPath(CGPath(roundedRect: outer, cornerWidth: radius, cornerHeight: radius, transform: nil))
    ctx.setFillColor(c(0x1E2220)); ctx.fillPath()
    let inner = outer.insetBy(dx: bezel, dy: bezel)
    ctx.saveGState()
    ctx.addPath(CGPath(roundedRect: inner, cornerWidth: radius - bezel, cornerHeight: radius - bezel, transform: nil)); ctx.clip()
    ctx.draw(shot, in: inner)
    ctx.restoreGState()
    return ctx.makeImage()!
}

/// Perspektive: eine Kante rückt nach hinten (kürzer, leicht nach innen), wie ein um die Hochachse gedrehtes Gerät
func tilted(_ image: CGImage, tilt: CGFloat, depth: CGFloat = 0.075) -> (CIImage, CGRect) {
    let w = CGFloat(image.width), h = CGFloat(image.height)
    let shrink = h * depth, inset = w * depth * 0.9
    let input = CIImage(cgImage: image)
    let filter = CIFilter(name: "CIPerspectiveTransform")!
    filter.setValue(input, forKey: kCIInputImageKey)
    // CI-Koordinaten: Ursprung unten links
    let far = tilt > 0
    filter.setValue(CIVector(x: far ? 0 : inset, y: far ? h : h - shrink), forKey: "inputTopLeft")
    filter.setValue(CIVector(x: far ? w - inset : w, y: far ? h - shrink : h), forKey: "inputTopRight")
    filter.setValue(CIVector(x: far ? 0 : inset, y: far ? 0 : shrink), forKey: "inputBottomLeft")
    filter.setValue(CIVector(x: far ? w - inset : w, y: far ? shrink : 0), forKey: "inputBottomRight")
    let output = filter.outputImage!
    return (output, output.extent)
}

func line(_ text: String, font: String, size: CGFloat, color: CGColor) -> CTLine {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: f, .foregroundColor: color]))
}

func drawCentered(_ l: CTLine, in ctx: CGContext, centerX: CGFloat, baseline: CGFloat) {
    let width = CTLineGetTypographicBounds(l, nil, nil, nil)
    ctx.textPosition = CGPoint(x: centerX - width / 2, y: baseline)
    CTLineDraw(l, ctx)
}

/// Ein Store-Bild
func render(_ shot: CGImage, key: String, device: Device, look: Look) -> CGImage {
    let (title, iPhoneSubtitle) = captions[key] ?? ("", "")
    let subtitle = device.folder == "ipad" ? iPhoneSubtitle.replacingOccurrences(of: "iPhone", with: "iPad") : iPhoneSubtitle
    let W = device.size.width, H = device.size.height
    let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    // Himbeere mit sanftem Verlauf nach unten
    let gradient = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: [c(0xD43C67), c(0xB82A52)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: H), end: CGPoint(x: W * 0.3, y: 0),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    let titleBaseline = H - device.top
    // Lange Überschriften etwas kleiner, damit sie nicht an den Rand stoßen
    var titleLine = line(title, font: "BricolageGrotesque96pt-ExtraBold", size: device.titleSize, color: c(white))
    let titleWidth = CTLineGetTypographicBounds(titleLine, nil, nil, nil)
    if titleWidth > W * 0.88 {
        titleLine = line(title, font: "BricolageGrotesque96pt-ExtraBold", size: device.titleSize * W * 0.88 / titleWidth, color: c(white))
    }
    drawCentered(titleLine, in: ctx, centerX: W / 2, baseline: titleBaseline)
    drawCentered(line(subtitle, font: "DMSans-Regular", size: device.subSize, color: c(white, 0.88)), in: ctx, centerX: W / 2, baseline: titleBaseline - device.subSize * 1.9)

    // Gerät
    let deviceW = W * device.shotWidth
    let deviceH = deviceW * CGFloat(shot.height) / CGFloat(shot.width)
    let framed = framedScreen(shot, size: CGSize(width: deviceW, height: deviceH), radius: device.radius, bezel: device.bezel)
    let (tiltedImage, extent) = tilted(framed, tilt: look.tilt)
    let deviceTop = titleBaseline - device.subSize * 1.9 - device.subSize * 2.2
    // Zur Seite versetzt, damit Platz für Chefi bleibt
    let shift = (look.chefiRight ? -1 : 1) * W * 0.07
    let deviceRect = CGRect(x: (W - extent.width) / 2 + shift, y: deviceTop - extent.height, width: extent.width, height: extent.height)

    // Chefi steht hinter dem Gerät und lehnt sich hinaus
    let chefiW = W * device.chefiWidth
    let scale = chefiW / 200
    let chefiCenterY = deviceRect.minY + deviceRect.height * look.chefiHeight
    let edgeX = look.chefiRight ? deviceRect.maxX : deviceRect.minX
    ctx.saveGState()
    // Mitte knapp außerhalb der Kante: gut die Hälfte schaut heraus, der Rest steckt hinter dem Gerät
    ctx.translateBy(x: edgeX + (look.chefiRight ? chefiW * 0.1 : -chefiW * 0.1), y: chefiCenterY - 115 * scale)
    ctx.rotate(by: look.chefiRight ? -0.32 : 0.32)
    ctx.scaleBy(x: look.chefiRight ? scale : -scale, y: scale) // links gespiegelt, damit er immer zur Mitte schaut
    ctx.translateBy(x: -100, y: 0)
    chefi(Pen(ctx: ctx), look.pose)
    ctx.restoreGState()

    // Gerät vor Chefi, mit Schatten
    let cgTilted = ciContext.createCGImage(tiltedImage, from: extent)!
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: look.tilt * -24, height: -30), blur: 70, color: c(0x000000, 0.32))
    ctx.draw(cgTilted, in: deviceRect)
    ctx.restoreGState()

    // Eine Pfote hält sich am Rand fest
    ctx.saveGState()
    let pawY = chefiCenterY + 30 * scale
    ctx.translateBy(x: edgeX + (look.chefiRight ? -8 * scale : 8 * scale), y: pawY)
    ctx.scaleBy(x: scale * 1.4, y: scale * 1.4)
    paw(Pen(ctx: ctx), 0, 0)
    ctx.restoreGState()

    return ctx.makeImage()!
}

func write(_ image: CGImage, to url: URL) {
    try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url)
}

func rawShots(_ device: Device) -> [(String, CGImage)] {
    let dir = root.appendingPathComponent("store/screenshots/roh/\(device.folder)")
    let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
    return files.filter { $0.pathExtension == "png" }.sorted { $0.lastPathComponent < $1.lastPathComponent }.compactMap { file in
        NSImage(contentsOf: file)?.cgImage(forProposedRect: nil, context: nil, hints: nil).map { (file.deletingPathExtension().lastPathComponent, $0) }
    }
}

// MARK: - Ablauf

let mode = CommandLine.arguments.dropFirst().first ?? "b"

if mode == "vorschlag" {
    // Bogen: die ersten drei iPhone-Bilder in beiden Stilen, so wie sie im Store nebeneinander stehen
    let device = devices[0]
    let shots = Array(rawShots(device).prefix(3))
    let thumbW: CGFloat = 440, thumbH = thumbW * device.size.height / device.size.width
    let sheetW = 60 + (thumbW + 24) * 3 + 60, sheetH = 200 + (thumbH + 120) * 2
    let sheet = CGContext(data: nil, width: Int(sheetW), height: Int(sheetH), bitsPerComponent: 8, bytesPerRow: 0,
                          space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    sheet.setFillColor(c(0xEFEBE3)); sheet.fill(CGRect(x: 0, y: 0, width: sheetW, height: sheetH))
    func label(_ s: String, _ font: String, _ size: CGFloat, _ color: UInt32, _ x: CGFloat, _ y: CGFloat) {
        sheet.textPosition = CGPoint(x: x, y: y); CTLineDraw(line(s, font: font, size: size, color: c(color)), sheet)
    }
    label("Store-Bilder, dynamischer", "BricolageGrotesque96pt-ExtraBold", 44, ink, 60, sheetH - 80)
    label("So stehen die ersten drei im App Store nebeneinander.", "DMSans-Regular", 20, 0x6E726F, 60, sheetH - 116)
    for (row, style) in ["a", "b"].enumerated() {
        let y = sheetH - 200 - CGFloat(row + 1) * (thumbH + 120) + 120
        label(style == "a" ? "A · Immer gleich geneigt, Chefi rechts" : "B · Abwechselnd geneigt, Chefi wechselt Seite und Höhe",
              "DMSans-SemiBold", 22, ink, 60, y + thumbH + 30)
        for (i, (key, shot)) in shots.enumerated() {
            let image = render(shot, key: key, device: device, look: look(style: style, index: i))
            let rect = CGRect(x: 60 + CGFloat(i) * (thumbW + 24), y: y, width: thumbW, height: thumbH)
            sheet.saveGState()
            sheet.addPath(CGPath(roundedRect: rect, cornerWidth: 26, cornerHeight: 26, transform: nil)); sheet.clip()
            sheet.draw(image, in: rect)
            sheet.restoreGState()
        }
    }
    write(sheet.makeImage()!, to: root.appendingPathComponent("store/vorschlag-dynamisch.png"))
    print("store/vorschlag-dynamisch.png")
} else {
    for device in devices {
        let outDir = root.appendingPathComponent("store/screenshots/\(device.folder)")
        try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
        for (i, (key, shot)) in rawShots(device).enumerated() {
            write(render(shot, key: key, device: device, look: look(style: mode, index: i)), to: outDir.appendingPathComponent("\(key).png"))
            print("\(device.folder)/\(key).png")
        }
    }
}
