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
        // Arbeitsliste aus offenen Einträgen; abgehakte bleiben unberührt (das war ein früherer Einkauf)
        var open = existing.filter { !$0.checked }
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
            if let index = match {
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

struct MealPlanEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    /// Postgres-`date`, z. B. „2026-10-26“
    var day: String
    var recipeId: UUID
    var servings: Int
    var note: String?

    init(id: UUID = UUID(), householdId: UUID, day: String, recipeId: UUID, servings: Int, note: String? = nil) {
        self.id = id
        self.householdId = householdId
        self.day = day
        self.recipeId = recipeId
        self.servings = servings
        self.note = note
    }

    enum CodingKeys: String, CodingKey {
        case id, day, servings, note
        case householdId = "household_id"
        case recipeId = "recipe_id"
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
