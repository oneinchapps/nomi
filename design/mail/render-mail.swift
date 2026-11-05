// Rendert die Entwürfe der Anmelde-Mail so, wie sie auf einem iPhone (390 pt breit) erscheinen.
// - assets/: Wortmarke (hell und auf Himbeere) als PNG aus den PDFs der App, Chefi aus design/mascot
// - vorschlaege.png: die Entwürfe nebeneinander
// Aufruf (im Repo-Ordner): swift design/mail/render-mail.swift
// Eine fertige Mail (z. B. aus Mailpit) als PNG: swift design/mail/render-mail.swift --einzeln mail.html mail.png
import AppKit
import CoreText
import WebKit

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let mailDir = root.appendingPathComponent("design/mail")
let assets = mailDir.appendingPathComponent("assets")
let fontDir = root.appendingPathComponent("Nomi/Resources/Fonts")
try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)
for f in try! FileManager.default.contentsOfDirectory(at: fontDir, includingPropertiesForKeys: nil) {
    CTFontManagerRegisterFontsForURL(f as CFURL, .process, nil)
}

func c(_ h: UInt32) -> CGColor {
    CGColor(srgbRed: CGFloat(h >> 16 & 255) / 255, green: CGFloat(h >> 8 & 255) / 255, blue: CGFloat(h & 255) / 255, alpha: 1)
}

func writePNG(_ image: CGImage, _ url: URL) {
    try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: url)
}

// MARK: - Bilder für die Mail

/// PDF der App als PNG mit fester Breite in Pixeln, transparent
func rasterize(_ pdf: URL, width: Int, to out: URL) {
    let page = CGPDFDocument(pdf as CFURL)!.page(at: 1)!
    let box = page.getBoxRect(.mediaBox)
    let scale = CGFloat(width) / box.width
    let ctx = CGContext(data: nil, width: width, height: Int((box.height * scale).rounded()), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: scale, y: scale)
    ctx.translateBy(x: -box.minX, y: -box.minY)
    ctx.drawPDFPage(page)
    writePNG(ctx.makeImage()!, out)
}

let xcassets = root.appendingPathComponent("Nomi/Resources/Assets.xcassets")
rasterize(xcassets.appendingPathComponent("Wordmark.imageset/wordmark.pdf"), width: 360, to: assets.appendingPathComponent("wordmark.png"))
rasterize(xcassets.appendingPathComponent("WordmarkOnLight.imageset/wordmark.pdf"), width: 360, to: assets.appendingPathComponent("wordmark-on-light.png"))
let chefi = assets.appendingPathComponent("chefi.png")
try? FileManager.default.removeItem(at: chefi)
try! FileManager.default.copyItem(at: root.appendingPathComponent("design/mascot/chefi-winkt.png"), to: chefi)

// MARK: - Entwürfe rendern

let drafts: [(file: String, title: String, note: String)] = [
    ("entwurf-a.html", "A · Himbeer-Kopf", "wie die Köpfe in der App, Chefi winkt rechts"),
    ("entwurf-b.html", "B · Chefi in der Mitte", "freundlich, Code als Himbeer-Pille"),
    ("entwurf-c.html", "C · Ruhig", "nur Wortmarke, Code in Himbeere"),
]

// Vorschau lädt die Schriften der App; die echte Mail bindet sie über Google Fonts ein
let fontFaces = [("Bricolage Grotesque", "BricolageGrotesque-ExtraBold.ttf", 800), ("DM Sans", "DMSans-Regular.ttf", 400),
                 ("DM Mono", "DMMono-Regular.ttf", 400), ("DM Mono", "DMMono-Medium.ttf", 500)]
    .map { "@font-face { font-family: '\($0.0)'; font-weight: \($0.2); src: url('\(fontDir.appendingPathComponent($0.1).absoluteString)'); }" }
    .joined(separator: "\n")

final class Renderer: NSObject, WKNavigationDelegate {
    let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 800))
    let window = NSWindow(contentRect: CGRect(x: -3000, y: 0, width: 390, height: 800), styleMask: [.borderless], backing: .buffered, defer: false)
    var done: ((NSImage) -> Void)?

    override init() {
        super.init()
        window.contentView = web
        web.navigationDelegate = self
    }

    func render(_ file: URL, _ completion: @escaping (NSImage) -> Void) {
        done = completion
        // Entwürfe brauchen die Schriften aus dem Repo, einzelne Mails nur ihren eigenen Ordner
        web.loadFileURL(file, allowingReadAccessTo: file.path.hasPrefix(root.path) ? root : file.deletingLastPathComponent())
    }

    // Ohne diese Meldung bliebe das Skript bei einem Ladefehler einfach hängen
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { fail(error) }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { fail(error) }
    func fail(_ error: Error) {
        FileHandle.standardError.write("Laden fehlgeschlagen: \(error.localizedDescription)\n".data(using: .utf8)!)
        exit(1)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        // Kurz warten, bis Schriften und Bilder da sind
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            webView.evaluateJavaScript("document.documentElement.scrollHeight") { height, _ in
                let h = max(CGFloat((height as? NSNumber)?.doubleValue ?? 800), 760)
                self.window.setContentSize(CGSize(width: 390, height: h))
                webView.frame = CGRect(x: 0, y: 0, width: 390, height: h)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    let config = WKSnapshotConfiguration()
                    config.rect = CGRect(x: 0, y: 0, width: 390, height: h)
                    config.snapshotWidth = 390
                    webView.takeSnapshot(with: config) { image, _ in self.done?(image!) }
                }
            }
        }
    }
}

