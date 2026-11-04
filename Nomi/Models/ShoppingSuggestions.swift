import Foundation

/// Ein Vorschlag beim Tippen in der Einkaufsliste.
struct ShoppingSuggestion: Hashable, Identifiable, Sendable {
    /// Artikelname, z. B. „Milch“
    var name: String
    /// Was auf die Liste kommt – mit der schon eingetippten Menge („2 l Milch“)
    var line: String
    var id: String { line }
}

/// Autovervollständigung für die Einkaufsliste: Was ihr schon mal gekauft habt, eure Standardartikel,
/// Zutaten aus euren Rezepten und ein Grundwortschatz – das Bekannte zuerst.
enum ShoppingSuggestions {
    struct Candidate: Equatable, Sendable {
        var name: String
        /// Wie wahrscheinlich ihr das meint; höher kommt zuerst
        var weight: Double
    }

    /// Vorschläge für die Eingabe. Eine vorangestellte Menge („2 l “) bleibt erhalten,
    /// ergänzt wird nur der Name.
    static func suggestions(for input: String, candidates: [Candidate], limit: Int = 6) -> [ShoppingSuggestion] {
        guard let (amount, query) = split(input) else { return [] }
        let folded = fold(query)
        guard !folded.isEmpty else { return [] }

        let ranked = candidates.compactMap { candidate -> (Candidate, Int)? in
            let name = fold(candidate.name)
            // Genau das Getippte braucht keinen Vorschlag
            guard name != folded else { return nil }
            guard let tier = matchTier(name: name, query: folded) else { return nil }
            return (candidate, tier)
        }
        .sorted { a, b in
            if a.1 != b.1 { return a.1 > b.1 }
            if a.0.weight != b.0.weight { return a.0.weight > b.0.weight }
            if a.0.name.count != b.0.name.count { return a.0.name.count < b.0.name.count }
            return a.0.name < b.0.name
        }

        return ranked.prefix(limit).map { candidate, _ in
            ShoppingSuggestion(name: candidate.name, line: amount + candidate.name)
        }
    }

    /// Alle Kandidaten aus den Quellen, zusammengefasst nach Name (ohne Groß-/Kleinschreibung und Akzente).
    static func candidates(
        history: [String: Int] = [:],
        staples: [String] = [],
        listItems: [String] = [],
        recipeIngredients: [String] = [],
        common: [String] = ShoppingSuggestions.common
    ) -> [Candidate] {
        var byKey: [String: Candidate] = [:]
        var order: [String] = []
        func add(_ name: String, _ weight: Double) {
            let name = name.trimmingCharacters(in: .whitespaces)
            let key = fold(name)
            guard !key.isEmpty else { return }
            if var existing = byKey[key] {
                existing.weight += weight
                byKey[key] = existing
            } else {
                byKey[key] = Candidate(name: name, weight: weight)
                order.append(key)
            }
        }
        // Die erste Schreibweise gewinnt – darum die persönlichsten Quellen zuerst
        for (name, count) in history { add(name, 10 * Double(count)) }
        for name in staples { add(name, 8) }
        for name in listItems { add(name, 6) }
        for name in recipeIngredients { add(name, 2) }
        for name in common { add(name, 1) }
        return order.compactMap { byKey[$0] }
    }

    /// Trennt „2 l Mi“ in „2 l “ und „Mi“. Nil, wenn noch kein Name angefangen ist oder nach dem
    /// Komma schon eine Notiz kommt.
    static func split(_ input: String) -> (amount: String, query: String)? {
        // Mehrfache Leerzeichen wie der Parser behandeln, damit der Name hinten wiederzufinden ist
        let trimmed = input.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        guard !trimmed.contains(","), let parsed = IngredientParser.parse(trimmed) else { return nil }
        guard parsed.quantity != nil else { return ("", parsed.name) }
        // Der Name steht am Ende der Eingabe; alles davor ist die Menge
        guard let range = trimmed.range(of: parsed.name, options: [.backwards, .anchored]) else { return nil }
        let amount = trimmed[..<range.lowerBound].trimmingCharacters(in: .whitespaces)
        return (amount.isEmpty ? "" : amount + " ", parsed.name)
    }

    /// 3: Name beginnt so, 2: ein Wort darin beginnt so, 1: steckt irgendwo drin (ab 3 Zeichen)
    private static func matchTier(name: String, query: String) -> Int? {
        if name.hasPrefix(query) { return 3 }
        let words = name.split { !$0.isLetter && !$0.isNumber }
        if words.contains(where: { $0.hasPrefix(query) }) { return 2 }
        if query.count >= 3, name.contains(query) { return 1 }
        return nil
    }

