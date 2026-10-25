import XCTest

final class ShoppingFlowTests: NomNomUITestCase {
    @MainActor
    func testShoppingListFromRecipeWithLivePartner() async throws {
        let app = try launchWithNewHousehold()

        // Einladungscode für die zweite Person merken
        let codeText = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[A-Z0-9]{6}$")).firstMatch
        XCTAssertTrue(codeText.waitForExistence(timeout: 5))
        let inviteCode = codeText.label

        createRecipe(app, title: "Halloumi-Tacos", ingredients: "250 g Halloumi\n8 kleine Tortillas\n2 EL Olivenöl\nSalz")

        // Aus dem Rezept auf die Liste – Gewürze & Öle sind abgewählt
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Halloumi-Tacos")).firstMatch.tap()
        app.buttons["Einkaufen"].tap()
        XCTAssertTrue(app.staticTexts["Gewürze & Öle sind abgewählt – die habt ihr meist schon."].waitForExistence(timeout: 15))
        snapshot(app, "30-add-to-list")
        app.buttons["2 Zutaten hinzufügen"].tap()

        // Einkaufsliste nach Abteilungen
        app.tabBars.buttons["Einkauf"].tap()
        XCTAssertTrue(app.buttons["item-Halloumi"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-kleine Tortillas"].exists)
        XCTAssertTrue(app.staticTexts["KÜHLREGAL"].exists)
        XCTAssertTrue(app.staticTexts["BACKWAREN"].exists)
        XCTAssertFalse(app.buttons["item-Olivenöl"].exists)

        // Freitext, und Zusammenführen: noch einmal Halloumi → 500 g statt zweiter Zeile
        let field = app.textFields["Was fehlt? z. B. 2 l Milch"]
        field.tap()
        field.typeText("2 l Milch\n")
        field.typeText("250 g Halloumi\n")
        XCTAssertTrue(app.buttons["item-Milch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-Halloumi"].label.contains("500 g"), "Halloumi wurde nicht zusammengeführt: \(app.buttons["item-Halloumi"].label)")

        // Abhaken
        app.buttons["item-Milch"].tap()
        XCTAssertTrue(app.staticTexts["IM WAGEN · 1"].waitForExistence(timeout: 3))
        snapshot(app, "31-shopping-list")

        // Zweite Person, live: tritt bei, fügt hinzu, hakt ab, löscht
        let sam = try await apiSignIn(email: "sam-\(run)@nomnom.test")
        let household = try await api("POST", "/rest/v1/rpc/join_household", body: ["code": inviteCode, "display_name": "Sam"], as: sam)
        let householdId = try XCTUnwrap(household["id"] as? String)

        let kaffee = try await api("POST", "/rest/v1/shopping_items", body: [
            "household_id": householdId, "name": "Kaffee", "aisle": "getraenke",
        ], as: sam)
        XCTAssertTrue(app.buttons["item-Kaffee"].waitForExistence(timeout: 10), "Eintrag der anderen Person kommt nicht live an")
        // Beitritt kommt ebenfalls live an: Einladungskarte im Heute-Tab ist weg
        app.tabBars.buttons["Heute"].tap()
        let invite = app.staticTexts["EINLADUNGSCODE"]
        await fulfillment(of: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: invite)], timeout: 10)
        app.tabBars.buttons["Einkauf"].tap()

        let tortillas = try await api("GET", "/rest/v1/shopping_items?name=eq.kleine%20Tortillas&select=id", as: sam)
        let samRow = try await api("GET", "/rest/v1/household_members?display_name=eq.Sam&select=user_id", as: sam)
        let samId = try XCTUnwrap(samRow["user_id"] as? String)
        try await api("PATCH", "/rest/v1/shopping_items?id=eq.\(try XCTUnwrap(tortillas["id"] as? String))",
                      body: ["checked": true, "checked_by": samId], as: sam)
        XCTAssertTrue(app.descendants(matching: .any)["abgehakt von Sam"].waitForExistence(timeout: 10), "Abhaken der anderen Person kommt nicht live an")
        XCTAssertTrue(app.staticTexts["IM WAGEN · 2"].exists)
        snapshot(app, "32-live-partner")

        try await api("DELETE", "/rest/v1/shopping_items?id=eq.\(try XCTUnwrap(kaffee["id"] as? String))", as: sam)
        let gone = NSPredicate(format: "exists == false")
        await fulfillment(of: [expectation(for: gone, evaluatedWith: app.buttons["item-Kaffee"])], timeout: 10)

        // Erledigte entfernen
        app.buttons["Leeren"].tap()
        let cartGone = expectation(for: gone, evaluatedWith: app.buttons["item-Milch"])
        await fulfillment(of: [cartGone], timeout: 5)
    }

    @MainActor
    func testWeekPlanAndShoppingForTheWeek() async throws {
        let app = try launchWithNewHousehold()
        createRecipe(app, title: "Shakshuka", ingredients: "6 Eier\n1 Dose Tomaten\n1 Paprika")

        app.tabBars.buttons["Woche"].tap()
        if !app.staticTexts["Diese Woche"].waitForExistence(timeout: 5) {
            snapshot(app, "fail-week")
            XCTFail("Wochenplan nicht sichtbar: \(app.staticTexts.allElementsBoundByIndex.prefix(12).map(\.label))")
            return
        }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Gericht für")).firstMatch.tap()
        // Auf die Liste im Sheet beschränken – die Rezept-Kachel im (verborgenen) Rezepte-Tab ist auch ein Button
        let pick = app.collectionViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Shakshuka")).firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        snapshot(app, "41-recipe-picker")
        pick.tap()

        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "FÜR ZWEI")).firstMatch.waitForExistence(timeout: 5))
        snapshot(app, "40-week")

        // Nächste Woche ist leer, zurück zur aktuellen
        app.buttons["Nächste Woche"].tap()
        XCTAssertTrue(app.staticTexts["Nächste Woche"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Zutaten der Woche einkaufen"].exists)
        app.buttons["Zur aktuellen Woche"].tap()

        let shopWeek = app.buttons["Zutaten der Woche einkaufen"]
        XCTAssertTrue(shopWeek.waitForExistence(timeout: 5))
        while !shopWeek.isHittable { app.swipeUp() }
        snapshot(app, "42-week-scrolled")
        shopWeek.tap()
        app.buttons["3 Zutaten hinzufügen"].tap()

        app.tabBars.buttons["Einkauf"].tap()
        XCTAssertTrue(app.buttons["item-Eier"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-Tomaten"].exists)
        XCTAssertTrue(app.buttons["item-Paprika"].exists)
    }
}
