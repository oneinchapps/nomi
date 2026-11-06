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

    /// Alle Abteilungen mit Einträgen, in der Laufreihenfolge des Supermarkts
    static func pages(_ items: [ShoppingItem], order: [ShoppingCategory]) -> [Page] {
        ShoppingGrouping.group(items, order: order).map { Page(category: $0.category, items: $0.items) }
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
