// Wortmarke „nomi“ in modernen Display-Schriften (Google Fonts, OFL), teils variabel mit eingestellter Stärke:
// groß auf Himbeere und Creme, dazu klein in Kopfzeilengröße.
// Aufruf: swift design/wordmark/render-display-wordmarks.swift <Ordner mit TTFs> Nomi/Resources/Fonts design/wordmark/display-vorschlaege.png
import AppKit
import CoreText

let candidates = URL(fileURLWithPath: CommandLine.arguments[1])
for dir in CommandLine.arguments[2...2] {
    for f in try! FileManager.default.contentsOfDirectory(at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil) where f.pathExtension == "ttf" {
        CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
    }
}

func c(_ h: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1)
}
let ink: UInt32 = 0x262B28, inkMuted: UInt32 = 0x6E726F, brand: UInt32 = 0xCC335E, canvas: UInt32 = 0xF7F4EE, white: UInt32 = 0xFFFFFF

/// Achsen variabler Schriften als OpenType-Tag
func tag(_ s: String) -> Int { s.unicodeScalars.reduce(0) { $0 << 8 | Int($1.value) } }

struct Candidate { let file: String; let axes: [String: Double]; let name: String; let note: String }
let fonts: [Candidate] = [
    Candidate(file: "Fraunces.ttf", axes: ["wght": 800, "SOFT": 100, "WONK": 1, "opsz": 144], name: "Fraunces Soft", note: "Weiche, leicht schräge Serif – warm, „Bäckerei & Bio“, sehr eigen."),
    Candidate(file: "YoungSerif.ttf", axes: [:], name: "Young Serif", note: "Freundliche, kräftige Serif mit Kochbuch-Charme."),
    Candidate(file: "Fredoka.ttf", axes: ["wght": 650], name: "Fredoka", note: "Rund und weich – freundlich, gut lesbar, passt zu Chefi."),
    Candidate(file: "DynaPuff.ttf", axes: ["wght": 650], name: "DynaPuff", note: "Puffig wie ein Knödel – verspielt, sehr sympathisch."),
    Candidate(file: "BagelFatOne.ttf", axes: [:], name: "Bagel Fat One", note: "Fett und knubbelig, Retro-Snack. Laut, aber lecker."),
    Candidate(file: "LilitaOne.ttf", axes: [:], name: "Lilita One", note: "Kompakt und plakativ, leicht verspielt."),
    Candidate(file: "Unbounded.ttf", axes: ["wght": 750], name: "Unbounded", note: "Breit, rund, modern – Tech-Startup-Gefühl."),
    Candidate(file: "Syne.ttf", axes: ["wght": 800], name: "Syne", note: "Avantgardistisch und eigenwillig, Design-Studio-Look."),
    Candidate(file: "Righteous.ttf", axes: [:], name: "Righteous", note: "Geometrisch mit Retro-Futur-Schwung."),
]

/// Schrift aus Datei, variable Achsen gesetzt
func makeFont(_ candidate: Candidate, size: CGFloat) -> CTFont {
    let url = candidates.appendingPathComponent(candidate.file) as CFURL
    let base = (CTFontManagerCreateFontDescriptorsFromURL(url) as! [CTFontDescriptor])[0]
    var attributes: [CFString: Any] = [:]
    if !candidate.axes.isEmpty {
        attributes[kCTFontVariationAttribute] = Dictionary(uniqueKeysWithValues: candidate.axes.map { (NSNumber(value: tag($0.key)), NSNumber(value: $0.value)) })
    }
    let descriptor = CTFontDescriptorCreateCopyWithAttributes(base, attributes as CFDictionary)
    return CTFontCreateWithFontDescriptor(descriptor, size, nil)
}

let cols = 3
let tileW: CGFloat = 480, tileH: CGFloat = 170, gap: CGFloat = 26
let blockH = 70 + tileH * 2 + gap + 74 + 60
let W = Int(CGFloat(cols) * (tileW + gap) + 60), H = Int(CGFloat((fonts.count + cols - 1) / cols) * blockH + 130)
let ctx = CGContext(data: nil, width: W, height: H, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(c(canvas)); ctx.fill(CGRect(x: 0, y: 0, width: W, height: H))

func line(_ s: String, font: CTFont, color: UInt32) -> CTLine {
    CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: [.font: font, .foregroundColor: c(color)]))
}

/// „nomi“ so groß, dass es `width` füllt, mittig in `rect`
func wordmark(_ candidate: Candidate, in rect: CGRect, width: CGFloat, color: UInt32) {
    // Bildgrenzen rechnet CoreText relativ zur aktuellen Textposition
    ctx.textPosition = .zero
    let probe = CTLineGetImageBounds(line("nomi", font: makeFont(candidate, size: 100), color: color), ctx)
    let size = min(100 * width / probe.width, 100 * rect.height * 0.62 / probe.height)
    let l = line("nomi", font: makeFont(candidate, size: size), color: color)
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

text("Wortmarke: moderne Display-Schriften", font: "BricolageGrotesque96pt-ExtraBold", size: 44, color: ink, at: CGPoint(x: 30, y: CGFloat(H) - 76))
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
        wordmark(f, in: tile, width: tileW * 0.62, color: fg)
    }

    // Kopfzeile in Originalgröße (ca. 28 pt Höhe @2x)
    let bar = CGRect(x: x, y: top - 92 - tileH * 2 - gap - 74, width: tileW, height: 58)
    ctx.addPath(CGPath(roundedRect: bar, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.setFillColor(c(brand)); ctx.fillPath()
    ctx.saveGState()
    let logoArea = CGRect(x: bar.minX + 14, y: bar.minY + 8, width: 140, height: 42)
    wordmark(f, in: logoArea, width: 86, color: white)
    ctx.restoreGState()
    ctx.setFillColor(c(white)); ctx.setAlpha(0.18)
    ctx.fillEllipse(in: CGRect(x: bar.maxX - 54, y: bar.midY - 18, width: 36, height: 36))
    ctx.setAlpha(1)
    text("KOPFZEILE", font: "DMMono-Regular", size: 12, color: inkMuted, at: CGPoint(x: bar.minX, y: bar.minY - 18))
}

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[3]))
