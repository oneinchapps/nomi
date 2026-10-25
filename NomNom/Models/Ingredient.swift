import Foundation

struct Ingredient: Codable, Hashable, Sendable {
    var name: String
    var quantity: Double?
    var unit: String?
    var note: String?
    var aisle: Aisle?

    func scaled(by factor: Double) -> Ingredient {
        var copy = self
        copy.quantity = quantity.map { $0 * factor }
        return copy
    }

    /// „1 ½ EL“ – Menge und Einheit, leer bei „Salz nach Geschmack“.
    var amountText: String {
        QuantityFormatter.amount(quantity, unit: unit)
    }

    /// Zurück in eine Textzeile, wie man sie im Editor tippt.
    var line: String {
        var parts = [amountText, name].filter { !$0.isEmpty }.joined(separator: " ")
        if let note, !note.isEmpty { parts += ", \(note)" }
        return parts
    }
}

// MARK: - Supermarkt-Abteilungen

/// Entspricht dem Postgres-Enum `public.aisle`, Reihenfolge = Weg durch den Laden.
enum Aisle: String, Codable, CaseIterable, Sendable {
    case obstGemuese = "obst_gemuese"
    case backwaren
    case kuehlregal
    case fleischFisch = "fleisch_fisch"
    case trockenwaren
    case konserven
    case gewuerzeOele = "gewuerze_oele"
    case tiefkuehl
    case getraenke
    case drogerie
    case sonstiges

    var title: String {
        switch self {
        case .obstGemuese: "Obst & Gemüse"
        case .backwaren: "Backwaren"
        case .kuehlregal: "Kühlregal"
        case .fleischFisch: "Fleisch & Fisch"
        case .trockenwaren: "Trockenwaren"
        case .konserven: "Konserven & Gläser"
        case .gewuerzeOele: "Gewürze & Öle"
        case .tiefkuehl: "Tiefkühl"
        case .getraenke: "Getränke"
        case .drogerie: "Drogerie"
        case .sonstiges: "Sonstiges"
        }
    }

    /// Grobe Zuordnung per Stichwort, bis die KI beim Import genauer zuordnet.
    static func guess(for name: String) -> Aisle {
        let n = name.lowercased()
        let words = n.split { !$0.isLetter }.map(String.init)
        for (aisle, keys) in keywords where keys.contains(where: { matches($0, name: n, words: words) }) {
            return aisle
        }
        return .sonstiges
    }

    /// Kurze Stichworte („ei“, „öl“) nur am Wortanfang/-ende, sonst landet „Reis“ im Kühlregal.
    /// Wortende zählt, weil deutsche Komposita hinten das Entscheidende tragen („Olivenöl“).
    private static func matches(_ key: String, name: String, words: [String]) -> Bool {
        guard key.count <= 3 else { return name.contains(key) }
        return words.contains { $0.hasPrefix(key) || $0.hasSuffix(key) }
    }

