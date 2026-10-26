// Wortmarke „nomi“ in modernen kalligrafischen Schriften (Google Fonts, OFL/Apache):
// groß auf Himbeere und Creme, dazu klein in Kopfzeilengröße.
// Aufruf: swift design/wordmark/render-script-wordmarks.swift <Ordner mit TTFs> Nomi/Resources/Fonts design/wordmark/schrift-vorschlaege.png
import AppKit
import CoreText

for dir in CommandLine.arguments[1...2] {
    for f in try! FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil) where f.pathExtension == "ttf" {
        CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
    }
}

func c(_ h: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1)
}
let ink: UInt32 = 0x262B28, inkMuted: UInt32 = 0x6E726F, brand: UInt32 = 0xCC335E, canvas: UInt32 = 0xF7F4EE, white: UInt32 = 0xFFFFFF

let fonts: [(ps: String, name: String, note: String)] = [
    ("Pacifico-Regular", "Pacifico", "Rund, fröhlich, Surf-Diner. Sehr gut lesbar, aber oft gesehen."),
    ("KaushanScript-Regular", "Kaushan Script", "Pinselschrift mit Schwung – handgemacht, energisch."),
    ("Yellowtail-Regular", "Yellowtail", "Elegant geneigt, Retro-Schild. Klein etwas zart."),
    ("Damion-Regular", "Damion", "Weiche, kräftige Schreibschrift, wie mit Filzstift."),
    ("Shrikhand-Regular", "Shrikhand", "Fette, kursive Display-Schrift. Sehr präsent, Food-Truck-Charme."),
    ("LeckerliOne-Regular", "Leckerli One", "Verspielte Pinselschrift, wie handbeschriftete Speisekarte."),
    ("GrandHotel-Regular", "Grand Hotel", "Klassische Schreibschrift mit Hotel-Eleganz."),
    ("Sriracha-Regular", "Sriracha", "Locker handgeschrieben, ehrlich und modern-leicht."),
]

let cols = 4
let tileW: CGFloat = 400, tileH: CGFloat = 170, gap: CGFloat = 26
let blockH = 70 + tileH * 2 + gap + 74 + 60
let W = Int(CGFloat(cols) * (tileW + gap) + 60), H = Int(CGFloat((fonts.count + cols - 1) / cols) * blockH + 130)
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(c(canvas)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

func line(_ s: String, font: CTFont, color: UInt32) -> CTLine {
    CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: c(color)]))
}

/// „nomi“ so groß, dass es `width` füllt, mittig in `rect`
func wordmark(_ ps: String, in rect: CGRect, width: CGFloat, color: UInt32) {
    // Bildgrenzen rechnet CoreText relativ zur aktuellen Textposition
    ctx.textPosition = .zero
    let probe = CTLineGetImageBounds(line("nomi", font: CTFontCreateWithName(ps as CFString, 100, nil), color: color), ctx)
    let size = min(100 * width / probe.width, 100 * rect.height * 0.62 / probe.height)
    let l = line("nomi", font: CTFontCreateWithName(ps as CFString, size, nil), color: color)
    ctx.textPosition = .zero
    let b = CTLineGetImageBounds(l, ctx)
    ctx.textPosition = CGPoint(x: rect.midX - b.width / 2 - b.minX, y: rect.midY - b.height / 2 - b.minY)
    CTLineDraw(l, ctx)
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

text("Wortmarke: kalligrafische Schriften", font: "BricolageGrotesque96pt-ExtraBold", size: 44, color: ink, at: CGPoint(x: 30, y: CGFloat(H) - 76))
for (i, f) in fonts.enumerated() {
    let x = 30 + CGFloat(i % cols) * (tileW + gap)
    let top = CGFloat(H) - 120 - CGFloat(i / cols) * blockH
    text("\(i + 1) · \(f.name)", font: "BricolageGrotesque96pt-ExtraBold", size: 24, color: ink, at: CGPoint(x: x, y: top - 26))
    text(f.note, font: "DMSans-Regular", size: 15, color: inkMuted, at: CGPoint(x: x, y: top - 38), width: tileW)

    for (j, (bg, fg)) in [(brand, white), (canvas, brand)].enumerated() {
        let tile = CGRect(x: x, y: top - 92 - tileH - CGFloat(j) * (tileH + gap), width: tileW, height: tileH)
        ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 22, cornerHeight: 22, transform: nil))
        ctx.setFillColor(c(bg)); ctx.fillPath()
        if bg == canvas {
            ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 22, cornerHeight: 22, transform: nil))
            ctx.setStrokeColor(c(0xE6E1D8)); ctx.setLineWidth(1.5); ctx.strokePath()
        }
        wordmark(f.ps, in: tile, width: tileW * 0.62, color: fg)
    }

    // Kopfzeile in Originalgröße (ca. 28 pt Höhe @2x)
    let bar = CGRect(x: x, y: top - 92 - tileH * 2 - gap - 74, width: tileW, height: 58)
    ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.setFillColor(c(brand)); ctx.fillPath()
    ctx.saveGState()
    let logoArea = CGRect(x: bar.minX + 14, y: bar.minY + 8, width: 140, height: 42)
    wordmark(f.ps, in: logoArea, width: 86, color: white)
    ctx.restoreGState()
    ctx.setFillColor(c(white)); ctx.setAlpha(0.18)
    ctx.fillEllipse(in: CGRect(x: bar.maxX - 54, y: bar.midY - 18, width: 36, height: 36))
    ctx.setAlpha(1)
    text("KOPFZEILE", font: "DMMono-Regular", size: 12, color: inkMuted, at: CGPoint(x: bar.minX, y: bar.minY - 18))
}

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
