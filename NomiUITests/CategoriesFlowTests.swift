import XCTest

final class CategoriesFlowTests: NomiUITestCase {
    @MainActor
    func testCategoriesAndCookingHistory() async throws {
        let app = try launchWithNewHousehold()
        let codeText = inviteCodeText(app)
        XCTAssertTrue(codeText.waitForExistence(timeout: 10))
        let sam = try await apiSignIn(email: "sam-\(run)@nomi.test")
        let household = try await api("POST", "/rest/v1/rpc/join_household", body: ["code": codeText.label, "display_name": "Sam"], as: sam)
        let householdId = try XCTUnwrap(household["id"] as? String)

        // Drei kategorisierte Rezepte, angelegt von der anderen Person
        for (title, minutes, type, diet) in [
            ("Linsen-Dal", 25, "hauptgericht", "vegan"),
            ("Rinderrouladen", 180, "hauptgericht", "fleisch"),
            ("Kaiserschmarrn", 30, "dessert", "vegetarisch"),
        ] {
            try await api("POST", "/rest/v1/recipes", body: [
                "household_id": householdId, "title": title, "total_minutes": minutes,
                "dish_type": type, "diet": diet,
                "ingredients": [["name": "Zutat", "quantity": 1, "unit": NSNull(), "note": NSNull(), "aisle": "sonstiges"]],
                "steps": [["text": "Kochen.", "timer_seconds": NSNull()]],
            ], as: sam)
        }

        app.tabBars.buttons["Rezepte"].tap()
        if !app.staticTexts["3 REZEPTE"].waitForExistence(timeout: 20) {
            snapshot(app, "fail-categories")
            XCTFail("Rezepte fehlen: \(app.staticTexts.allElementsBoundByIndex.prefix(15).map(\.label))")
            return
        }
        XCTAssertTrue(app.staticTexts["NEU IN EURER SAMMLUNG"].exists)
        // Vegan zählt auch als vegetarisch
        let vegetarian = app.buttons["Vegetarisch, 2 Rezepte"]
        XCTAssertTrue(vegetarian.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Fleisch, 1 Rezept"].exists)
        snapshot(app, "90-recipes-landing")

        // Kategorie öffnen, dann per Chip wechseln
        vegetarian.tap()
        XCTAssertTrue(app.staticTexts["2 REZEPTE"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Linsen-Dal'")).firstMatch.exists)
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Rinderrouladen'")).firstMatch.exists)
        snapshot(app, "91-recipes-vegetarian")
        app.buttons["Fleisch"].tap()
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Rinderrouladen'")).firstMatch.waitForExistence(timeout: 3))
        app.buttons["Übersicht"].tap()

        // Kochen → Historie
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Linsen-Dal'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Noch nie gekocht"].waitForExistence(timeout: 5))
        app.buttons["Jetzt kochen"].tap()
        app.buttons["Los geht's"].tap()
        app.buttons["Kochmodus beenden"].tap()
        XCTAssertTrue(app.staticTexts["Zuletzt gekocht heute"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.staticTexts["ZULETZT GEKOCHT"].waitForExistence(timeout: 5))
        snapshot(app, "92-recipes-recent")

        // Lange nicht gekocht: die beiden anderen, Linsen-Dal nicht
        app.swipeUp()
        app.buttons.containing(NSPredicate(format: "label CONTAINS 'Lange nicht gekocht'")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["2 REZEPTE"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'NOCH NIE GEKOCHT'")).firstMatch.exists)
        XCTAssertFalse(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Linsen-Dal'")).firstMatch.exists)
        app.buttons["Übersicht"].tap()

        // Verlauf
        app.swipeDown()
        app.buttons["Verlauf"].tap()
        XCTAssertTrue(app.navigationBars["Kochhistorie"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS 'Linsen-Dal'")).firstMatch.exists)
        snapshot(app, "93-history")
    }
}
