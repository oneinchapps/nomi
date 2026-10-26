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
    private(set) var hasLoaded = false
    var error: String?

    init(householdId: UUID, userId: UUID) {
        self.householdId = householdId
        self.userId = userId
    }

    var openItems: [ShoppingItem] { items.filter { !$0.checked } }
    var checkedItems: [ShoppingItem] { items.filter(\.checked) }

    /// Offene Einträge nach Abteilung, in der Reihenfolge des Wegs durch den Laden.
    var openByAisle: [(aisle: Aisle, items: [ShoppingItem])] {
        let groups = Dictionary(grouping: openItems, by: \.aisle)
        return Aisle.allCases.compactMap { aisle in
            groups[aisle].map { (aisle, $0.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }) }
        }
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
            (self.items, self.staples) = try await (items, staples)
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
            group.addTask {
                await observeTable("staple_items", householdId: self.householdId) { [weak self] in
                    await self?.load()
                }
            }
        }
    }

    // MARK: - Liste

    /// Freitext wie „2 l Milch“ oder „Brot“.
    func addLine(_ line: String) async {
        guard let ingredient = IngredientParser.parse(line) else { return }
        await add([ingredient], recipeId: nil)
    }

    /// Fügt Zutaten hinzu und führt sie mit vorhandenen offenen Einträgen zusammen.
    @discardableResult
    func add(_ ingredients: [Ingredient], recipeId: UUID?) async -> ShoppingChange {
        let result = ShoppingMerge.merge(ingredients, recipeId: recipeId, into: items, householdId: householdId)
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

    // MARK: - Intern

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