let app = NSApplication.shared
let renderer = Renderer()
var shots: [NSImage] = []
let preview = mailDir.appendingPathComponent(".vorschau.html")

/// --einzeln <html> <png>: rendert eine vollständige Mail ohne Bogen, mit den echten Schriften aus dem Netz
let single = CommandLine.arguments.count == 4 && CommandLine.arguments[1] == "--einzeln"
    ? (URL(fileURLWithPath: CommandLine.arguments[2]), URL(fileURLWithPath: CommandLine.arguments[3])) : nil

func next() {
    if let (input, output) = single {
        renderer.render(input) { image in
            let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil)!
            writePNG(cg, output)
            exit(0)
        }
        return
    }
    guard shots.count < drafts.count else { compose(); exit(0) }
    let body = try! String(contentsOf: mailDir.appendingPathComponent(drafts[shots.count].file), encoding: .utf8)
        .replacingOccurrences(of: "{{ .Token }}", with: "482913")
    let html = """
    <!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width">
    <style>\(fontFaces)\nbody { margin: 0; background: #F7F4EE; }</style></head><body>\(body)</body></html>
    """
    try! html.write(to: preview, atomically: true, encoding: .utf8)
    renderer.render(preview) { image in
        shots.append(image)
        next()
    }
}

// MARK: - Bogen

func compose() {
    try? FileManager.default.removeItem(at: preview)
    let s: CGFloat = 2, phoneW: CGFloat = 390, gap: CGFloat = 60, margin: CGFloat = 60
    let phoneH = shots.map(\.size.height).max()! + 60
    let width = Int((margin * 2 + phoneW * 3 + gap * 2) * s)
    let height = Int((phoneH + 200) * s)
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    ctx.scaleBy(x: s, y: s)
    ctx.setFillColor(c(0xE9E4DA)); ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

    func text(_ str: String, _ font: String, _ size: CGFloat, _ color: UInt32, _ x: CGFloat, _ y: CGFloat) {
        let f = CTFontCreateWithName(font as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: str, attributes: [.font: f, .foregroundColor: c(color)]))
        ctx.textPosition = CGPoint(x: x, y: y); CTLineDraw(line, ctx)
    }

    let top = CGFloat(height) / s
    text("Anmelde-Mail im Stil von nomi", "BricolageGrotesque96pt-ExtraBold", 34, 0x262B28, margin, top - 70)
    text("Betreff: „Dein nomi-Code“ · so sieht es in Apple Mail auf dem iPhone aus", "DMSans-Regular", 17, 0x6E726F, margin, top - 100)

    for (i, shot) in shots.enumerated() {
        let x = margin + CGFloat(i) * (phoneW + gap)
        let frame = CGRect(x: x, y: 60, width: phoneW, height: phoneH)
        // Mail-Kopf wie in Apple Mail, darunter der Inhalt
        ctx.saveGState()
        ctx.addPath(CGPath(roundedRect: frame, cornerWidth: 28, cornerHeight: 28, transform: nil)); ctx.clip()
        ctx.setFillColor(c(0xF7F4EE)); ctx.fill(frame)
        ctx.setFillColor(c(0xFFFFFF)); ctx.fill(CGRect(x: x, y: frame.maxY - 60, width: phoneW, height: 60))
        text("nomi", "DMSans-SemiBold", 15, 0x262B28, x + 18, frame.maxY - 26)
        text("Dein nomi-Code", "DMSans-Regular", 14, 0x6E726F, x + 18, frame.maxY - 46)
        let cg = shot.cgImage(forProposedRect: nil, context: nil, hints: nil)!
        ctx.draw(cg, in: CGRect(x: x, y: frame.maxY - 60 - shot.size.height, width: phoneW, height: shot.size.height))
        ctx.restoreGState()
        ctx.addPath(CGPath(roundedRect: frame, cornerWidth: 28, cornerHeight: 28, transform: nil))
        ctx.setStrokeColor(c(0xD6D0C4)); ctx.setLineWidth(1); ctx.strokePath()
        text(drafts[i].title, "BricolageGrotesque96pt-ExtraBold", 22, 0x262B28, x, 30)
        text(drafts[i].note, "DMSans-Regular", 15, 0x6E726F, x, 10)
    }
    writePNG(ctx.makeImage()!, mailDir.appendingPathComponent("vorschlaege.png"))
}

app.setActivationPolicy(.prohibited)
DispatchQueue.main.async { next() }
app.run()
