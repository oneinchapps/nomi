// Tab-Symbole im Stil „Eigene Linie“ (Vorschlag B) als Vorlagenbilder für das Asset-Katalog.
// Pro Tab zwei Varianten: inaktiv nur Linie, aktiv mit gefüllten Akzenten. iOS färbt beide ein.
// Aufruf: swift design/tabbar/render-tab-assets.swift Nomi/Resources/Assets.xcassets design/tabbar/final.png
import AppKit

let assets = URL(fileURLWithPath: CommandLine.arguments[1])
let previewURL = URL(fileURLWithPath: CommandLine.arguments[2])

// MARK: - Formen (Raster 24 × 24, Ursprung unten links)

func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r), transform: nil) }
func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath { CGPath(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h), transform: nil) }
func rrect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
    CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: r, cornerHeight: r, transform: nil)
}
func line(_ pts: (CGFloat, CGFloat)...) -> CGPath {
    let p = CGMutablePath(); p.move(to: CGPoint(x: pts[0].0, y: pts[0].1))
    for pt in pts.dropFirst() { p.addLine(to: CGPoint(x: pt.0, y: pt.1)) }
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
    p.addQuadCurve(to: CGPoint(x: len, y: 0), control: CGPoint(x: len / 2, y: len * 0.45))
    p.addQuadCurve(to: .zero, control: CGPoint(x: len / 2, y: -len * 0.45))
    var t = CGAffineTransform(translationX: x, y: y).rotated(by: deg * .pi / 180)
    return p.copy(using: &t)!
}

let stroke: CGFloat = 1.75

/// Zeichnet ein Tab-Symbol in Schwarz (Vorlage) – `active` füllt die Akzente.
func draw(_ name: String, active: Bool, in ctx: CGContext) {
    ctx.setLineCap(.round); ctx.setLineJoin(.round); ctx.setLineWidth(stroke)
    let black = CGColor(gray: 0, alpha: 1)
    ctx.setStrokeColor(black); ctx.setFillColor(black)
    func strokePath(_ p: CGPath) { ctx.addPath(p); ctx.strokePath() }
    func fill(_ p: CGPath, _ alpha: CGFloat = 1) { ctx.setFillColor(CGColor(gray: 0, alpha: alpha)); ctx.addPath(p); ctx.fillPath(); ctx.setFillColor(black) }
    func clear(_ p: CGPath) { ctx.setBlendMode(.clear); ctx.addPath(p); ctx.fillPath(); ctx.setBlendMode(.normal) }

    switch name {
    case "Nomi":
        // Chefi: großes rundes Gesicht, kleine Mütze obendrauf – das Gesicht muss auch in 25 pt lesbar sein
        let head = circle(12, 9.6, 8.6)
        let puffs = [circle(9.5, 20.6, 2.3), circle(12, 21.7, 2.5), circle(14.5, 20.6, 2.3), rrect(9.2, 18.4, 5.6, 2.6, 0.8)]
        let hat = puffs.dropFirst().reduce(puffs[0]) { $0.union($1) }
        let band = rrect(8.4, 16.6, 7.2, 2.5, 1)
        if active { fill(head, 0.2) }
        strokePath(head)
        clear(hat.copy(strokingWithWidth: stroke, lineCap: .round, lineJoin: .round, miterLimit: 1).union(hat))
        strokePath(hat)
        clear(band.copy(strokingWithWidth: stroke, lineCap: .round, lineJoin: .round, miterLimit: 1).union(band))
        if active { fill(band) } else { strokePath(band) }
        // Gesicht: große Augen, breites Lächeln
        fill(circle(8.8, 10.4, 1.55)); fill(circle(15.2, 10.4, 1.55))
        let smile = CGMutablePath()
        smile.addArc(center: CGPoint(x: 12, y: 8.4), radius: 3.3, startAngle: -0.3, endAngle: -.pi + 0.3, clockwise: true)
        strokePath(smile)
        if active { fill(ellipse(6.4, 7.4, 2.6, 1.7), 0.7); fill(ellipse(17.6, 7.4, 2.6, 1.7), 0.7) }
    case "Today":
        // Pfanne schräg von der Seite: Rand als Ellipse, gewölbter Boden, langer Stiel
        let rim = ellipse(9.6, 12.4, 15.6, 5.6)
        let bowl = CGMutablePath()
        bowl.move(to: CGPoint(x: 1.8, y: 12.4))
        bowl.addCurve(to: CGPoint(x: 9.6, y: 5.2), control1: CGPoint(x: 2.2, y: 8.2), control2: CGPoint(x: 5.6, y: 5.2))
        bowl.addCurve(to: CGPoint(x: 17.4, y: 12.4), control1: CGPoint(x: 13.6, y: 5.2), control2: CGPoint(x: 17, y: 8.2))
        if active { fill(rim.union(bowl), 0.2) }
        strokePath(bowl)
        strokePath(rim)
        ctx.setLineWidth(2.6); strokePath(line((17.9, 13.4), (22.6, 15.6))); ctx.setLineWidth(stroke)
        if active {
            fill(ellipse(9.2, 12.6, 6.6, 2.6), 0.55)
            fill(ellipse(9.6, 12.8, 2.6, 1.6))
        }
    case "Recipes":
        let card = rrect(5, 2.6, 14, 18.8, 3.2)
        if active { fill(card, 0.2) }
        strokePath(card)
        strokePath(line((8.5, 10.4), (15.5, 10.4)))
        strokePath(line((8.5, 6.9), (13.5, 6.9)))
        let h = heart(12, 15.6, 2.6)
        if active { fill(h) } else { strokePath(h) }
    case "Shopping":
        let body = CGMutablePath()
        body.move(to: CGPoint(x: 6.2, y: 14.2))
        body.addLine(to: CGPoint(x: 17.8, y: 14.2))
        body.addLine(to: CGPoint(x: 19, y: 4.4))
        body.addQuadCurve(to: CGPoint(x: 17.5, y: 2.8), control: CGPoint(x: 19.2, y: 2.8))
        body.addLine(to: CGPoint(x: 6.5, y: 2.8))
        body.addQuadCurve(to: CGPoint(x: 5, y: 4.4), control: CGPoint(x: 4.8, y: 2.8))
        body.closeSubpath()
        let handle = CGMutablePath()
        handle.addArc(center: CGPoint(x: 10.6, y: 14.2), radius: 3.2, startAngle: .pi, endAngle: 0, clockwise: true)
        let sprig = leaf(15.6, 14.4, 6.6, deg: 68)
        if active { fill(body, 0.2) }
        strokePath(body)
        strokePath(handle)
        if active { fill(sprig) } else { strokePath(sprig) }
    default: // Week
        let cal = rrect(3.5, 3.2, 17, 15.8, 3.4)
        if active { fill(cal, 0.2) }
        strokePath(cal)
        strokePath(line((3.5, 14.6), (20.5, 14.6)))
        strokePath(line((8, 17.2), (8, 21)))
        strokePath(line((16, 17.2), (16, 21)))
        for (x, y) in [(8.2, 11), (12, 11), (15.8, 11), (8.2, 7.1), (12, 7.1)] as [(CGFloat, CGFloat)] { fill(circle(x, y, 1.1)) }
        let today = circle(15.8, 7.1, 2.1)
        if active { fill(today) } else { strokePath(circle(15.8, 7.1, 1.9)) }
    }
}

