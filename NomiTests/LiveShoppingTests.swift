import Foundation
import Testing
@testable import nomi

struct LiveShoppingTests {
    let household = UUID()
    let me = UUID()
    let sam = UUID()
    let order = CategoryCatalog().ordered(for: nil)

    func item(_ name: String, _ aisle: Aisle, checked: Bool = false, by: UUID? = nil, at seconds: TimeInterval = 0) -> ShoppingItem {
        ShoppingItem(householdId: household, name: name, aisle: aisle, checked: checked, checkedBy: by,
                     createdAt: Date(timeIntervalSince1970: seconds))
    }

    @Test func eineSeiteProAbteilungMitAbgehaktemInFesterReihenfolge() {
        let items = [
            item("Milch", .kuehlregal, at: 1),
            item("Bananen", .obstGemuese, at: 2),
            item("Joghurt", .kuehlregal, checked: true, by: me, at: 3),
            item("Käse", .kuehlregal, at: 4),
        ]
        let pages = LiveShopping.pages(items, order: order)
        #expect(pages.map(\.category.key) == [.aisle(.obstGemuese), .aisle(.kuehlregal)])
        // Abgehakter Joghurt bleibt an seinem Platz statt ans Ende zu rutschen
        #expect(pages[1].items.map(\.name) == ["Milch", "Joghurt", "Käse"])
        #expect(pages[1].openCount == 2)
    }

    @Test func naechsteSeiteUeberspringtErledigteAbteilungen() {
        let pages = LiveShopping.pages([
            item("Bananen", .obstGemuese),
            item("Brot", .backwaren, checked: true),
            item("Milch", .kuehlregal),
        ], order: order)
        #expect(pages.count == 3)
        #expect(LiveShopping.nextOpenPage(after: 0, in: pages) == 2)
        #expect(LiveShopping.nextOpenPage(after: 2, in: pages) == nil)
    }

    @Test func erkenntNurHakenDerAnderenPerson() {
        let milch = item("Milch", .kuehlregal)
        let brot = item("Brot", .backwaren)
        let eier = item("Eier", .kuehlregal, checked: true, by: sam)
        var milchNeu = milch; milchNeu.checked = true; milchNeu.checkedBy = sam
        var brotNeu = brot; brotNeu.checked = true; brotNeu.checkedBy = me
        let kaffee = item("Kaffee", .getraenke, checked: true, by: sam) // neu und gleich abgehakt: kein Aufleuchten
        let found = LiveShopping.newlyCheckedByOthers(old: [milch, brot, eier], new: [milchNeu, brotNeu, eier, kaffee], me: me)
        #expect(found == [milch.id])
    }

    @Test func eigeneHakenGehenVorDemServerStand() {
        let milch = item("Milch", .kuehlregal)
        let brot = item("Brot", .backwaren, checked: true, by: sam)
        let pending: [UUID: LiveShopping.PendingCheck] = [
            milch.id: .init(checked: true, checkedBy: me),
            brot.id: .init(checked: false, checkedBy: nil),
        ]
        let result = LiveShopping.applyPending(pending, to: [milch, brot])
        #expect(result[0].checked && result[0].checkedBy == me)
        #expect(!result[1].checked && result[1].checkedBy == nil)
    }
}
