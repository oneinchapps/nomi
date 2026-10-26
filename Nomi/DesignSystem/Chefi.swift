import SwiftUI

/// nomis Maskottchen: kleiner Koch in Mint mit Kochmütze und Holzlöffel.
///
/// Gezeichnet wie in design/mascot/render-mascots.swift (Raster 200 × 230, Ursprung unten links),
/// damit Entwurf und App übereinstimmen. Die Farben sind fest – Chefi steht immer auf Himbeere
/// und sieht im Dark Mode genauso aus.
struct ChefiView: View, Animatable {
    /// Neigung des Löffels im Bogenmaß, negativ = nach außen
    var spoonTilt: CGFloat = -0.32
    /// Löffel samt Pfote anheben (Rasterpunkte)
    var spoonLift: CGFloat = 0
    var winks = false
    /// Linke Pfote winkt neben dem Kopf statt am Bauch zu liegen
    var waves = false

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(spoonTilt, spoonLift) }
        set { (spoonTilt, spoonLift) = (newValue.first, newValue.second) }
    }

    static let aspectRatio: CGFloat = 200 / 230

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width / 200, size.height / 230)
            context.translateBy(x: (size.width - 200 * scale) / 2, y: (size.height + 230 * scale) / 2)
            context.scaleBy(x: scale, y: -scale)
            ChefiDrawing(context: context, pose: self).draw()
        }
        .aspectRatio(Self.aspectRatio, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

private enum ChefiColor {
    static let ink = Color(red: 0x26 / 255, green: 0x2B / 255, blue: 0x28 / 255)
    static let body = Color(red: 0xD3 / 255, green: 0xE9 / 255, blue: 0xC8 / 255)
    static let belly = Color(red: 0xFF / 255, green: 0xF6 / 255, blue: 0xE8 / 255)
    static let wood = Color(red: 0xE2 / 255, green: 0xA6 / 255, blue: 0x5A / 255)
    static let band = Color(red: 0xCC / 255, green: 0x33 / 255, blue: 0x5E / 255)
    static let blush = Color(red: 0xF4 / 255, green: 0xA0 / 255, blue: 0xB5 / 255)
    static let mouth = Color(red: 0x8E / 255, green: 0x1F / 255, blue: 0x3E / 255)
    static let tongue = Color(red: 0xF2 / 255, green: 0x8C / 255, blue: 0xA6 / 255)
}

/// Die eigentliche Zeichnung im y-oben-Raster; Reihenfolge = von hinten nach vorne.
private struct ChefiDrawing {
    let context: GraphicsContext
    let pose: ChefiView

    private let cx: CGFloat = 100, b: CGFloat = 16, w: CGFloat = 130, h: CGFloat = 132

    func draw() {
        for side in [-1.0, 1.0] as [CGFloat] { shape(ellipse(cx + side * 30, b + 2, 34, 18), ChefiColor.body) }
        shape(bean(), ChefiColor.body)
        shape(ellipse(cx, b + h * 0.3, w * 0.62, h * 0.42), ChefiColor.belly)

        if pose.waves {
            for (dx, dy) in [(-12.0, 4.0), (-10.0, 14.0)] as [(CGFloat, CGFloat)] {
                line(curve(cx - 66 + dx, b + 96 + dy, cx - 72 + dx, b + 102 + dy, cx - 70 + dx, b + 110 + dy), width: 3)
            }
            paw(cx - 56, b + 96)
        } else {
            paw(cx - 50, b + 50)
        }

        let hold = CGAffineTransform(translationX: cx + 40, y: b + 20 + pose.spoonLift).rotated(by: pose.spoonTilt)
        shape(Path(roundedRect: CGRect(x: -4.5, y: 0, width: 9, height: 78), cornerRadius: 4.5).applying(hold), ChefiColor.wood)
        shape(ellipse(0, 92, 26, 34).applying(hold), ChefiColor.wood)
        line(curve(-6, 84, 0, 80, 6, 84).applying(hold), width: 3)
        let hand = CGPoint(x: 0, y: 34).applying(hold)
        paw(hand.x, hand.y)

        let top = b + h - 8
        for (x, y, r) in [(cx - 24, top + 30, 20.0), (cx + 24, top + 30, 20.0), (cx, top + 42, 24.0)] as [(CGFloat, CGFloat, CGFloat)] {
            shape(ellipse(x, y, 2 * r, 2 * r), .white)
        }
        shape(Path(roundedRect: CGRect(x: cx - 34, y: top, width: 68, height: 22), cornerRadius: 6), ChefiColor.band)

        face(eyeY: b + h * 0.62)
    }

    private func face(eyeY: CGFloat) {
        let spacing: CGFloat = 18
        for side in [-1.0, 1.0] as [CGFloat] {
            let x = cx + side * spacing
            if pose.winks && side > 0 {
                line(curve(x - 5.5, eyeY - 1.5, x, eyeY + 5, x + 5.5, eyeY - 1.5), width: 3.5)
            } else {
                fill(ellipse(x, eyeY, 10.4, 10.4), ChefiColor.ink)
                fill(ellipse(x + 1.6, eyeY + 1.9, 3.4, 3.4), .white)
            }
            fill(ellipse(cx + side * spacing * 1.75, eyeY - 9, 15, 9), ChefiColor.blush)
        }
        let top = eyeY - 4, r: CGFloat = 10
        var mouth = Path()
        mouth.move(to: CGPoint(x: cx - r, y: top))
        mouth.addLine(to: CGPoint(x: cx + r, y: top))
        mouth.addArc(center: CGPoint(x: cx, y: top), radius: r, startAngle: .zero, endAngle: .radians(.pi), clockwise: true)
        mouth.closeSubpath()
        fill(mouth, ChefiColor.mouth)
        var inner = context
        inner.clip(to: mouth)
        inner.fill(ellipse(cx + 1, top - r * 0.95, r * 1.3, r * 0.9), with: .color(ChefiColor.tongue))
        line(mouth, width: 3.5)
    }

    private func paw(_ x: CGFloat, _ y: CGFloat) {
        shape(ellipse(x, y, 22, 18), ChefiColor.body)
        line(curve(x - 5, y + 3, x, y - 1, x + 5, y + 3), width: 2.5)
    }

    // MARK: Formen

    private func bean() -> Path {
        var p = Path()
        p.move(to: CGPoint(x: cx, y: b))
        p.addCurve(to: CGPoint(x: cx + w / 2, y: b + h * 0.38), control1: CGPoint(x: cx + w * 0.42, y: b), control2: CGPoint(x: cx + w / 2, y: b + h * 0.12))
        p.addCurve(to: CGPoint(x: cx, y: b + h), control1: CGPoint(x: cx + w / 2, y: b + h * 0.78), control2: CGPoint(x: cx + w * 0.34, y: b + h))
        p.addCurve(to: CGPoint(x: cx - w / 2, y: b + h * 0.38), control1: CGPoint(x: cx - w * 0.34, y: b + h), control2: CGPoint(x: cx - w / 2, y: b + h * 0.78))
        p.addCurve(to: CGPoint(x: cx, y: b), control1: CGPoint(x: cx - w / 2, y: b + h * 0.12), control2: CGPoint(x: cx - w * 0.42, y: b))
        p.closeSubpath()
        return p
    }

    private func ellipse(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x - width / 2, y: y - height / 2, width: width, height: height))
    }

    private func curve(_ x0: CGFloat, _ y0: CGFloat, _ cx: CGFloat, _ cy: CGFloat, _ x1: CGFloat, _ y1: CGFloat) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: x0, y: y0))
        p.addQuadCurve(to: CGPoint(x: x1, y: y1), control: CGPoint(x: cx, y: cy))
        return p
    }

    // MARK: Malen

    private func shape(_ path: Path, _ color: Color) {
        fill(path, color)
        line(path, width: 4.5)
    }

    private func fill(_ path: Path, _ color: Color) {
        context.fill(path, with: .color(color))
    }

    private func line(_ path: Path, width: CGFloat) {
        context.stroke(path, with: .color(ChefiColor.ink), style: StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
    }
}

#Preview {
    HStack {
        ChefiView()
        ChefiView(spoonTilt: -0.08, spoonLift: 20, winks: true)
        ChefiView(waves: true)
    }
    .padding()
    .background(Color.brand)
}