// MARK: - Assets (25 pt, @1x–@3x)

let names = ["Nomi", "Today", "Recipes", "Shopping", "Week"]
for name in names {
    for active in [false, true] {
        let asset = "Tab\(name)\(active ? "Active" : "")"
        let dir = assets.appendingPathComponent("\(asset).imageset")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var images: [String] = []
        for scale in [1, 2, 3] {
            let px = 25 * scale
            let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            ctx.scaleBy(x: CGFloat(px) / 24, y: CGFloat(px) / 24)
            draw(name, active: active, in: ctx)
            let file = scale == 1 ? "\(asset).png" : "\(asset)@\(scale)x.png"
            try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!.write(to: dir.appendingPathComponent(file))
            images.append(#"    { "filename" : "\#(file)", "idiom" : "universal", "scale" : "\#(scale)x" }"#)
        }
        let contents = """
        {
          "images" : [
        \(images.joined(separator: ",\n"))
          ],
          "info" : { "author" : "xcode", "version" : 1 },
          "properties" : { "template-rendering-intent" : "template" }
        }

        """
        try! contents.write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
    }
}

// MARK: - Vorschau: groß, inaktiv und aktiv, hell und dunkel

let cell: CGFloat = 150
let preview = CGContext(data: nil, width: Int(cell * 5), height: Int(cell * 4), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let rows: [(active: Bool, dark: Bool)] = [(false, false), (true, false), (false, true), (true, true)]
for (row, mode) in rows.enumerated() {
    let y = CGFloat(rows.count - 1 - row) * cell
    preview.setFillColor(mode.dark ? CGColor(srgbRed: 0.09, green: 0.09, blue: 0.09, alpha: 1) : CGColor(srgbRed: 0.97, green: 0.96, blue: 0.93, alpha: 1))
    preview.fill(CGRect(x: 0, y: y, width: cell * 5, height: cell))
    for (col, name) in names.enumerated() {
        // Vorlage zeichnen, dann einfärben wie iOS
        let layer = CGContext(data: nil, width: 96, height: 96, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        layer.scaleBy(x: 4, y: 4)
        draw(name, active: mode.active, in: layer)
        let mask = layer.makeImage()!
        let rect = CGRect(x: CGFloat(col) * cell + 27, y: y + 27, width: 96, height: 96)
        preview.saveGState()
        preview.clip(to: rect, mask: mask)
        let tint = mode.active
            ? (mode.dark ? CGColor(srgbRed: 0.88, green: 0.35, blue: 0.49, alpha: 1) : CGColor(srgbRed: 0.8, green: 0.2, blue: 0.37, alpha: 1))
            : (mode.dark ? CGColor(srgbRed: 0.95, green: 0.94, blue: 0.91, alpha: 1) : CGColor(srgbRed: 0.15, green: 0.17, blue: 0.16, alpha: 1))
        preview.setFillColor(tint); preview.fill(rect)
        preview.restoreGState()
    }
}
// Originalgröße: so groß erscheint das Symbol in der Tab-Leiste (25 pt @3x = 75 px)
for (row, mode) in rows.enumerated() where !mode.dark {
    let y = CGFloat(rows.count - 1 - row) * cell
    for (col, name) in names.enumerated() {
        let layer = CGContext(data: nil, width: 75, height: 75, bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        layer.scaleBy(x: 75 / 24, y: 75 / 24)
        draw(name, active: mode.active, in: layer)
        let rect = CGRect(x: CGFloat(col) * cell + 112, y: y + 8, width: 32, height: 32)
        preview.saveGState()
        preview.clip(to: rect, mask: layer.makeImage()!)
        preview.setFillColor(mode.active ? CGColor(srgbRed: 0.8, green: 0.2, blue: 0.37, alpha: 1) : CGColor(srgbRed: 0.15, green: 0.17, blue: 0.16, alpha: 1))
        preview.fill(rect)
        preview.restoreGState()
    }
}
try! NSBitmapImageRep(cgImage: preview.makeImage()!).representation(using: .png, properties: [:])!.write(to: previewURL)