    /// „Möhre“ und „mohre“ gelten als gleich
    static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de_DE"))
    }

    /// Grundwortschatz, damit es auch in einem neuen Haushalt schon Vorschläge gibt
    static let common: [String] = [
        // Obst und Gemüse
        "Äpfel", "Bananen", "Birnen", "Orangen", "Mandarinen", "Zitronen", "Limetten", "Trauben", "Erdbeeren",
        "Himbeeren", "Heidelbeeren", "Kiwis", "Mango", "Ananas", "Avocado", "Tomaten", "Kirschtomaten", "Gurke",
        "Paprika", "Zucchini", "Aubergine", "Karotten", "Kartoffeln", "Süßkartoffeln", "Zwiebeln", "rote Zwiebeln",
        "Knoblauch", "Ingwer", "Frühlingszwiebeln", "Lauch", "Brokkoli", "Blumenkohl", "Spinat", "Rucola",
        "Eisbergsalat", "Feldsalat", "Champignons", "Pilze", "Kürbis", "Sellerie", "Fenchel", "Radieschen",
        "Rote Bete", "Mais", "Erbsen", "Petersilie", "Basilikum", "Koriander", "Schnittlauch", "Minze", "Dill",
        // Kühlregal
        "Milch", "Hafermilch", "Sojamilch", "Butter", "Margarine", "Joghurt", "Naturjoghurt", "Quark", "Skyr",
        "Sahne", "Schmand", "Crème fraîche", "Frischkäse", "Mozzarella", "Feta", "Halloumi", "Parmesan",
        "Gouda", "Emmentaler", "Reibekäse", "Eier", "Tofu", "Hackfleisch", "Hähnchenbrust", "Lachs", "Schinken",
        "Speck", "Salami", "Würstchen", "Hefe",
        // Brot und Backwaren
        "Brot", "Vollkornbrot", "Toast", "Brötchen", "Baguette", "Tortillas", "Wraps", "Croissants",
        // Trockenwaren
        "Mehl", "Zucker", "Puderzucker", "Backpulver", "Nudeln", "Spaghetti", "Penne", "Reis", "Basmatireis",
        "Risottoreis", "Linsen", "rote Linsen", "Kichererbsen", "Haferflocken", "Müsli", "Cornflakes", "Couscous",
        "Bulgur", "Quinoa", "Nüsse", "Mandeln", "Walnüsse", "Cashews", "Rosinen", "Schokolade", "Kekse", "Chips",
        "Kaffee", "Tee", "Kakao", "Honig", "Marmelade", "Erdnussbutter", "Nutella",
        // Konserven
        "Dosentomaten", "passierte Tomaten", "Tomatenmark", "Kokosmilch", "Kidneybohnen", "Thunfisch", "Mais (Dose)",
        // Gewürze und Öle
        "Salz", "Pfeffer", "Olivenöl", "Rapsöl", "Essig", "Balsamico", "Senf", "Ketchup", "Mayonnaise",
        "Sojasauce", "Gemüsebrühe", "Paprikapulver", "Curry", "Zimt", "Oregano", "Chiliflocken",
        // Getränke
        "Wasser", "Sprudel", "Orangensaft", "Apfelsaft", "Bier", "Wein", "Weißwein", "Rotwein",
        // Tiefkühl
        "TK-Erbsen", "TK-Spinat", "Pizza", "Eis", "Pommes",
        // Haushalt und Drogerie
        "Klopapier", "Küchenrolle", "Spülmittel", "Spülmaschinentabs", "Waschmittel", "Müllbeutel",
        "Alufolie", "Backpapier", "Frischhaltefolie", "Zahnpasta", "Duschgel", "Shampoo", "Taschentücher",
    ]
}

/// Merkt sich pro Haushalt, was ihr selbst eingetippt habt – damit Häufiges oben steht.
/// Liegt nur auf diesem Gerät; die Liste selbst verliert Erledigtes beim „Leeren“.
enum ShoppingHistory {
    private static let maxEntries = 300

    static func load(householdId: UUID, defaults: UserDefaults = .standard) -> [String: Int] {
        defaults.dictionary(forKey: key(householdId)) as? [String: Int] ?? [:]
    }

    static func record(_ name: String, householdId: UUID, defaults: UserDefaults = .standard) {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        var counts = load(householdId: householdId, defaults: defaults)
        // Gleiche Namen in anderer Schreibweise zusammenzählen, die neueste Schreibweise behalten
        let folded = ShoppingSuggestions.fold(name)
        let previous = counts.keys.filter { ShoppingSuggestions.fold($0) == folded }
        let count = previous.reduce(0) { $0 + (counts[$1] ?? 0) }
        previous.forEach { counts[$0] = nil }
        counts[name] = count + 1
        if counts.count > maxEntries {
            counts = Dictionary(uniqueKeysWithValues: counts.sorted { $0.value > $1.value }.prefix(maxEntries).map { ($0.key, $0.value) })
        }
        defaults.set(counts, forKey: key(householdId))
    }

    private static func key(_ householdId: UUID) -> String { "shoppingHistory.\(householdId.uuidString)" }
}
