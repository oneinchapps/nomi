import Foundation

struct ShoppingItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var name: String
    var quantity: Double?
    var unit: String?
    var aisle: Aisle
    var checked: Bool
    var checkedBy: UUID?
    var recipeId: UUID?
    /// Eigene Kategorie des Haushalts, geht vor `aisle`
    var categoryId: UUID?
    var createdAt: Date?

    init(
        id: UUID = UUID(),
        householdId: UUID,
        name: String,
        quantity: Double? = nil,
        unit: String? = nil,
        aisle: Aisle = .sonstiges,
        checked: Bool = false,
        checkedBy: UUID? = nil,
        recipeId: UUID? = nil,
        categoryId: UUID? = nil,
        createdAt: Date? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.aisle = aisle
        self.checked = checked
        self.checkedBy = checkedBy
        self.recipeId = recipeId
        self.categoryId = categoryId
        self.createdAt = createdAt
    }

    var amountText: String {
        QuantityFormatter.amount(quantity, unit: unit)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, aisle, checked
        case householdId = "household_id"
        case checkedBy = "checked_by"
        case recipeId = "recipe_id"
        case categoryId = "category_id"
        case createdAt = "created_at"
    }

    /// created_at und added_by setzt die Datenbank.
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(householdId, forKey: .householdId)
        try c.encode(name, forKey: .name)
        try c.encode(quantity, forKey: .quantity)
        try c.encode(unit, forKey: .unit)
        try c.encode(aisle, forKey: .aisle)
        try c.encode(checked, forKey: .checked)
        try c.encode(checkedBy, forKey: .checkedBy)
        try c.encode(recipeId, forKey: .recipeId)
        // Nur wenn gesetzt: Beim Zusammenführen bleibt die Kategorie so unangetastet
        try c.encodeIfPresent(categoryId, forKey: .categoryId)
    }
}

/// Wiederkehrende Artikel (Milch, Eier …), die per Tap auf die Liste kommen.
struct StapleItem: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var name: String
    var quantity: Double?
    var unit: String?
    var aisle: Aisle
    var position: Int

    init(id: UUID = UUID(), householdId: UUID, name: String, quantity: Double? = nil, unit: String? = nil, aisle: Aisle, position: Int = 0) {
        self.id = id
        self.householdId = householdId
        self.name = name
        self.quantity = quantity
        self.unit = unit
        self.aisle = aisle
        self.position = position
    }

    var ingredient: Ingredient {
        Ingredient(name: name, quantity: quantity, unit: unit, aisle: aisle)
    }

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, unit, aisle, position
        case householdId = "household_id"
    }
}

// MARK: - Zusammenführen

/// Neue Zutaten in eine bestehende Liste einsortieren: Gleiches wird addiert statt doppelt geführt.
/// Was ein `ShoppingStore.add` verändert hat – genug, um es rückgängig zu machen.
struct ShoppingChange: Codable, Hashable, Sendable {
    var insertedIds: [UUID] = []
    /// Stand der zusammengeführten Einträge vor der Änderung
    var previous: [ShoppingItem] = []

    var isEmpty: Bool { insertedIds.isEmpty && previous.isEmpty }

    mutating func append(_ other: ShoppingChange) {
        insertedIds += other.insertedIds
        // Beim zweiten Zusammenführen desselben Eintrags zählt der allererste Stand
        previous += other.previous.filter { old in !previous.contains { $0.id == old.id } && !insertedIds.contains(old.id) }
    }

    enum CodingKeys: String, CodingKey {
        case insertedIds = "inserted_ids"
        case previous
    }
}

enum ShoppingMerge {
    struct Result: Equatable {
        var updates: [ShoppingItem] = []
        var inserts: [ShoppingItem] = []
    }