    // Reihenfolge wichtig: „Tomatenmark“ soll Konserve sein, nicht Gemüse; „Kokosmilch“ nicht Kühlregal.
    private static let keywords: [(Aisle, [String])] = [
        (.tiefkuehl, ["tiefkühl", "tk-", "gefroren"]),
        (.konserven, ["dose", "tomatenmark", "passiert", "kokosmilch", "kichererbsen", "kidneybohnen", "mais", "pesto", "senf", "ketchup", "mayo", "glas"]),
        (.gewuerzeOele, ["salz", "pfeffer", "öl", "essig", "paprikapulver", "kreuzkümmel", "curry", "zimt", "chiliflocken", "oregano", "sojasauce", "brühe", "gewürz", "kurkuma", "muskat", "honig", "zucker", "sirup"]),
        (.kuehlregal, ["milch", "sahne", "butter", "joghurt", "quark", "käse", "feta", "halloumi", "mozzarella", "parmesan", "schmand", "rahm", "crème", "creme", "ei", "tofu", "skyr", "frischkäse"]),
        (.fleischFisch, ["hähnchen", "huhn", "rind", "schwein", "hack", "speck", "schinken", "wurst", "lachs", "thunfisch", "garnele", "fisch", "steak"]),
        (.backwaren, ["brot", "brötchen", "tortilla", "wrap", "baguette", "toast", "pita", "naan"]),
        (.trockenwaren, ["mehl", "nudel", "pasta", "spaghetti", "reis", "linsen", "haferflocken", "couscous", "bulgur", "quinoa", "backpulver", "hefe", "nüsse", "mandel", "sesam", "panko", "ramen"]),
        (.getraenke, ["wein", "bier", "saft", "wasser"]),
        (.obstGemuese, ["zwiebel", "knoblauch", "tomate", "paprika", "zucchini", "aubergine", "karotte", "möhre", "kartoffel", "salat", "spinat", "gurke", "avocado", "zitrone", "limette", "apfel", "banane", "ingwer", "koriander", "petersilie", "basilikum", "minze", "lauch", "frühlingszwiebel", "pilz", "champignon", "brokkoli", "blumenkohl", "kürbis", "chili", "erbsen", "bohnen", "kohl", "rucola", "beeren", "sellerie", "fenchel", "radieschen", "mango", "schnittlauch", "dill", "thymian", "rosmarin"]),
    ]
}

// MARK: - Zeile → Zutat

enum IngredientParser {
    /// Bekannte Einheiten, Schreibweisen werden auf die rechte Seite normalisiert.
    static let units: [String: String] = [
        "g": "g", "gr": "g", "gramm": "g", "kg": "kg", "mg": "mg",
        "ml": "ml", "cl": "cl", "l": "l", "liter": "l",
        "el": "EL", "esslöffel": "EL", "tl": "TL", "teelöffel": "TL",
        "prise": "Prise", "prisen": "Prise", "msp": "Msp", "msp.": "Msp",
        "bund": "Bund", "stück": "Stück", "stk": "Stück", "stk.": "Stück",
        "dose": "Dose", "dosen": "Dose", "packung": "Packung", "pck": "Packung", "pck.": "Packung", "päckchen": "Packung",
        "zehe": "Zehe", "zehen": "Zehe", "scheibe": "Scheibe", "scheiben": "Scheibe",
        "becher": "Becher", "tasse": "Tasse", "tassen": "Tasse", "glas": "Glas", "handvoll": "Handvoll",
        "cup": "Cup", "cups": "Cup", "tbsp": "EL", "tsp": "TL",
    ]

    private static let unicodeFractions: [Character: Double] = [
        "½": 0.5, "¼": 0.25, "¾": 0.75, "⅓": 1.0 / 3, "⅔": 2.0 / 3, "⅛": 0.125,
    ]

