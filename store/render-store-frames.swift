// Setzt die rohen Screenshots in Store-Bilder mit Überschrift: Himbeere, Text oben, Screenshot mit runden Ecken darunter.
// Größen nach Apple: iPhone 6,9″ 1320 × 2868, iPad 13″ quer 2752 × 2064.
// Aufruf (im Repo-Ordner): swift store/render-store-frames.swift
import AppKit
import CoreText

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
for f in try! FileManager.default.contentsOfDirectory(at: root.appendingPathComponent("Nomi/Resources/Fonts"), includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}

func c(_ h: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: a)
}

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

struct Device {
    let folder: String
    let size: CGSize
    let titleSize: CGFloat
    let subSize: CGFloat
    let top: CGFloat
    /// Anteil der Bildbreite für den Screenshot
    let shotWidth: CGFloat
    let radius: CGFloat
}

let devices = [
    Device(folder: "iphone", size: CGSize(width: 1320, height: 2868), titleSize: 104, subSize: 46, top: 190, shotWidth: 0.8, radius: 96),
    Device(folder: "ipad", size: CGSize(width: 2752, height: 2064), titleSize: 112, subSize: 48, top: 150, shotWidth: 0.82, radius: 44),
]

func line(_ text: String, font: String, size: CGFloat, color: CGColor) -> CTLine {
    let f = CTFontCreateWithName(font as CFString, size, nil)
    return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: f, .foregroundColor: color]))
}

func drawCentered(_ l: CTLine, in ctx: CGContext, centerX: CGFloat, baseline: CGFloat) {
    let width = CTLineGetTypographicBounds(l, nil, nil, nil)
    ctx.textPosition = CGPoint(x: centerX - width / 2, y: baseline)
    CTLineDraw(l, ctx)
}

for device in devices {
    let rawDir = root.appendingPathComponent("store/screenshots/roh/\(device.folder)")
    let outDir = root.appendingPathComponent("store/screenshots/\(device.folder)")
    guard let files = try? FileManager.default.contentsOfDirectory(at: rawDir, includingPropertiesForKeys: nil) else { continue }
    try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)
    for file in files.filter({ $0.pathExtension == "png" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
        let key = file.deletingPathExtension().lastPathComponent
        guard let (title, iPhoneSubtitle) = captions[key],
              let image = NSImage(contentsOf: file)?.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
        // Auf dem iPad soll auch „iPad“ dastehen
        let subtitle = device.folder == "ipad" ? iPhoneSubtitle.replacingOccurrences(of: "iPhone", with: "iPad") : iPhoneSubtitle
        let W = device.size.width, H = device.size.height
        let ctx = CGContext(data: nil, width: Int(W), height: Int(H), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
        ctx.setFillColor(c(0xCC335E)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

        // Text oben
        let titleBaseline = H - device.top
        drawCentered(line(title, font: "BricolageGrotesque96pt-ExtraBold", size: device.titleSize, color: c(0xFFFFFF)), in: ctx, centerX: W / 2, baseline: titleBaseline)
        drawCentered(line(subtitle, font: "DMSans-Regular", size: device.subSize, color: c(0xFFFFFF, 0.88)), in: ctx, centerX: W / 2, baseline: titleBaseline - device.subSize * 1.9)

        // Screenshot darunter, unten angeschnitten wirkt es wie ein Gerät, das ins Bild ragt
        let shotW = W * device.shotWidth
        let shotH = shotW * CGFloat(image.height) / CGFloat(image.width)
        let shotTop = titleBaseline - device.subSize * 1.9 - device.subSize * 1.6
        let shotRect = CGRect(x: (W - shotW) / 2, y: shotTop - shotH, width: shotW, height: shotH)
        let path = CGPath(roundedRect: shotRect, cornerWidth: device.radius, cornerHeight: device.radius, transform: nil)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 60, color: c(0x000000, 0.28))
        ctx.addPath(path); ctx.setFillColor(c(0xFFFFFF)); ctx.fillPath()
        ctx.restoreGState()
        ctx.saveGState()
        ctx.addPath(path); ctx.clip()
        ctx.draw(image, in: shotRect)
        ctx.restoreGState()
        ctx.addPath(path); ctx.setStrokeColor(c(0x262B28, 0.9)); ctx.setLineWidth(device.folder == "iphone" ? 14 : 10); ctx.strokePath()

        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(file.lastPathComponent))
        print("\(device.folder)/\(file.lastPathComponent)")
    }
}
