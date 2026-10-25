import Foundation
import Testing
@testable import nomnom

struct ShoppingMergeTests {
    let household = UUID()
    let recipeA = UUID()
    let recipeB = UUID()

    func item(_ name: String, _ quantity: Double? = nil, _ unit: String? = nil, checked: Bool = false, recipe: UUID? = nil) -> ShoppingItem {
        ShoppingItem(householdId: household, name: name, quantity: quantity, unit: unit, aisle: Aisle.guess(for: name), checked: checked, recipeId: recipe)
    }

    func ingredient(_ name: String, _ quantity: Double? = nil, _ unit: String? = nil) -> Ingredient {
        Ingredient(name: name, quantity: quantity, unit: unit)
    }

    @Test func addsUpSameNameAndUnit() {
        let existing = [item("Mehl", 200, "g", recipe: recipeA)]
        let result = ShoppingMerge.merge([ingredient("mehl", 300, "g")], recipeId: recipeA, into: existing, householdId: household)
        #expect(result.inserts.isEmpty)
        #expect(result.updates.count == 1)
        #expect(result.updates[0].quantity == 500)
        #expect(result.updates[0].id == existing[0].id)
        #expect(result.updates[0].recipeId == recipeA)
    }

    @Test func convertsKilogramsAndShowsThemNicely() {
        let existing = [item("Kartoffeln", 500, "g")]
        let result = ShoppingMerge.merge([ingredient("Kartoffeln", 1, "kg")], recipeId: nil, into: existing, householdId: household)
        #expect(result.updates.first?.quantity == 1500)
        #expect(result.updates.first?.unit == "g")
        #expect(result.updates.first?.amountText == "1,5 kg")
    }

    @Test func keepsDifferentUnitsApart() {
        let existing = [item("Olivenöl", 2, "EL")]
        let result = ShoppingMerge.merge([ingredient("Olivenöl", 100, "ml")], recipeId: nil, into: existing, householdId: household)
        #expect(result.updates.isEmpty)
        #expect(result.inserts.count == 1)
    }

    @Test func entryWithoutQuantityMatchesEverything() {
        // „Salz“ steht schon drauf → „1 TL Salz“ ergänzt die Menge statt eine zweite Zeile anzulegen
        let existing = [item("Salz")]
        let result = ShoppingMerge.merge([ingredient("Salz", 1, "TL")], recipeId: nil, into: existing, householdId: household)
        #expect(result.inserts.isEmpty)
        #expect(result.updates.first?.amountText == "1 TL")

        // Umgekehrt: „Salz“ ohne Menge zu „1 TL Salz“ ändert nichts
        let again = ShoppingMerge.merge([ingredient("Salz")], recipeId: nil, into: [item("Salz", 1, "TL")], householdId: household)
        #expect(again == ShoppingMerge.Result())
    }

    @Test func ignoresCheckedItemsFromEarlierShopping() {
        let existing = [item("Milch", 1, "l", checked: true)]
        let result = ShoppingMerge.merge([ingredient("Milch", 1, "l")], recipeId: nil, into: existing, householdId: household)
        #expect(result.updates.isEmpty)
        #expect(result.inserts.count == 1)
        #expect(result.inserts[0].checked == false)
    }

    @Test func mergesWithinOneBatch() {
        // Wochen-Einkauf: zwei Rezepte brauchen Zwiebeln
        let result = ShoppingMerge.merge(
            [ingredient("Zwiebeln", 2), ingredient("Knoblauch", 1, "Zehe"), ingredient("Zwiebeln", 1), ingredient("Knoblauch", 2, "Zehe")],
            recipeId: nil, into: [], householdId: household
        )
        #expect(result.updates.isEmpty)
        #expect(result.inserts.map(\.name) == ["Zwiebeln", "Knoblauch"])
        #expect(result.inserts.map(\.quantity) == [3, 3])
    }

    @Test func mixedRecipesLoseTheirRecipeReference() {
        let existing = [item("Zitrone", 1, recipe: recipeA)]
        let result = ShoppingMerge.merge([ingredient("Zitrone", 1)], recipeId: recipeB, into: existing, householdId: household)
        #expect(result.updates.first?.recipeId == nil)
    }

    @Test func usesIngredientAisleOrGuesses() {
        var withAisle = ingredient("Halloumi", 250, "g")
        withAisle.aisle = .kuehlregal
        let result = ShoppingMerge.merge([withAisle, ingredient("Spaghetti", 500, "g")], recipeId: nil, into: [], householdId: household)
        #expect(result.inserts.map(\.aisle) == [.kuehlregal, .trockenwaren])
    }
}

struct PlanCalendarTests {
    func date(_ s: String) -> Date {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd HH:mm"
        return f.date(from: s)!
    }

    @Test func weekStartsOnMonday() {
        // Sonntag, 1. November 2026, spätabends
        let start = PlanCalendar.startOfWeek(containing: date("2026-11-01 23:30"))
        #expect(PlanCalendar.key(for: start) == "2026-10-26")
        #expect(PlanCalendar.days(ofWeekStarting: start).map(PlanCalendar.key) == [
            "2026-10-26", "2026-10-27", "2026-10-28", "2026-10-29", "2026-10-30", "2026-10-31", "2026-11-01",
        ])
        #expect(PlanCalendar.weekNumber(of: start) == 44)
    }
}
