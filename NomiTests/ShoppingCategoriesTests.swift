import Foundation
import Testing
@testable import nomi

struct ShoppingCategoriesTests {
    let household = UUID()

    func item(_ name: String, _ aisle: Aisle, category: UUID? = nil) -> ShoppingItem {
        ShoppingItem(householdId: household, name: name, aisle: aisle, categoryId: category)
    }

    @Test func keysRoundTrip() {
        let id = UUID()
        #expect(CategoryKey(raw: CategoryKey.aisle(.kuehlregal).raw) == .aisle(.kuehlregal))
        #expect(CategoryKey(raw: CategoryKey.custom(id).raw) == .custom(id))
        #expect(CategoryKey(raw: "aisle:gibtsnicht") == nil)
        #expect(CategoryKey(raw: "quatsch") == nil)
    }

    @Test func catalogRenamesAndAppendsOwnCategories() {
        let bio = CategoryRecord(householdId: household, name: "Bio-Ecke", createdAt: .now)
        let catalog = CategoryCatalog(records: [
            CategoryRecord(householdId: household, name: "Kühltheke", aisle: .kuehlregal),
            bio,
        ])
        #expect(catalog.categories.count == Aisle.allCases.count + 1)
        #expect(catalog.name(for: .aisle(.kuehlregal)) == "Kühltheke")
        #expect(catalog.name(for: .aisle(.backwaren)) == "Backwaren")
        #expect(catalog.categories.last?.key == .custom(bio.id))
        #expect(catalog.categories.last?.isCustom == true)
    }

    @Test func storeOrderPutsUnlistedAtTheEnd() {
        let bio = CategoryRecord(householdId: household, name: "Bio-Ecke")
        let catalog = CategoryCatalog(records: [bio])
        let store = ShoppingStoreRecord(householdId: household, name: "Rewe", categoryOrder: [
            "aisle:getraenke", bio.id.uuidString.lowercased(), "aisle:obst_gemuese", "aisle:getraenke", "unbekannt",
        ])
        let order = catalog.ordered(for: store).map(\.key)
        #expect(Array(order.prefix(3)) == [.aisle(.getraenke), .custom(bio.id), .aisle(.obstGemuese)])
        #expect(order[3] == .aisle(.backwaren))
        #expect(order.count == Aisle.allCases.count + 1)
        #expect(catalog.ordered(for: nil).first?.key == .aisle(.obstGemuese))
    }

    @Test func groupsByOwnCategoryAndFallsBackWhenItIsGone() {
        let bio = UUID()
        let catalog = CategoryCatalog(records: [CategoryRecord(id: bio, householdId: household, name: "Bio-Ecke")])
        let store = ShoppingStoreRecord(householdId: household, name: "Rewe", categoryOrder: ["\(bio)".lowercased(), "aisle:kuehlregal"])
        let items = [item("Milch", .kuehlregal), item("Bio-Eier", .kuehlregal, category: bio), item("Tofu", .kuehlregal, category: UUID())]
        let groups = ShoppingGrouping.group(items, order: catalog.ordered(for: store))
        #expect(groups.map(\.category.name) == ["Bio-Ecke", "Kühlregal"])
        #expect(groups[0].items.map(\.name) == ["Bio-Eier"])
        // Tofu zeigt auf eine gelöschte Kategorie → Kühlregal
        #expect(Set(groups[1].items.map(\.name)) == ["Milch", "Tofu"])
    }

    @Test func rememberedOwnCategoryAppliesToNewItems() {
        let bio = UUID()
        let preferences = ["eier": AislePreference(householdId: household, nameKey: "eier", aisle: .kuehlregal, categoryId: bio)]
        let inserts = ShoppingMerge.applyCategories(preferences, to: [item("Eier", .kuehlregal), item("Brot", .backwaren)])
        #expect(inserts[0].categoryId == bio)
        #expect(inserts[1].categoryId == nil)
    }
}