    static func parse(_ raw: String) -> Ingredient? {
        var rest = raw.trimmingCharacters(in: .whitespaces)
        // Aufzählungszeichen vom Kopieren aus Blogs entfernen
        while let first = rest.first, "-•*–·".contains(first) {
            rest = String(rest.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        guard !rest.isEmpty else { return nil }

        var quantity: Double?
        var tokens = rest.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        // „200g“ → „200“ „g“
        if let first = tokens.first,
           let match = first.wholeMatch(of: /(\d+(?:[.,]\d+)?)([A-Za-zÄÖÜäöü.]+)/),
           units[String(match.2).lowercased()] != nil {
            tokens.replaceSubrange(0...0, with: [String(match.1), String(match.2)])
        }

        // Menge: „1“, „1,5“, „1/2“, „½“, „1½“, „1 1/2“, „2-3“ (nimmt den kleineren Wert)
        while let token = tokens.first, let value = number(from: token) {
            quantity = (quantity ?? 0) + value
            tokens.removeFirst()
            if value >= 1, let next = tokens.first, next.contains("/") || next.count == 1 && unicodeFractions[next.first!] != nil {
                continue
            }
            break
        }

        var unit: String?
        if quantity != nil, let token = tokens.first, let normalized = units[token.lowercased()] {
            unit = normalized
            tokens.removeFirst()
        }

        var name = tokens.joined(separator: " ")
        var note: String?
        if let comma = name.firstIndex(of: ",") {
            note = name[name.index(after: comma)...].trimmingCharacters(in: .whitespaces)
            name = String(name[..<comma]).trimmingCharacters(in: .whitespaces)
        }
        guard !name.isEmpty else { return nil }

        return Ingredient(
            name: name,
            quantity: quantity,
            unit: unit,
            note: note?.isEmpty == true ? nil : note,
            aisle: Aisle.guess(for: name)
        )
    }

    private static func number(from token: String) -> Double? {
        // „2-3“ → 2
        let token = token.split(separator: "-").first.map(String.init) ?? token
        if token.count == 1, let f = unicodeFractions[token.first!] { return f }
        if let last = token.last, let f = unicodeFractions[last], let whole = Double(token.dropLast()) {
            return whole + f
        }
        if token.contains("/") {
            let parts = token.split(separator: "/")
            guard parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]), b != 0 else { return nil }
            return a / b
        }
        return Double(token.replacingOccurrences(of: ",", with: "."))
    }
}

// MARK: - Mengen formatieren

enum QuantityFormatter {
    /// Menge mit Einheit in der lesbarsten Größe: „1500 g“ → „1,5 kg“, „0,75 l“ → „750 ml“.
    static func amount(_ quantity: Double?, unit: String?) -> String {
        guard let quantity else { return unit ?? "" }
        var value = quantity
        var unit = unit
        if unit == "g", value >= 1000 { value /= 1000; unit = "kg" }
        if unit == "ml", value >= 1000 { value /= 1000; unit = "l" }
        if unit == "kg", value < 1 { value *= 1000; unit = "g" }
        if unit == "l", value < 1 { value *= 1000; unit = "ml" }
        let shown = value > 1 ? unit.map { plurals[$0] ?? $0 } : unit
        return [string(for: value, unit: unit), shown].compactMap { $0 }.joined(separator: " ")
    }

    /// Einheiten im Plural, nur für die Anzeige („2 Zehen“). Gespeichert wird immer der Singular.
    private static let plurals = [
        "Zehe": "Zehen", "Scheibe": "Scheiben", "Dose": "Dosen", "Packung": "Packungen",
        "Prise": "Prisen", "Tasse": "Tassen", "Glas": "Gläser",
    ]

    /// Gramm & Co. werden sinnvoll gerundet, Stückzahlen und Löffel als Brüche gezeigt.
    static func string(for value: Double, unit: String?) -> String {
        switch unit {
        case "g", "ml":
            let rounded = value >= 100 ? (value / 10).rounded() * 10 : value >= 20 ? (value / 5).rounded() * 5 : value.rounded()
            return decimal(max(rounded, 1))
        case "kg", "l":
            return decimal((value * 100).rounded() / 100)
        default:
            return fraction(value)
        }
    }

    static func fraction(_ value: Double) -> String {
        let whole = Int(value)
        let rest = value - Double(whole)
        let candidates: [(Double, String)] = [(0, ""), (0.25, "¼"), (1.0 / 3, "⅓"), (0.5, "½"), (2.0 / 3, "⅔"), (0.75, "¾"), (1, "")]
        let nearest = candidates.min { abs($0.0 - rest) < abs($1.0 - rest) }!
        let adjustedWhole = nearest.0 == 1 ? whole + 1 : whole
        if adjustedWhole == 0 && nearest.1.isEmpty {
            // Sehr kleine Mengen nicht auf 0 runden
            return decimal(value)
        }
        if adjustedWhole == 0 { return nearest.1 }
        return nearest.1.isEmpty ? "\(adjustedWhole)" : "\(adjustedWhole) \(nearest.1)"
    }

    static func decimal(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0...2)).locale(Locale(identifier: "de_DE")))
    }
}