    /// Basis-Einheiten, damit „200 g“ und „0,3 kg“ zusammenpassen.
    private static let conversions: [String: (base: String, factor: Double)] = [
        "g": ("g", 1), "kg": ("g", 1000), "mg": ("g", 0.001),
        "ml": ("ml", 1), "l": ("ml", 1000), "cl": ("ml", 10),
    ]

    static func key(_ name: String) -> String {
        name.lowercased().split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func base(_ quantity: Double?, _ unit: String?) -> (Double?, String?) {
        guard let unit, let c = conversions[unit] else { return (quantity, unit) }
        return (quantity.map { $0 * c.factor }, c.base)
    }

    static func merge(
        _ ingredients: [Ingredient],
        recipeId: UUID?,
        into existing: [ShoppingItem],
        householdId: UUID
    ) -> Result {
        // Arbeitsliste aus offenen Einträgen. Erledigte werden nicht zusammengezählt (das war ein früherer
        // Einkauf), aber wieder geöffnet statt doppelt angelegt – jeder Artikel steht nur einmal auf der Liste.
        var open = existing.filter { !$0.checked }
        var done = existing.filter(\.checked)
        var updatedIds = Set<UUID>()
        var insertedIds = Set<UUID>()

        for ingredient in ingredients {
            let name = ingredient.name.trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty else { continue }
            let (quantity, unit) = base(ingredient.quantity, ingredient.unit)

            // Passt, wenn Einheiten zusammenpassen oder eine Seite gar keine Menge hat („Salz“)
            let match = open.firstIndex { item in
                let (existingQuantity, existingUnit) = base(item.quantity, item.unit)
                return key(item.name) == key(name)
                    && (existingUnit == unit || existingQuantity == nil || quantity == nil)
            }
            if match == nil, let doneIndex = done.firstIndex(where: { key($0.name) == key(name) }) {
                // Zurück aus „Erledigt“, mit der neu gebrauchten Menge
                var item = done.remove(at: doneIndex)
                item.checked = false
                item.checkedBy = nil
                item.quantity = quantity
                item.unit = unit
                item.recipeId = recipeId
                open.append(item)
                updatedIds.insert(item.id)
            } else if let index = match {
                var item = open[index]
                let (existingQuantity, _) = base(item.quantity, item.unit)
                if let quantity, let existingQuantity {
                    item.quantity = existingQuantity + quantity
                    item.unit = unit
                } else if let quantity {
                    item.quantity = quantity
                    item.unit = unit
                }
                if item.recipeId != recipeId { item.recipeId = nil }
                guard item != open[index] else { continue }
                open[index] = item
                if !insertedIds.contains(item.id) { updatedIds.insert(item.id) }
            } else {
                let item = ShoppingItem(
                    householdId: householdId,
                    name: name,
                    quantity: quantity,
                    unit: unit,
                    aisle: ingredient.aisle ?? Aisle.guess(for: name),
                    recipeId: recipeId
                )
                open.append(item)
                insertedIds.insert(item.id)
            }
        }

        return Result(
            updates: open.filter { updatedIds.contains($0.id) },
            inserts: open.filter { insertedIds.contains($0.id) }
        )
    }
}

// MARK: - Wochenplan

/// Mahlzeiten eines Tages. Mittag- und Abendessen gibt es immer, Frühstück bei Bedarf.
enum Meal: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case fruehstueck, mittag, abend

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fruehstueck: "Frühstück"
        case .mittag: "Mittagessen"
        case .abend: "Abendessen"
        }
    }

    /// Kurz für Metazeilen und Auswahl: „Frühstück“, „Mittag“, „Abend“
    var short: String {
        switch self {
        case .fruehstueck: "Frühstück"
        case .mittag: "Mittag"
        case .abend: "Abend"
        }
    }

    /// Welche Mahlzeit gemeint ist, wenn jemand „heute“ sagt
    static func next(after date: Date = .now) -> Meal {
        PlanCalendar.calendar.component(.hour, from: date) < 14 ? .mittag : .abend
    }
}

