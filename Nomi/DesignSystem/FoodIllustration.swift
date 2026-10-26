import SwiftUI

/// nomis Illustrationen im Stil „Linie“: feine Tintenzeichnung, Flächen in der Hintergrundfarbe
/// (damit sich Formen überdecken), ein Akzent in Himbeere. Alles Vektor – scharf in jeder Größe,
/// Tinte wird im Dark Mode automatisch hell.
///
/// Motive sind in einem 200×200-Raster mit Ursprung **unten links** beschrieben (wie in
/// design/illustrations/render-styles.swift), damit Entwurf und App dieselben Koordinaten nutzen.
enum FoodMotif: String, CaseIterable, Sendable {
    case teller, suppe, nudeln, fisch, steak, keule, salat, burger, pizza, bowl, spiegelei,
         brot, eis, muffin, kuchen, glas, knoedel, auflauf, pfannkuchen, kuerbis, gemuese, spiess, taco

    /// Pastellton für Flächen ohne Foto
    var tint: Color {
        let (light, dark): (UInt32, UInt32) = switch self {
        case .suppe, .kuerbis, .knoedel, .auflauf: (0xF6DCC2, 0x3A2F24)
        case .nudeln, .taco, .brot, .pfannkuchen, .spiegelei, .burger: (0xF9E7B8, 0x3A3320)
        case .fisch, .glas, .teller: (0xDCE6EA, 0x1D282C)
        case .kuchen, .eis, .muffin, .steak: (0xF6D5DD, 0x3B2229)
        case .salat, .gemuese, .bowl, .spiess: (0xDCEBD5, 0x253222)
        case .keule, .pizza: (0xF3D2C7, 0x3B2622)
        }
        return Color(light: light, dark: dark)
    }

    fileprivate var parts: [IllustrationPart] { Motifs.parts(for: self) }
}

struct FoodIllustration: View {
    let motif: FoodMotif
    /// Fläche hinter der Zeichnung – Formen werden damit gefüllt, damit sie sich überdecken
    var background: Color?

    var body: some View {
        IllustrationCanvas(parts: motif.parts, fill: background ?? motif.tint)
    }
}

/// Momente statt Gerichte (Match, Warten, Guten Appetit …) – ersetzt die Reaktions-Emojis.
enum Reaction: String, CaseIterable, Sendable {
    case jubel, warten, lecker, korb, ratlos

    /// Füllung der Flächen; die Zeichnungen stehen frei auf dem Creme-Grund
    var tint: Color {
        switch self {
        case .jubel, .korb: FoodMotif.nudeln.tint
        case .warten, .ratlos: FoodMotif.teller.tint
        case .lecker: FoodMotif.suppe.tint
        }
    }

    fileprivate var parts: [IllustrationPart] { Motifs.parts(for: self) }
}

struct ReactionIllustration: View {
    let reaction: Reaction

    var body: some View {
        IllustrationCanvas(parts: reaction.parts, fill: reaction.tint)
    }
}

