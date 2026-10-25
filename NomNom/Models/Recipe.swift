import SwiftUI

struct Recipe: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID?
    var title: String
    var summary: String?
    var source: Source
    var sourceURL: URL?
    var imageURL: URL?
    var totalMinutes: Int?
    var servings: Int
    var ingredients: [Ingredient]
    var steps: [Step]
    var tags: [String]
    var createdAt: Date?

    enum Source: String, Codable, Sendable {
        case manual, web, instagram, tiktok, ai
    }

    struct Step: Codable, Hashable, Sendable {
        var text: String
        var timerSeconds: Int?

        enum CodingKeys: String, CodingKey {
            case text
            case timerSeconds = "timer_seconds"
        }
    }

    enum CodingKeys: String, CodingKey {
        case id, title, summary, source, servings, ingredients, steps, tags
        case householdId = "household_id"
        case sourceURL = "source_url"
        case imageURL = "image_url"
        case totalMinutes = "total_minutes"
        case createdAt = "created_at"
    }

    init(
        id: UUID = UUID(),
        householdId: UUID? = nil,
        title: String,
        summary: String? = nil,
        source: Source = .manual,
        sourceURL: URL? = nil,
        imageURL: URL? = nil,
        totalMinutes: Int? = nil,
        servings: Int = 2,
        ingredients: [Ingredient] = [],
        steps: [Step] = [],
        tags: [String] = [],
        createdAt: Date? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.title = title
        self.summary = summary
        self.source = source
        self.sourceURL = sourceURL
        self.imageURL = imageURL
        self.totalMinutes = totalMinutes
        self.servings = servings
        self.ingredients = ingredients
        self.steps = steps
        self.tags = tags
        self.createdAt = createdAt
    }

    /// Schreibt nur die Felder, die die App setzt; created_at/created_by vergibt die Datenbank.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(householdId, forKey: .householdId)
        try c.encode(title, forKey: .title)
        try c.encode(summary, forKey: .summary)
        try c.encode(source, forKey: .source)
        try c.encode(sourceURL, forKey: .sourceURL)
        try c.encode(imageURL, forKey: .imageURL)
        try c.encode(totalMinutes, forKey: .totalMinutes)
        try c.encode(servings, forKey: .servings)
        try c.encode(ingredients, forKey: .ingredients)
        try c.encode(steps, forKey: .steps)
        try c.encode(tags, forKey: .tags)
    }
}

// MARK: - Darstellung

extension Recipe {
    /// „25 MIN · FÜR ZWEI“
    var metaLine: String {
        [totalMinutes.map(Self.durationLabel), Self.servingsLabel(servings)]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    static func durationLabel(_ minutes: Int) -> String {
        guard minutes >= 60 else { return "\(minutes) Min" }
        let h = minutes / 60, m = minutes % 60
        return m == 0 ? "\(h) Std" : "\(h) Std \(m)"
    }

    static func servingsLabel(_ n: Int) -> String {
        let words = [1: "eine Person", 2: "zwei", 3: "drei", 4: "vier", 5: "fünf", 6: "sechs"]
        return "für " + (words[n] ?? "\(n)")
    }

    /// Platzhalter-Emoji nach Stichworten im Titel, solange es kein Foto gibt.
    var emoji: String {
        let t = title.lowercased()
        let map: [(String, String)] = [
            ("taco", "🌮"), ("burrito", "🌯"), ("pizza", "🍕"), ("burger", "🍔"), ("ramen", "🍜"),
            ("nudel", "🍜"), ("udon", "🍜"), ("pasta", "🍝"), ("spaghetti", "🍝"), ("lasagne", "🍝"),
            ("curry", "🍛"), ("dal", "🍛"), ("reis", "🍚"), ("risotto", "🍚"), ("sushi", "🍣"),
            ("suppe", "🍲"), ("eintopf", "🍲"), ("chili", "🌶️"), ("salat", "🥗"), ("bowl", "🥗"),
            ("gemüse", "🥦"), ("shakshuka", "🍳"), ("ei", "🍳"), ("pfannkuchen", "🥞"), ("pancake", "🥞"),
            ("kuchen", "🍰"), ("brot", "🥖"), ("sandwich", "🥪"), ("lachs", "🐟"), ("fisch", "🐟"),
            ("garnele", "🍤"), ("hähnchen", "🍗"), ("huhn", "🍗"), ("steak", "🥩"), ("kartoffel", "🥔"),
            ("roulade", "🥩"), ("braten", "🍖"), ("gulasch", "🍲"), ("schnitzel", "🍖"), ("knödel", "🥟"),
            ("spätzle", "🍝"), ("flammkuchen", "🍕"), ("auflauf", "🥘"), ("gratin", "🥘"), ("quiche", "🥧"),
            ("falafel", "🧆"), ("halloumi", "🧀"), ("käse", "🧀"), ("dumpling", "🥟"), ("gyoza", "🥟"),
        ]
        return map.first { t.contains($0.0) }?.1 ?? "🍽️"
    }

    /// Stabile Pastellfarbe pro Rezept (hashValue ist pro Start zufällig, daher eigener Hash).
    var tint: Color {
        let palette: [(UInt32, UInt32)] = [
            (0xF1DCC3, 0x3A2F24), (0xF3D2C7, 0x3B2622), (0xD7E3C8, 0x2A3526),
            (0xE6DCEA, 0x2D2533), (0xF4E3B5, 0x3A3320), (0xDCE6EA, 0x1D282C),
        ]
        let hash = title.unicodeScalars.reduce(UInt32(5381)) { ($0 &* 33) &+ $1.value }
        let pick = palette[Int(hash % UInt32(palette.count))]
        return Color(light: pick.0, dark: pick.1)
    }

    /// Mengen für eine andere Personenzahl.
    func scaledIngredients(for targetServings: Int) -> [Ingredient] {
        guard targetServings != servings, servings > 0 else { return ingredients }
        let factor = Double(targetServings) / Double(servings)
        return ingredients.map { $0.scaled(by: factor) }
    }
}

extension Recipe {
    static let samples: [Recipe] = [
        Recipe(title: "Pesto-Pasta mit Erbsen", totalMinutes: 15),
        Recipe(title: "Halloumi-Tacos", totalMinutes: 25),
        Recipe(title: "Chili-Nudeln", totalMinutes: 20),
        Recipe(title: "Ofengemüse mit Feta", totalMinutes: 35),
        Recipe(title: "Shakshuka", totalMinutes: 30),
    ]
}
