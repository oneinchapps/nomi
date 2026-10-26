// Tab-Symbol für nomi: Chefis Kochmütze als Silhouette (Vorlagenbild, iOS färbt es ein).
// Aufruf: swift design/mascot/render-tab-icon.swift Nomi/Resources/Assets.xcassets/TabNomi.imageset
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments[1])
for scale in [1, 2, 3] {
    let size = 25 * scale
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    // Raster 100 × 100, Ursprung unten links
    ctx.scaleBy(x: CGFloat(size) / 100, y: CGFloat(size) / 100)
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    for (x, y, r) in [(29.0, 58.0, 19.0), (71.0, 58.0, 19.0), (50.0, 70.0, 23.0)] {
        ctx.fillEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
    }
    ctx.addPath(CGPath(roundedRect: CGRect(x: 22, y: 10, width: 56, height: 28), cornerWidth: 6, cornerHeight: 6, transform: nil))
    ctx.fillPath()
    // Spalt zwischen Band und Mütze
    ctx.setBlendMode(.clear)
    ctx.fill(CGRect(x: 0, y: 38, width: 100, height: 6))
    let name = scale == 1 ? "tab-nomi.png" : "tab-nomi@\(scale)x.png"
    try! NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
        .write(to: out.appendingPathComponent(name))
}