fileprivate struct IllustrationCanvas: View {
    let parts: [IllustrationPart]
    let fill: Color

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 200
            context.translateBy(x: (size.width - 200 * scale) / 2, y: (size.height - 200 * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            let stroke = StrokeStyle(lineWidth: 4.5, lineCap: .round, lineJoin: .round)
            for part in parts {
                switch part.role {
                case .fill:
                    context.fill(part.path, with: .color(fill))
                    context.stroke(part.path, with: .color(.ink), style: stroke)
                case .accent:
                    context.fill(part.path, with: .color(.brand))
                    context.stroke(part.path, with: .color(.ink), style: stroke)
                case .soft:
                    context.fill(part.path, with: .color(Color(light: 0xF2B33D, dark: 0xC99230)))
                    context.stroke(part.path, with: .color(.ink), style: stroke)
                case .dot:
                    context.fill(part.path, with: .color(.ink))
                case .line:
                    context.stroke(part.path, with: .color(.ink), style: stroke)
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// Illustration auf ihrer Pastellfläche – Ersatz für die bisherigen Emoji-Platzhalter.
struct IllustrationTile: View {
    let motif: FoodMotif
    var tint: Color?
    /// Anteil der Kachel, den die Zeichnung einnimmt
    var scale: CGFloat = 0.62

    var body: some View {
        let background = tint ?? motif.tint
        Rectangle()
            .fill(background)
            .overlay {
                GeometryReader { geo in
                    FoodIllustration(motif: motif, background: background)
                        .frame(width: geo.size.width * scale, height: geo.size.height * scale)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
    }
}

// MARK: - Zuordnung

extension FoodMotif {
    /// Schlagworte im Titel, in Prüfreihenfolge (spezifisch vor allgemein)
    private static let keywords: [(String, FoodMotif)] = [
        ("suppe", .suppe), ("eintopf", .suppe), ("brühe", .suppe), ("chili", .suppe),
        ("taco", .taco), ("burrito", .taco), ("wrap", .taco),
        ("burger", .burger), ("pizza", .pizza), ("flammkuchen", .pizza),
        ("nudel", .nudeln), ("pasta", .nudeln), ("spaghetti", .nudeln), ("lasagne", .auflauf), ("gnocchi", .nudeln),
        ("auflauf", .auflauf), ("gratin", .auflauf), ("quiche", .auflauf), ("tarte", .auflauf),
        ("curry", .bowl), ("bowl", .bowl), ("reis", .bowl), ("risotto", .bowl), ("dal", .bowl), ("ramen", .bowl),
        ("lachs", .fisch), ("fisch", .fisch), ("kabeljau", .fisch), ("forelle", .fisch), ("thunfisch", .fisch), ("garnele", .fisch),
        ("hähnchen", .keule), ("huhn", .keule), ("chicken", .keule), ("geflügel", .keule), ("coq", .keule),
        ("steak", .steak), ("roulade", .steak), ("braten", .steak), ("gulasch", .steak), ("filet", .steak),
        ("medaillon", .steak), ("tafelspitz", .steak), ("schnitzel", .steak), ("cordon", .steak), ("rind", .steak), ("gyros", .steak),
        ("spieß", .spiess), ("espetada", .spiess), ("schaschlik", .spiess),
        ("salat", .salat),
        ("spiegelei", .spiegelei), ("rührei", .spiegelei), ("omelett", .spiegelei), ("shakshuka", .spiegelei),
        ("pfannkuchen", .pfannkuchen), ("pancake", .pfannkuchen), ("schmarrn", .pfannkuchen), ("crêpe", .pfannkuchen),
        ("knödel", .knoedel), ("klöße", .knoedel), ("kloß", .knoedel), ("dampfnudel", .knoedel), ("maultasche", .knoedel),
        ("eis", .eis), ("sorbet", .eis),
        ("muffin", .muffin), ("cupcake", .muffin),
        ("kuchen", .kuchen), ("torte", .kuchen), ("tiramisu", .kuchen), ("crumble", .kuchen), ("brownie", .kuchen),
        ("brot", .brot), ("brötchen", .brot), ("focaccia", .brot), ("polenta", .brot),
        ("kürbis", .kuerbis),
        ("smoothie", .glas), ("limonade", .glas), ("cocktail", .glas), ("drink", .glas),
        ("gemüse", .gemuese), ("karotte", .gemuese), ("möhre", .gemuese), ("zucchini", .gemuese), ("spargel", .gemuese),
    ]

    /// Motiv für einen Titel; nil, wenn kein Schlagwort passt
    static func matching(title: String) -> FoodMotif? {
        let t = title.lowercased()
        // „eis“ nur als eigenes Wort bzw. Wortende („Vanilleeis“), sonst passt „Reis“/„Fleisch“ nicht
        return keywords.first { keyword, _ in
            keyword == "eis"
                ? t.split { !$0.isLetter }.contains { $0.hasSuffix("eis") && !$0.hasSuffix("reis") && $0 != "preis" }
                : t.contains(keyword)
        }?.1
    }

    init(dishType: DishType) {
        self = switch dishType {
        case .vorspeise: .spiess
        case .suppe: .suppe
        case .salat: .salat
        case .hauptgericht: .teller
        case .beilage: .knoedel
        case .dessert: .kuchen
        case .backen: .muffin
        case .snack: .spiess
        case .getraenk: .glas
        }
    }

    init(diet: Diet) {
        self = switch diet {
        case .fleisch: .steak
        case .fisch: .fisch
        case .vegetarisch: .gemuese
        case .vegan: .salat
        }
    }
}

extension Recipe {
    /// Illustration, solange es kein Foto gibt: Titel-Schlagwort, sonst Kategorie, sonst Teller
    var motif: FoodMotif {
        if let match = FoodMotif.matching(title: title) { return match }
        if let dishType, dishType != .hauptgericht { return FoodMotif(dishType: dishType) }
        if let diet { return FoodMotif(diet: diet) }
        return .teller
    }
}

extension RecipeFilter {
    var motif: FoodMotif {
        switch self {
        case .all: .teller
        case .diet(let diet): FoodMotif(diet: diet)
        case .dishType(let type): type == .hauptgericht ? .teller : FoodMotif(dishType: type)
        case .quick: .spiegelei
        case .longNotCooked: .auflauf
        }
    }
}

// MARK: - Zeichnungen

fileprivate enum PartRole { case fill, accent, soft, dot, line }
fileprivate struct IllustrationPart {
    let path: Path
    let role: PartRole
}

/// Hilfen im 200er-Raster mit Ursprung unten links (y wird für SwiftUI gespiegelt)
fileprivate enum Draw {
    static func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x, y: 200 - y) }

    static func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: x, y: 200 - y - h, width: w, height: h))
    }

    static func circle(_ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) -> Path { ellipse(cx - r, cy - r, 2 * r, 2 * r) }

    static func rect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, radius: CGFloat = 0) -> Path {
        Path(roundedRect: CGRect(x: x, y: 200 - y - h, width: w, height: h), cornerRadius: radius)
    }

    static func poly(_ points: [(CGFloat, CGFloat)]) -> Path {
        var p = Path()
        p.move(to: pt(points[0].0, points[0].1))
        for point in points.dropFirst() { p.addLine(to: pt(point.0, point.1)) }
        p.closeSubpath()
        return p
    }

    static func line(_ points: (CGFloat, CGFloat)...) -> Path {
        var p = Path()
        p.move(to: pt(points[0].0, points[0].1))
        for point in points.dropFirst() { p.addLine(to: pt(point.0, point.1)) }
        return p
    }

    static func wave(from x0: CGFloat, to x1: CGFloat, y: CGFloat, amp: CGFloat, waves: Int) -> Path {
        var p = Path()
        p.move(to: pt(x0, y))
        let step = (x1 - x0) / CGFloat(waves * 2)
        for i in 0..<(waves * 2) {
            let x = x0 + CGFloat(i) * step
            p.addQuadCurve(to: pt(x + step, y), control: pt(x + step / 2, y + (i % 2 == 0 ? amp : -amp)))
        }
        return p
    }

    static func steam(_ x: CGFloat, _ y0: CGFloat, _ y1: CGFloat) -> Path {
        var p = Path()
        let mid = (y0 + y1) / 2
        p.move(to: pt(x, y0))
        p.addCurve(to: pt(x, mid), control1: pt(x - 12, y0 + 8), control2: pt(x + 12, mid - 8))
        p.addCurve(to: pt(x, y1), control1: pt(x - 12, mid + 8), control2: pt(x + 12, y1 - 8))
        return p
    }

    /// Blatt mit Spitze bei (x, y), Länge len, Winkel in Grad (gegen den Uhrzeigersinn)
    static func leaf(_ x: CGFloat, _ y: CGFloat, _ len: CGFloat, angle: Double) -> Path {
        var p = Path()
        p.move(to: .zero)
        p.addQuadCurve(to: CGPoint(x: len, y: 0), control: CGPoint(x: len / 2, y: -len * 0.45))
        p.addQuadCurve(to: .zero, control: CGPoint(x: len / 2, y: len * 0.45))
        let a = -angle * .pi / 180
        return p.applying(CGAffineTransform(rotationAngle: a).concatenating(CGAffineTransform(translationX: x, y: 200 - y)))
    }

    /// Untere Hälfte eines Kreises (Schüssel), oben offen und mit gerader Kante geschlossen
    static func bowl(center cx: CGFloat, _ cy: CGFloat, radius r: CGFloat, depth: CGFloat = 1) -> Path {
        let k = 0.5523 * r
        var p = Path()
        p.move(to: pt(cx - r, cy))
        p.addCurve(to: pt(cx, cy - r * depth), control1: pt(cx - r, cy - k * depth), control2: pt(cx - k, cy - r * depth))
        p.addCurve(to: pt(cx + r, cy), control1: pt(cx + k, cy - r * depth), control2: pt(cx + r, cy - k * depth))
        p.closeSubpath()
        return p
    }

    /// Obere Hälfte (Kuppel), unten mit gerader Kante geschlossen
    static func dome(center cx: CGFloat, _ cy: CGFloat, radius r: CGFloat, height: CGFloat? = nil) -> Path {
        let h = height ?? r
        let k = 0.5523
        var p = Path()
        p.move(to: pt(cx - r, cy))
        p.addCurve(to: pt(cx, cy + h), control1: pt(cx - r, cy + k * h), control2: pt(cx - k * r, cy + h))
        p.addCurve(to: pt(cx + r, cy), control1: pt(cx + k * r, cy + h), control2: pt(cx + r, cy + k * h))
        p.closeSubpath()
        return p
    }
}

fileprivate enum Motifs {
    typealias D = Draw

    static func parts(for motif: FoodMotif) -> [IllustrationPart] {
        switch motif {
        case .teller:
            return [
                .init(path: D.circle(100, 100, 64), role: .fill),
                .init(path: D.circle(100, 100, 44), role: .line),
                .init(path: D.line((22, 52), (22, 150)), role: .line),
                .init(path: D.line((14, 150), (14, 124), (30, 124), (30, 150)), role: .line),
                .init(path: D.line((178, 52), (178, 150)), role: .line),
                .init(path: D.poly([(178, 150), (186, 132), (178, 110)]), role: .fill),
                .init(path: D.leaf(86, 102, 28, angle: 25), role: .accent),
            ]
        case .suppe:
            return [
                .init(path: D.steam(72, 132, 178), role: .line),
                .init(path: D.steam(100, 138, 188), role: .line),
                .init(path: D.steam(128, 132, 178), role: .line),
                .init(path: D.poly([(76, 30), (124, 30), (118, 42), (82, 42)]), role: .fill),
                .init(path: D.bowl(center: 100, 108, radius: 72), role: .fill),
                .init(path: D.ellipse(30, 98, 140, 22), role: .accent),
                .init(path: D.circle(78, 110, 5), role: .dot),
                .init(path: D.circle(112, 106, 4), role: .dot),
            ]
        case .nudeln:
            return [
                .init(path: D.ellipse(18, 36, 164, 64), role: .fill),
                .init(path: D.wave(from: 52, to: 148, y: 72, amp: 9, waves: 3), role: .line),
                .init(path: D.wave(from: 46, to: 154, y: 86, amp: 9, waves: 3), role: .line),
                .init(path: D.wave(from: 58, to: 142, y: 100, amp: 9, waves: 3), role: .line),
                .init(path: D.circle(82, 108, 13), role: .accent),
                .init(path: D.circle(118, 104, 11), role: .accent),
                .init(path: D.leaf(96, 118, 34, angle: 30), role: .fill),
            ]
        case .fisch:
            var body = Path()
            body.move(to: D.pt(34, 100))
            body.addCurve(to: D.pt(150, 100), control1: D.pt(72, 156), control2: D.pt(128, 150))
            body.addCurve(to: D.pt(34, 100), control1: D.pt(128, 52), control2: D.pt(72, 46))
            var gill = Path()
            gill.move(to: D.pt(78, 124))
            gill.addQuadCurve(to: D.pt(78, 78), control: D.pt(92, 100))
            return [
                .init(path: D.poly([(146, 100), (184, 134), (176, 100), (184, 66)]), role: .accent),
                .init(path: D.poly([(92, 136), (118, 158), (124, 134)]), role: .fill),
                .init(path: body, role: .fill),
                .init(path: gill, role: .line),
                .init(path: D.circle(58, 108, 6), role: .dot),
                .init(path: D.wave(from: 96, to: 136, y: 96, amp: 5, waves: 2), role: .line),
            ]
        case .steak:
            var marbling = Path()
            marbling.move(to: D.pt(60, 70))
            marbling.addQuadCurve(to: D.pt(150, 90), control: D.pt(110, 60))
            return [
                .init(path: D.ellipse(26, 50, 148, 100), role: .accent),
                .init(path: marbling, role: .line),
                .init(path: D.wave(from: 92, to: 150, y: 120, amp: 5, waves: 2), role: .line),
                .init(path: D.circle(60, 112, 18), role: .fill),
                .init(path: D.circle(60, 112, 7), role: .line),
                .init(path: D.leaf(130, 150, 36, angle: 20), role: .fill),
            ]
        case .keule:
            return [
                .init(path: D.poly([(110, 96), (122, 106), (162, 62), (150, 52)]), role: .fill),
                .init(path: D.circle(160, 44, 11), role: .fill),
                .init(path: D.circle(170, 58, 11), role: .fill),
                .init(path: D.ellipse(26, 82, 104, 84), role: .fill),
                .init(path: D.wave(from: 50, to: 100, y: 128, amp: 5, waves: 2), role: .line),
                .init(path: D.leaf(60, 148, 30, angle: 30), role: .accent),
            ]
        case .salat:
            return [
                .init(path: D.leaf(46, 110, 60, angle: 50), role: .fill),
                .init(path: D.leaf(80, 112, 66, angle: 75), role: .fill),
                .init(path: D.leaf(112, 110, 62, angle: 105), role: .fill),
                .init(path: D.leaf(150, 108, 56, angle: 135), role: .fill),
                .init(path: D.circle(124, 118, 13), role: .accent),
                .init(path: D.circle(78, 116, 9), role: .accent),
                .init(path: D.bowl(center: 100, 108, radius: 76, depth: 0.82), role: .fill),
                .init(path: D.line((30, 108), (170, 108)), role: .line),
            ]
        case .burger:
            return [
                .init(path: D.rect(32, 46, 136, 24, radius: 12), role: .fill),
                .init(path: D.rect(28, 70, 144, 24, radius: 12), role: .fill),
                .init(path: D.rect(34, 94, 132, 10, radius: 5), role: .accent),
                .init(path: D.wave(from: 30, to: 170, y: 106, amp: 6, waves: 5), role: .line),
                .init(path: D.dome(center: 100, 108, radius: 70, height: 60), role: .fill),
                .init(path: D.circle(80, 146, 3), role: .dot),
                .init(path: D.circle(104, 154, 3), role: .dot),
                .init(path: D.circle(126, 142, 3), role: .dot),
            ]
        case .pizza:
            return [
                .init(path: D.poly([(100, 28), (34, 156), (166, 156)]), role: .fill),
                .init(path: D.rect(26, 150, 148, 22, radius: 11), role: .fill),
                .init(path: D.circle(86, 118, 12), role: .accent),
                .init(path: D.circle(118, 132, 10), role: .accent),
                .init(path: D.circle(102, 86, 9), role: .accent),
                .init(path: D.leaf(116, 104, 22, angle: 40), role: .line),
            ]
        case .bowl:
            return [
                .init(path: D.line((124, 120), (172, 186)), role: .line),
                .init(path: D.line((140, 116), (186, 178)), role: .line),
                .init(path: D.dome(center: 92, 104, radius: 54, height: 40), role: .fill),
                .init(path: D.ellipse(96, 98, 64, 26), role: .accent),
                .init(path: D.bowl(center: 100, 104, radius: 76, depth: 0.85), role: .fill),
                .init(path: D.poly([(78, 34), (122, 34), (116, 44), (84, 44)]), role: .fill),
            ]
        case .spiegelei:
            return [
                .init(path: D.rect(140, 92, 54, 16, radius: 8), role: .fill),
                .init(path: D.circle(88, 100, 66), role: .fill),
                .init(path: D.circle(88, 100, 50), role: .line),
                .init(path: D.ellipse(54, 70, 72, 60), role: .fill),
                .init(path: D.circle(92, 104, 15), role: .soft),
            ]
        case .brot:
            return [
                .init(path: D.dome(center: 100, 64, radius: 76, height: 72), role: .fill),
                .init(path: D.rect(24, 44, 152, 22, radius: 6), role: .fill),
                .init(path: D.line((66, 94), (82, 122)), role: .line),
                .init(path: D.line((96, 98), (112, 126)), role: .line),
                .init(path: D.line((126, 94), (142, 122)), role: .line),
            ]
        case .eis:
            return [
                .init(path: D.poly([(100, 24), (66, 108), (134, 108)]), role: .fill),
                .init(path: D.line((86, 96), (112, 56)), role: .line),
                .init(path: D.line((114, 96), (88, 56)), role: .line),
                .init(path: D.circle(84, 132, 30), role: .fill),
                .init(path: D.circle(118, 138, 30), role: .accent),
                .init(path: D.circle(102, 172, 9), role: .accent),
            ]
        case .muffin:
            return [
                .init(path: D.poly([(56, 36), (144, 36), (158, 100), (42, 100)]), role: .fill),
                .init(path: D.line((78, 40), (72, 96)), role: .line),
                .init(path: D.line((100, 40), (100, 96)), role: .line),
                .init(path: D.line((122, 40), (128, 96)), role: .line),
                .init(path: D.dome(center: 100, 98, radius: 64, height: 58), role: .fill),
                .init(path: D.circle(80, 124, 7), role: .accent),
                .init(path: D.circle(108, 138, 7), role: .accent),
                .init(path: D.circle(124, 116, 7), role: .accent),
            ]
        case .kuchen:
            return [
                .init(path: D.line((150, 152), (162, 176)), role: .line),
                .init(path: D.poly([(28, 44), (172, 44), (172, 118), (28, 78)]), role: .fill),
                .init(path: D.poly([(28, 78), (172, 118), (172, 134), (28, 92)]), role: .fill),
                .init(path: D.line((28, 62), (172, 84)), role: .line),
                .init(path: D.circle(150, 142, 12), role: .accent),
            ]
        case .glas:
            return [
                .init(path: D.line((118, 128), (146, 186)), role: .line),
                .init(path: D.poly([(62, 34), (138, 34), (148, 160), (52, 160)]), role: .fill),
                .init(path: D.poly([(64, 42), (136, 42), (142, 118), (58, 118)]), role: .accent),
                .init(path: D.circle(56, 160, 20), role: .soft),
            ]
        case .knoedel:
            return [
                .init(path: D.ellipse(16, 38, 168, 60), role: .fill),
                .init(path: D.ellipse(36, 52, 128, 30), role: .accent),
                .init(path: D.circle(76, 98, 32), role: .fill),
                .init(path: D.circle(124, 94, 30), role: .fill),
                .init(path: D.circle(70, 108, 3), role: .dot),
                .init(path: D.circle(86, 96, 3), role: .dot),
                .init(path: D.circle(120, 104, 3), role: .dot),
                .init(path: D.leaf(96, 128, 24, angle: 60), role: .line),
            ]
        case .auflauf:
            return [
                .init(path: D.steam(80, 118, 162), role: .line),
                .init(path: D.steam(118, 118, 162), role: .line),
                .init(path: D.rect(10, 74, 30, 16, radius: 8), role: .fill),
                .init(path: D.rect(160, 74, 30, 16, radius: 8), role: .fill),
                .init(path: D.rect(26, 40, 148, 66, radius: 18), role: .fill),
                .init(path: D.wave(from: 32, to: 168, y: 96, amp: 6, waves: 5), role: .line),
                .init(path: D.circle(70, 82, 7), role: .accent),
                .init(path: D.circle(118, 76, 6), role: .accent),
            ]
        case .pfannkuchen:
            return [
                .init(path: D.ellipse(30, 40, 140, 34), role: .fill),
                .init(path: D.ellipse(34, 58, 132, 32), role: .fill),
                .init(path: D.ellipse(38, 76, 124, 32), role: .fill),
                .init(path: D.poly([(84, 98), (110, 92), (122, 108), (96, 114)]), role: .soft),
                .init(path: D.circle(136, 104, 8), role: .accent),
                .init(path: D.circle(62, 100, 7), role: .accent),
            ]
        case .kuerbis:
            return [
                .init(path: D.leaf(108, 140, 42, angle: 20), role: .fill),
                .init(path: D.ellipse(30, 38, 84, 96), role: .fill),
                .init(path: D.ellipse(86, 38, 84, 96), role: .fill),
                .init(path: D.ellipse(64, 34, 72, 104), role: .accent),
                .init(path: D.poly([(93, 132), (107, 132), (110, 158), (96, 158)]), role: .fill),
            ]
        case .gemuese:
            // Möhre links, Brokkoli rechts
            return [
                .init(path: D.leaf(92, 150, 40, angle: 60), role: .fill),
                .init(path: D.leaf(96, 150, 36, angle: 100), role: .fill),
                .init(path: D.poly([(30, 30), (104, 150), (80, 160)]), role: .accent),
                .init(path: D.line((56, 76), (68, 70)), role: .line),
                .init(path: D.line((72, 104), (84, 98)), role: .line),
                .init(path: D.rect(134, 30, 22, 56, radius: 8), role: .fill),
                .init(path: D.circle(124, 96, 24), role: .fill),
                .init(path: D.circle(166, 98, 24), role: .fill),
                .init(path: D.circle(145, 122, 27), role: .fill),
            ]
        case .spiess:
            return [
                .init(path: D.line((30, 30), (172, 172)), role: .line),
                .init(path: D.rect(44, 44, 30, 30, radius: 6), role: .fill),
                .init(path: D.circle(92, 92, 17), role: .accent),
                .init(path: D.rect(110, 110, 30, 30, radius: 6), role: .fill),
                .init(path: D.circle(152, 152, 14), role: .accent),
            ]
        case .taco:
            var fillings: [IllustrationPart] = []
            for (i, deg) in stride(from: 32.0, through: 148.0, by: 23.2).enumerated() {
                let a = deg * .pi / 180
                fillings.append(.init(path: D.circle(100 + 82 * cos(a), 52 + 82 * sin(a), 17), role: i % 2 == 0 ? .fill : .accent))
            }
            return fillings + [
                .init(path: D.dome(center: 100, 52, radius: 80), role: .fill),
                .init(path: D.circle(70, 80, 3.5), role: .dot),
                .init(path: D.circle(104, 98, 3.5), role: .dot),
                .init(path: D.circle(134, 74, 3.5), role: .dot),
            ]
        }
    }

    static func parts(for reaction: Reaction) -> [IllustrationPart] {
        switch reaction {
        case .jubel:
            // Konfettikanone, Öffnung nach rechts oben
            return [
                .init(path: D.steam(124, 104, 172), role: .line),
                .init(path: D.wave(from: 116, to: 180, y: 96, amp: 8, waves: 2), role: .line),
                .init(path: D.poly([(150, 136), (164, 142), (158, 156), (144, 150)]), role: .accent),
                .init(path: D.poly([(88, 146), (100, 150), (96, 162), (84, 158)]), role: .soft),
                .init(path: D.circle(160, 118, 7), role: .accent),
                .init(path: D.circle(176, 168, 5), role: .dot),
                .init(path: D.circle(104, 186, 4), role: .dot),
                .init(path: D.circle(186, 130, 4), role: .dot),
                .init(path: D.poly([(26, 26), (114, 70), (70, 114)]), role: .fill),
                .init(path: D.line((62, 44), (44, 62)), role: .line),
                .init(path: D.line((88, 57), (57, 88)), role: .line),
            ]
        case .warten:
            // Sanduhr
            return [
                .init(path: D.poly([(62, 160), (138, 160), (108, 100), (138, 40), (62, 40), (92, 100)]), role: .fill),
                .init(path: D.poly([(76, 144), (124, 144), (100, 110)]), role: .accent),
                .init(path: D.poly([(72, 44), (128, 44), (100, 70)]), role: .accent),
                .init(path: D.line((100, 108), (100, 72)), role: .line),
                .init(path: D.rect(46, 158, 108, 16, radius: 8), role: .fill),
                .init(path: D.rect(46, 26, 108, 16, radius: 8), role: .fill),
            ]
        case .lecker:
            // Zufriedenes Gesicht mit Zunge
            var mouth = Path()
            mouth.move(to: D.pt(62, 86))
            mouth.addQuadCurve(to: D.pt(138, 86), control: D.pt(100, 44))
            return [
                .init(path: D.circle(100, 100, 72), role: .soft),
                .init(path: D.bowl(center: 118, 70, radius: 15, depth: 1.4), role: .accent),
                .init(path: D.line((118, 68), (118, 58)), role: .line),
                .init(path: mouth, role: .line),
                .init(path: D.line((64, 116), (76, 128), (88, 116)), role: .line),
                .init(path: D.line((112, 116), (124, 128), (136, 116)), role: .line),
            ]
        case .korb:
            // Leerer Einkaufskorb, nur ein Blatt schaut heraus
            return [
                .init(path: D.dome(center: 100, 104, radius: 54, height: 66), role: .line),
                .init(path: D.leaf(118, 104, 44, angle: 62), role: .accent),
                .init(path: D.poly([(32, 104), (168, 104), (150, 32), (50, 32)]), role: .fill),
                .init(path: D.line((74, 100), (78, 36)), role: .line),
                .init(path: D.line((100, 100), (100, 36)), role: .line),
                .init(path: D.line((126, 100), (122, 36)), role: .line),
                .init(path: D.line((42, 68), (158, 68)), role: .line),
                .init(path: D.rect(24, 98, 152, 18, radius: 9), role: .fill),
            ]
        case .ratlos:
            // Leerer Teller mit Fragezeichen
            var question = Path()
            question.move(to: D.pt(84, 116))
            question.addCurve(to: D.pt(116, 116), control1: D.pt(84, 140), control2: D.pt(116, 140))
            question.addCurve(to: D.pt(100, 92), control1: D.pt(116, 102), control2: D.pt(100, 104))
            question.addLine(to: D.pt(100, 84))
            return [
                .init(path: D.circle(100, 100, 66), role: .fill),
                .init(path: D.circle(100, 100, 46), role: .line),
                .init(path: question, role: .line),
                .init(path: D.circle(100, 70, 5), role: .accent),
            ]
        }
    }
}

#if DEBUG
/// Alle Motive auf einen Blick – für Design-Reviews (Start mit NOMI_GALLERY=1).
struct IllustrationGallery: View {
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(FoodMotif.allCases, id: \.self) { motif in
                    VStack(spacing: 4) {
                        IllustrationTile(motif: motif)
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(.rect(cornerRadius: 14))
                        Text(motif.rawValue).font(.meta)
                    }
                }
                ForEach(Array([ChefiView(), ChefiView(spoonTilt: -0.08, spoonLift: 20, winks: true), ChefiView(waves: true)].enumerated()), id: \.offset) { index, chefi in
                    VStack(spacing: 4) {
                        chefi
                            .padding(8)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color.brand, in: .rect(cornerRadius: 14))
                        Text("chefi \(index + 1)").font(.meta)
                    }
                }
                ForEach(Reaction.allCases, id: \.self) { reaction in
                    VStack(spacing: 4) {
                        ReactionIllustration(reaction: reaction)
                            .padding(10)
                            .aspectRatio(1, contentMode: .fit)
                            .background(Color.surface, in: .rect(cornerRadius: 14))
                        Text(reaction.rawValue).font(.meta)
                    }
                }
            }
            .padding(12)
        }
        .background(Color.canvas)
    }
}
#endif
