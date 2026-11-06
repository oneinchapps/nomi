import Foundation

/// Logik des Live-Einkaufsmodus: eine Seite pro Abteilung, Fortschritt und Abgleich zu zweit.
enum LiveShopping {
    struct Page: Identifiable {
        let category: ShoppingCategory
        /// Offene und abgehakte Einträge in fester Reihenfolge, damit beim Abhaken nichts springt
        let items: [ShoppingItem]

        var id: String { category.key.raw }
        var openCount: Int { items.filter { !$0.checked }.count }
    }

    /// Abteilungen in der Laufreihenfolge des Supermarkts. Mit `startedWith` nur die, in denen beim Start
    /// etwas offen war oder jetzt etwas offen ist; schon erledigte Abteilungen bleiben weg, und eine
    /// Seite verschwindet nicht, sobald man sie abgehakt hat.
    static func pages(_ items: [ShoppingItem], order: [ShoppingCategory], startedWith: Set<CategoryKey>? = nil) -> [Page] {
        let all = ShoppingGrouping.group(items, order: order).map { Page(category: $0.category, items: $0.items) }
        guard let startedWith else { return all }
        return all.filter { $0.openCount > 0 || startedWith.contains($0.category.key) }
    }

    /// Abteilungen mit Offenem, gemerkt beim Start des Modus
    static func openCategories(_ items: [ShoppingItem], order: [ShoppingCategory]) -> Set<CategoryKey> {
        Set(pages(items, order: order).filter { $0.openCount > 0 }.map(\.category.key))
    }

    /// Was auf einer Seite zu sehen ist. Ist „Erledigt“ ausgeblendet, bleibt gerade von der anderen Person
    /// Abgehaktes trotzdem stehen, solange es aufleuchtet – sonst verschwände es spurlos.
    static func visibleItems(_ page: Page, hidesCart: Bool, highlighted: Set<UUID>) -> [ShoppingItem] {
        guard hidesCart else { return page.items }
        return page.items.filter { !$0.checked || highlighted.contains($0.id) }
    }

    /// Nächste Seite nach `index`, auf der noch etwas offen ist; sonst nil
    static func nextOpenPage(after index: Int, in pages: [Page]) -> Int? {
        pages.indices.first { $0 > index && pages[$0].openCount > 0 }
    }

    /// Einträge, die seit dem letzten Stand von jemand anderem abgehakt wurden
    static func newlyCheckedByOthers(old: [ShoppingItem], new: [ShoppingItem], me: UUID) -> Set<UUID> {
        let wasChecked = Dictionary(old.map { ($0.id, $0.checked) }) { first, _ in first }
        return Set(new.filter { item in
            item.checked && wasChecked[item.id] == false && item.checkedBy != nil && item.checkedBy != me
        }.map(\.id))
    }

    /// Eigene Haken, die noch nicht gespeichert sind, gehen vor dem Server-Stand.
    /// Sonst springt ein Haken kurz zurück, wenn ein Abgleich vor dem Speichern ankommt.
    static func applyPending(_ pending: [UUID: PendingCheck], to items: [ShoppingItem]) -> [ShoppingItem] {
        guard !pending.isEmpty else { return items }
        return items.map { item in
            guard let check = pending[item.id] else { return item }
            var item = item
            item.checked = check.checked
            item.checkedBy = check.checkedBy
            return item
        }
    }

    struct PendingCheck: Equatable {
        var checked: Bool
        var checkedBy: UUID?
    }
}
