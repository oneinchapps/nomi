// App-Icon: Wortmarke „nomi“ in Weiß auf Himbeere.
// swift design/render-app-icon.swift <BricolageGrotesque-ExtraBold.ttf> <AppIcon.png>
import AppKit
import CoreText
CTFontManagerRegisterFontsForURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, .process, nil)
let size = 1024
let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
ctx.setFillColor(CGColor(srgbRed: 0xCC/255, green: 0x33/255, blue: 0x5E/255, alpha: 1))
ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))

func line(fontSize: CGFloat) -> (CTLine, CTFont) {
    let font = CTFontCreateWithName("BricolageGrotesque96pt-ExtraBold" as CFString, fontSize, nil)
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: "nomi", attributes: [
        .font: font, .foregroundColor: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1), .kern: -0.045 * fontSize,
    ]))
    return (line, font)
}

// Schriftgröße so wählen, dass die Wortmarke 76 % der Breite füllt
let reference = line(fontSize: 100)
let referenceWidth = CTLineGetImageBounds(reference.0, ctx).width
let (word, font) = line(fontSize: 100 * 0.76 * CGFloat(size) / referenceWidth)
let bounds = CTLineGetImageBounds(word, ctx)
// Optisch zentriert auf der x-Höhe; der i-Punkt ragt darüber hinaus
let xHeight = CTFontGetXHeight(font)
ctx.textPosition = CGPoint(x: (CGFloat(size) - bounds.width) / 2 - bounds.minX, y: (CGFloat(size) - xHeight) / 2 - 20)
CTLineDraw(word, ctx)

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
