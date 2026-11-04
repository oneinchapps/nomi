import Foundation
import Observation
import Supabase

/// Gemeinsame Einkaufsliste und Standardartikel. Änderungen der anderen Person kommen per Realtime.
@Observable
final class ShoppingStore {
    let householdId: UUID
    let userId: UUID

    private(set) var items: [ShoppingItem] = []
    private(set) var staples: [StapleItem] = []
    /// Per Ziehen festgelegte Abteilungen, nach `ShoppingMerge.key`
    private(set) var aislePreferences: [String: AislePreference] = [:]
    /// Umbenannte und eigene Kategorien
    private(set) var categories = CategoryCatalog()
    /// Supermärkte mit eigener Reihenfolge
    private(set) var stores: [ShoppingStoreRecord] = []
    /// Wo diese Person gerade einkauft – nur auf diesem Gerät
    var activeStoreId: UUID? {
        didSet { UserDefaults.standard.set(activeStoreId?.uuidString, forKey: activeStoreKey) }
    }
    private(set) var hasLoaded = false
    var error: String?
    /// Selbst eingetippte Artikel mit Anzahl – für die Vorschläge beim Tippen
    private var history: [String: Int]

    init(householdId: UUID, userId: UUID) {
        self.householdId = householdId
        self.userId = userId
        history = ShoppingHistory.load(householdId: householdId)
        activeStoreId = UserDefaults.standard.string(forKey: "activeStore.\(householdId.uuidString)").flatMap(UUID.init)
    }

    private var activeStoreKey: String { "activeStore.\(householdId.uuidString)" }

    var openItems: [ShoppingItem] { items.filter { !$0.checked } }
    var checkedItems: [ShoppingItem] { items.filter(\.checked) }

    /// Der gewählte Supermarkt; ist er gelöscht oder nichts gewählt, der erste
    var activeStore: ShoppingStoreRecord? {
        stores.first { $0.id == activeStoreId } ?? stores.first
    }

    /// Kategorien in der Laufreihenfolge des aktiven Supermarkts
    var categoryOrder: [ShoppingCategory] {
        categories.ordered(for: activeStore)
    }

    /// Offene Einträge nach Kategorie, in der Reihenfolge des Wegs durch den Laden.
    var openByCategory: [(category: ShoppingCategory, items: [ShoppingItem])] {
        ShoppingGrouping.group(openItems, order: categoryOrder)
    }

    /// Vorschläge für das Eingabefeld: euer Verlauf, Standardartikel, die Liste, Rezeptzutaten, Grundwortschatz
    func suggestions(for input: String, recipes: [Recipe]) -> [ShoppingSuggestion] {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        let candidates = ShoppingSuggestions.candidates(
            history: history,
            staples: staples.map(\.name),
            listItems: items.map(\.name),
            recipeIngredients: recipes.flatMap { $0.ingredients.map(\.name) }
        )
        return ShoppingSuggestions.suggestions(for: input, candidates: candidates)
    }

    func isOnList(_ staple: StapleItem) -> Bool {
        openItems.contains { ShoppingMerge.key($0.name) == ShoppingMerge.key(staple.name) }
    }

    // MARK: - Laden

    func load() async {
        do {
            async let items: [ShoppingItem] = supabase
                .from("shopping_items")
                .select()
                .eq("household_id", value: householdId)
                .order("created_at")
                .execute()
                .value
            async let staples: [StapleItem] = supabase
                .from("staple_items")
                .select()
                .eq("household_id", value: householdId)
                .order("position")
                .execute()
                .value
            async let preferences: [AislePreference]? = try? supabase
                .from("aisle_preferences")
                .select()
                .eq("household_id", value: householdId)
                .execute()
                .value
            async let categoryRecords: [CategoryRecord]? = try? supabase
                .from("shopping_categories")
                .select()
                .eq("household_id", value: householdId)
                .execute()
                .value
            async let stores: [ShoppingStoreRecord]? = try? supabase
                .from("shopping_stores")
                .select()
                .eq("household_id", value: householdId)
                .order("position")
                .order("created_at")
                .execute()
                .value
            (self.items, self.staples) = try await (items, staples)
            // Ohne die Zusätze geht die Liste trotzdem – dann gelten Raten und Standard-Reihenfolge
            if let preferences = await preferences {
                aislePreferences = Dictionary(preferences.map { ($0.nameKey, $0) }) { _, last in last }
            }
            if let categoryRecords = await categoryRecords {
                categories = CategoryCatalog(records: categoryRecords)
            }
            if let stores = await stores {
                self.stores = stores
            }
            error = nil
        } catch {
            self.error = userMessage(for: error)
        }
        hasLoaded = true
    }

