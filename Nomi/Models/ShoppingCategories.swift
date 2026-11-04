import Foundation

/// Eine Kategorie der Einkaufsliste: eine feste Abteilung oder eine eigene des Haushalts.
enum CategoryKey: Hashable, Sendable {
    case aisle(Aisle)
    case custom(UUID)

    /// So steht der Schlüssel in `shopping_stores.category_order`
    var raw: String {
        switch self {
        case .aisle(let aisle): "aisle:\(aisle.rawValue)"
        case .custom(let id): id.uuidString.lowercased()
        }
    }

    init?(raw: String) {
        if raw.hasPrefix("aisle:") {
            guard let aisle = Aisle(rawValue: String(raw.dropFirst(6))) else { return nil }
            self = .aisle(aisle)
        } else if let id = UUID(uuidString: raw) {
            self = .custom(id)
        } else {
            return nil
        }
    }
}

struct ShoppingCategory: Identifiable, Hashable, Sendable {
    var key: CategoryKey
    var name: String
    var id: CategoryKey { key }

    var isCustom: Bool {
        if case .custom = key { true } else { false }
    }
}

/// Zeile in `shopping_categories`: mit `aisle` ein neuer Name für eine feste Abteilung, ohne eine eigene Kategorie.
struct CategoryRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var name: String
    var aisle: Aisle?
    var createdAt: Date?

    init(id: UUID = UUID(), householdId: UUID, name: String, aisle: Aisle? = nil, createdAt: Date? = nil) {
        self.id = id
        self.householdId = householdId
        self.name = name
        self.aisle = aisle
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, name, aisle
        case householdId = "household_id"
        case createdAt = "created_at"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(householdId, forKey: .householdId)
        try c.encode(name, forKey: .name)
        try c.encode(aisle, forKey: .aisle)
    }
}

/// Ein Supermarkt mit eigener Laufreihenfolge der Kategorien.
struct ShoppingStoreRecord: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var householdId: UUID
    var name: String
    var categoryOrder: [String]
    var position: Int

    init(id: UUID = UUID(), householdId: UUID, name: String, categoryOrder: [String] = [], position: Int = 0) {
        self.id = id
        self.householdId = householdId
        self.name = name
        self.categoryOrder = categoryOrder
        self.position = position
    }

    enum CodingKeys: String, CodingKey {
        case id, name, position
        case householdId = "household_id"
        case categoryOrder = "category_order"
    }
}

/// Alle Kategorien eines Haushalts mit ihren Namen, und wie sie in einem Supermarkt sortiert sind.
struct CategoryCatalog: Sendable {
    /// Feste Abteilungen in Standard-Reihenfolge, danach eigene in der Reihenfolge ihres Anlegens
    let categories: [ShoppingCategory]
    let records: [CategoryRecord]

    init(records: [CategoryRecord] = []) {
        self.records = records
        let renamed = Dictionary(records.compactMap { r in r.aisle.map { ($0, r.name) } }) { first, _ in first }
        let fixed = Aisle.allCases.map { ShoppingCategory(key: .aisle($0), name: renamed[$0] ?? $0.title) }
        let custom = records
            .filter { $0.aisle == nil }
            .sorted { ($0.createdAt ?? .distantFuture, $0.name) < ($1.createdAt ?? .distantFuture, $1.name) }
            .map { ShoppingCategory(key: .custom($0.id), name: $0.name) }
        categories = fixed + custom
    }

    func name(for key: CategoryKey) -> String {
        categories.first { $0.key == key }?.name ?? {
            if case .aisle(let aisle) = key { return aisle.title }
            return "Sonstiges"
        }()
    }

    func contains(_ key: CategoryKey) -> Bool {
        categories.contains { $0.key == key }
    }

    /// Zeile, die eine feste Abteilung umbenennt
    func record(for aisle: Aisle) -> CategoryRecord? {
        records.first { $0.aisle == aisle }
    }

    /// Reihenfolge für einen Supermarkt. Was dort (noch) nicht einsortiert ist – z. B. eine neue eigene
    /// Kategorie –, kommt ans Ende, in Standard-Reihenfolge. Ohne Supermarkt gilt die Standard-Reihenfolge.
    func ordered(for store: ShoppingStoreRecord?) -> [ShoppingCategory] {
        guard let store else { return categories }
        var seen = Set<CategoryKey>()
        let listed = store.categoryOrder
            .compactMap(CategoryKey.init(raw:))
            .compactMap { key in categories.first { $0.key == key } }
            .filter { seen.insert($0.key).inserted }
        return listed + categories.filter { !seen.contains($0.key) }
    }
}

extension ShoppingItem {
    /// Eigene Kategorie, wenn gesetzt, sonst die feste Abteilung
    var categoryKey: CategoryKey {
        categoryId.map(CategoryKey.custom) ?? .aisle(aisle)
    }
}

enum ShoppingGrouping {
    /// Einträge nach Kategorie in der gegebenen Reihenfolge. Zeigt ein Eintrag auf eine gelöschte
    /// eigene Kategorie, gilt seine feste Abteilung.
    static func group(_ items: [ShoppingItem], order: [ShoppingCategory]) -> [(category: ShoppingCategory, items: [ShoppingItem])] {
        let known = Set(order.map(\.key))
        let groups = Dictionary(grouping: items) { item in
            known.contains(item.categoryKey) ? item.categoryKey : .aisle(item.aisle)
        }
        return order.compactMap { category in
            groups[category.key].map { (category, $0.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }) }
        }
    }
}

/// Umsortieren in einer flachen Liste aus Überschriften und Einträgen (Indizes wie bei `onMove`).
enum CategoryMove {
    /// Ziel für einen Eintrag, der von `source` nach `destination` gezogen wird: die nächste Überschrift
    /// darüber, ganz oben die erste.
    static func target<Key>(movingFrom source: Int, to destination: Int, headers: [Int: Key]) -> Key? {
        let above = headers.filter { $0.key < destination && $0.key != source }.max { $0.key < $1.key }
        return above?.value ?? headers.min { $0.key < $1.key }?.value
    }
}