struct MealPlanEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    /// Postgres-`date`, z. B. „2026-10-26“
    var day: String
    var recipeId: UUID
    var servings: Int
    var note: String?
    var meal: Meal
    /// Reihenfolge der Gänge innerhalb der Mahlzeit
    var position: Int

    init(id: UUID = UUID(), householdId: UUID, day: String, recipeId: UUID, servings: Int, note: String? = nil, meal: Meal = .abend, position: Int = 0) {
        self.id = id
        self.householdId = householdId
        self.day = day
        self.recipeId = recipeId
        self.servings = servings
        self.note = note
        self.meal = meal
        self.position = position
    }

    enum CodingKeys: String, CodingKey {
        case id, day, servings, note, meal, position
        case householdId = "household_id"
        case recipeId = "recipe_id"
    }
}

extension MealPlanEntry {
    /// Auf einen anderen Tag oder in eine andere Mahlzeit verschieben. Dort kommt der Eintrag als letzter
    /// Gang ans Ende, damit nichts Geplantes überschrieben wird.
    func moved(toDay day: String, meal: Meal? = nil, among entries: [MealPlanEntry]) -> MealPlanEntry {
        var moved = self
        moved.day = day
        moved.meal = meal ?? self.meal
        let others = entries.filter { $0.id != id && $0.day == day && $0.meal == moved.meal }
        moved.position = (others.map(\.position).max() ?? -1) + 1
        return moved
    }
}

/// Wochen beginnen montags, Tage werden als „yyyy-MM-dd“ in lokaler Zeit gespeichert.
enum PlanCalendar {
    static var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.locale = Locale(identifier: "de_DE")
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        return c
    }

    static func startOfWeek(containing date: Date) -> Date {
        let c = calendar
        return c.date(from: c.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))!
    }

    static func days(ofWeekStarting start: Date) -> [Date] {
        (0..<7).map { calendar.date(byAdding: .day, value: $0, to: start)! }
    }

    static func key(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func weekNumber(of date: Date) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    /// „2026-10-27“ → Mittag dieses Tages in lokaler Zeit; nil bei ungültigem Format
    static func date(forKey key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2], hour: 12))
    }
}

// MARK: - Eigene Abteilungen

/// Eine Abteilung, die der Haushalt per Ziehen festgelegt hat. Gilt für alle künftigen Einträge mit diesem Namen.
struct AislePreference: Codable, Hashable, Sendable {
    var householdId: UUID
    /// `ShoppingMerge.key` des Namens
    var nameKey: String
    var aisle: Aisle
    /// Eigene Kategorie, wenn dorthin gezogen
    var categoryId: UUID?

    enum CodingKeys: String, CodingKey {
        case aisle
        case householdId = "household_id"
        case nameKey = "name_key"
        case categoryId = "category_id"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(householdId, forKey: .householdId)
        try c.encode(nameKey, forKey: .nameKey)
        try c.encode(aisle, forKey: .aisle)
        try c.encode(categoryId, forKey: .categoryId) // auch null schreiben
    }
}

extension ShoppingMerge {
    /// Eigene Abteilungen des Haushalts gehen vor Rezept, KI und Stichwort-Raten.
    static func applyPreferences(_ preferences: [String: AislePreference], to ingredients: [Ingredient]) -> [Ingredient] {
        guard !preferences.isEmpty else { return ingredients }
        return ingredients.map { ingredient in
            var ingredient = ingredient
            if let preference = preferences[key(ingredient.name)] { ingredient.aisle = preference.aisle }
            return ingredient
        }
    }

    /// Neue Einträge in die gemerkte eigene Kategorie legen
    static func applyCategories(_ preferences: [String: AislePreference], to inserts: [ShoppingItem]) -> [ShoppingItem] {
        inserts.map { item in
            var item = item
            if let id = preferences[key(item.name)]?.categoryId { item.categoryId = id }
            return item
        }
    }
}