    func observeChanges() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await observeTable("shopping_items", householdId: self.householdId) { [weak self] in
                    await self?.load()
                }
            }
            for table in ["staple_items", "shopping_categories", "shopping_stores"] {
                group.addTask {
                    await observeTable(table, householdId: self.householdId) { [weak self] in
                        await self?.load()
                    }
                }
            }
        }
    }

    // MARK: - Liste

    /// Freitext wie „2 l Milch“ oder „Brot“.
    func addLine(_ line: String) async {
        guard let ingredient = IngredientParser.parse(line) else { return }
        ShoppingHistory.record(ingredient.name, householdId: householdId)
        history = ShoppingHistory.load(householdId: householdId)
        await add([ingredient], recipeId: nil)
    }

    /// Fügt Zutaten hinzu und führt sie mit vorhandenen offenen Einträgen zusammen.
    @discardableResult
    func add(_ ingredients: [Ingredient], recipeId: UUID?) async -> ShoppingChange {
        let ingredients = ShoppingMerge.applyPreferences(aislePreferences, to: ingredients)
        var result = ShoppingMerge.merge(ingredients, recipeId: recipeId, into: items, householdId: householdId)
        result.inserts = ShoppingMerge.applyCategories(aislePreferences, to: result.inserts)
        guard !result.inserts.isEmpty || !result.updates.isEmpty else { return ShoppingChange() }
        let previous = result.updates.compactMap { update in items.first { $0.id == update.id } }
        apply(result.updates + result.inserts)
        await write { try await supabase.from("shopping_items").upsert(result.updates + result.inserts).execute() }
        return ShoppingChange(insertedIds: result.inserts.map(\.id), previous: previous)
    }

    /// Macht eine Änderung rückgängig: Neue Einträge verschwinden, zusammengeführte bekommen ihre alte Menge.
    /// Was inzwischen abgehakt wurde, bleibt, wie es ist.
    func revert(_ change: ShoppingChange) async {
        let removable = change.insertedIds.filter { id in items.first { $0.id == id }?.checked != true }
        let restore = change.previous.filter { old in items.first { $0.id == old.id }?.checked != true }
        items.removeAll { removable.contains($0.id) }
        apply(restore)
        await write {
            if !removable.isEmpty { try await supabase.from("shopping_items").delete().in("id", values: removable).execute() }
            if !restore.isEmpty { try await supabase.from("shopping_items").upsert(restore).execute() }
        }
    }

    func toggle(_ item: ShoppingItem) async {
        var changed = item
        changed.checked.toggle()
        changed.checkedBy = changed.checked ? userId : nil
        apply([changed])
        await write {
            try await supabase.from("shopping_items")
                .update(CheckUpdate(checked: changed.checked, checkedBy: changed.checkedBy))
                .eq("id", value: item.id)
                .execute()
        }
    }

    /// In eine andere Kategorie ziehen. Gilt für alle offenen Einträge mit diesem Namen und wird
    /// für den Haushalt gemerkt, damit der Artikel künftig gleich dort landet.
    func move(_ item: ShoppingItem, to target: CategoryKey) async {
        let key = ShoppingMerge.key(item.name)
        let moved = items
            .filter { !$0.checked && ShoppingMerge.key($0.name) == key && $0.categoryKey != target }
            .map { old in
                var changed = old
                switch target {
                case .aisle(let aisle): changed.aisle = aisle; changed.categoryId = nil
                case .custom(let id): changed.categoryId = id
                }
                return changed
            }
        guard let first = moved.first else { return }
        apply(moved)
        let preference = AislePreference(householdId: householdId, nameKey: key, aisle: first.aisle, categoryId: first.categoryId)
        aislePreferences[key] = preference
        await write {
            try await supabase.from("shopping_items")
                .update(CategoryUpdate(aisle: first.aisle, categoryId: first.categoryId))
                .in("id", values: moved.map(\.id))
                .execute()
            try await supabase.from("aisle_preferences").upsert(preference).execute()
        }
    }

    func delete(_ item: ShoppingItem) async {
        items.removeAll { $0.id == item.id }
        await write { try await supabase.from("shopping_items").delete().eq("id", value: item.id).execute() }
    }

    func clearChecked() async {
        let ids = checkedItems.map(\.id)
        guard !ids.isEmpty else { return }
        items.removeAll(where: \.checked)
        await write { try await supabase.from("shopping_items").delete().in("id", values: ids).execute() }
    }

    // MARK: - Standardartikel

    func addStaple(_ line: String) async {
        guard let ingredient = IngredientParser.parse(line) else { return }
        let staple = StapleItem(
            householdId: householdId,
            name: ingredient.name,
            quantity: ingredient.quantity,
            unit: ingredient.unit,
            aisle: ingredient.aisle ?? .sonstiges,
            position: (staples.map(\.position).max() ?? -1) + 1
        )
        staples.append(staple)
        await write { try await supabase.from("staple_items").insert(staple).execute() }
    }

    func deleteStaple(_ staple: StapleItem) async {
        staples.removeAll { $0.id == staple.id }
        await write { try await supabase.from("staple_items").delete().eq("id", value: staple.id).execute() }
    }

    func addStapleToList(_ staple: StapleItem) async {
        await add([staple.ingredient], recipeId: nil)
    }

    // MARK: - Supermärkte

    func addStore(named name: String) async {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        // Neuer Supermarkt startet mit der Reihenfolge, die gerade gilt
        let store = ShoppingStoreRecord(
            householdId: householdId,
            name: String(name.prefix(40)),
            categoryOrder: categoryOrder.map(\.key.raw),
            position: (stores.map(\.position).max() ?? -1) + 1
        )
        stores.append(store)
        if stores.count == 1 { activeStoreId = store.id }
        await write { try await supabase.from("shopping_stores").insert(store).execute() }
    }

    func renameStore(_ store: ShoppingStoreRecord, to name: String) async {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, let index = stores.firstIndex(where: { $0.id == store.id }) else { return }
        stores[index].name = String(name.prefix(40))
        await write {
            try await supabase.from("shopping_stores").update(["name": stores[index].name]).eq("id", value: store.id).execute()
        }
    }

    func deleteStore(_ store: ShoppingStoreRecord) async {
        stores.removeAll { $0.id == store.id }
        if activeStoreId == store.id { activeStoreId = stores.first?.id }
        await write { try await supabase.from("shopping_stores").delete().eq("id", value: store.id).execute() }
    }

    /// Neue Laufreihenfolge eines Supermarkts
    func reorder(_ store: ShoppingStoreRecord, to order: [CategoryKey]) async {
        guard let index = stores.firstIndex(where: { $0.id == store.id }) else { return }
        stores[index].categoryOrder = order.map(\.raw)
        await write {
            try await supabase.from("shopping_stores")
                .update(["category_order": stores[index].categoryOrder])
                .eq("id", value: store.id)
                .execute()
        }
    }

    // MARK: - Kategorien

    func addCategory(named name: String) async {
        let name = name.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        let record = CategoryRecord(householdId: householdId, name: String(name.prefix(40)), createdAt: .now)
        categories = CategoryCatalog(records: categoryRecords + [record])
        await write { try await supabase.from("shopping_categories").insert(record).execute() }
    }

    /// Umbenennen; eine feste Abteilung mit leerem Namen bekommt ihren Standardnamen zurück.
    func renameCategory(_ key: CategoryKey, to name: String) async {
        let name = String(name.trimmingCharacters(in: .whitespaces).prefix(40))
        switch key {
        case .custom(let id):
            guard !name.isEmpty else { return }
            categories = CategoryCatalog(records: categoryRecords.map { $0.id == id ? renamed($0, name) : $0 })
            await write { try await supabase.from("shopping_categories").update(["name": name]).eq("id", value: id).execute() }
        case .aisle(let aisle):
            let existing = categories.record(for: aisle)
            if name.isEmpty || name == aisle.title {
                guard let existing else { return }
                categories = CategoryCatalog(records: categoryRecords.filter { $0.id != existing.id })
                await write { try await supabase.from("shopping_categories").delete().eq("id", value: existing.id).execute() }
            } else if let existing {
                categories = CategoryCatalog(records: categoryRecords.map { $0.id == existing.id ? renamed($0, name) : $0 })
                await write { try await supabase.from("shopping_categories").update(["name": name]).eq("id", value: existing.id).execute() }
            } else {
                let record = CategoryRecord(householdId: householdId, name: name, aisle: aisle)
                categories = CategoryCatalog(records: categoryRecords + [record])
                await write { try await supabase.from("shopping_categories").insert(record).execute() }
            }
        }
    }

    /// Eigene Kategorie löschen; ihre Einträge kommen zurück in ihre feste Abteilung (Datenbank: on delete set null).
    func deleteCategory(_ id: UUID) async {
        categories = CategoryCatalog(records: categoryRecords.filter { $0.id != id })
        for index in items.indices where items[index].categoryId == id { items[index].categoryId = nil }
        await write { try await supabase.from("shopping_categories").delete().eq("id", value: id).execute() }
    }

    private var categoryRecords: [CategoryRecord] { categories.records }

    private func renamed(_ record: CategoryRecord, _ name: String) -> CategoryRecord {
        var record = record
        record.name = name
        return record
    }

    // MARK: - Intern

    private struct CategoryUpdate: Encodable {
        let aisle: Aisle
        let categoryId: UUID?

        enum CodingKeys: String, CodingKey {
            case aisle
            case categoryId = "category_id"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(aisle, forKey: .aisle)
            try c.encode(categoryId, forKey: .categoryId) // auch null schreiben
        }
    }

    private struct CheckUpdate: Encodable {
        let checked: Bool
        let checkedBy: UUID?

        enum CodingKeys: String, CodingKey {
            case checked
            case checkedBy = "checked_by"
        }

        func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            try c.encode(checked, forKey: .checked)
            try c.encode(checkedBy, forKey: .checkedBy) // auch null schreiben
        }
    }

    /// Lokal sofort anzeigen, der Server-Stand kommt per Realtime nach.
    private func apply(_ changed: [ShoppingItem]) {
        for item in changed {
            if let index = items.firstIndex(where: { $0.id == item.id }) {
                items[index] = item
            } else {
                var item = item
                item.createdAt = item.createdAt ?? .now
                items.append(item)
            }
        }
    }

    private func write(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            error = nil
        } catch {
            self.error = userMessage(for: error)
            await load()
        }
    }
}
