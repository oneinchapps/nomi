import Foundation
import Testing
@testable import nomi

struct CategoryMappingsTests {
    let household = UUID()
    let order = CategoryCatalog().ordered(for: nil)

    func preference(_ key: String, _ aisle: Aisle, category: UUID? = nil) -> AislePreference {
        AislePreference(householdId: household, nameKey: key, aisle: aisle, categoryId: category)
    }

    @Test func namenInOriginalschreibweiseSonstWortanfaengeGross() {
        #expect(CategoryMappings.displayName(for: "vesper käse", knownNames: ["Milch", "Vesper  Käse"]) == "Vesper  Käse")
        #expect(CategoryMappings.displayName(for: "rote zwiebeln", knownNames: []) == "Rote Zwiebeln")
    }

    @Test func gruppiertInLaufreihenfolgeAlphabetischUndDurchsuchbar() {
        let prefs = [preference("vesper käse", .kuehlregal), preference("hafermilch", .kuehlregal), preference("laugenbrezel", .backwaren)]
        let groups = CategoryMappings.grouped(prefs, order: order, knownNames: [])
        #expect(groups.map(\.category.key) == [.aisle(.backwaren), .aisle(.kuehlregal)])
        #expect(groups[1].mappings.map(\.name) == ["Hafermilch", "Vesper Käse"])
        let found = CategoryMappings.grouped(prefs, order: order, knownNames: [], query: "KÄSE")
        #expect(found.flatMap(\.mappings).map(\.nameKey) == ["vesper käse"])
    }

    @Test func geloeschteEigeneKategorieFaelltAufAbteilungZurueck() {
        let bio = CategoryRecord(householdId: household, name: "Bio-Ecke", createdAt: .now)
        let withBio = CategoryCatalog(records: [bio]).ordered(for: nil)
        let pref = preference("tofu", .kuehlregal, category: bio.id)
        #expect(CategoryMappings.key(of: pref, known: Set(withBio.map(\.key))) == .custom(bio.id))
        #expect(CategoryMappings.key(of: pref, known: Set(order.map(\.key))) == .aisle(.kuehlregal))
    }
}
