import AppKit
import CoreText
CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, .process, nil)
let size = 1024
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(CGColor(srgbRed: 0xCC/255, green: 0x33/255, blue: 0x5E/255, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
let font = CTFontCreateWithName("BricolageGrotesque96pt-ExtraBold" as CFString, 410, nil)
for baseline in [571.0, 237.0] {
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "nom", attributes: [
        .font: font, .foregroundColor: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), .kern: -18,
    ]))
    let width = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    ctx.textPosition = CGPoint(x: (CGFloat(size) - width) / 2 - 10, y: baseline)
    CTLineDraw(line, ctx)
}
let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
