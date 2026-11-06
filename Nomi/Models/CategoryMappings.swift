import Foundation

/// Gemerkte Zuordnungen „Artikel → Kategorie“ (Tabelle `aisle_preferences`), aufbereitet fürs Zahnrad.
enum CategoryMappings {
    struct Mapping: Identifiable, Hashable {
        /// `ShoppingMerge.key` des Namens
        let nameKey: String
        let name: String
        let key: CategoryKey
        var id: String { nameKey }
    }

    /// Kategorie einer Zuordnung; eine gelöschte eigene Kategorie fällt auf die feste Abteilung zurück
    static func key(of preference: AislePreference, known: Set<CategoryKey>) -> CategoryKey {
        if let id = preference.categoryId, known.contains(.custom(id)) { return .custom(id) }
        return .aisle(preference.aisle)
    }

    /// Gespeichert ist nur der kleingeschriebene Name. Steht der Artikel irgendwo in Originalschreibweise
    /// (Liste, Standardartikel, Rezepte), nehmen wir die, sonst Wortanfänge groß.
    static func displayName(for nameKey: String, knownNames: [String]) -> String {
        if let known = knownNames.first(where: { ShoppingMerge.key($0) == nameKey }) {
            return known.trimmingCharacters(in: .whitespaces)
        }
        return nameKey.split(separator: " ").map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined(separator: " ")
    }

    /// Nach Kategorie in Laufreihenfolge, darin alphabetisch; `query` sucht im Namen (ohne Groß/klein).
    static func grouped(
        _ preferences: [AislePreference],
        order: [ShoppingCategory],
        knownNames: [String],
        query: String = ""
    ) -> [(category: ShoppingCategory, mappings: [Mapping])] {
        let known = Set(order.map(\.key))
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        let mappings = preferences
            .map { Mapping(nameKey: $0.nameKey, name: displayName(for: $0.nameKey, knownNames: knownNames), key: key(of: $0, known: known)) }
            .filter { needle.isEmpty || $0.nameKey.contains(needle) }
        let byKey = Dictionary(grouping: mappings, by: \.key)
        return order.compactMap { category in
            byKey[category.key].map { (category, $0.sorted { $0.name.localizedCompare($1.name) == .orderedAscending }) }
        }
    }
}
