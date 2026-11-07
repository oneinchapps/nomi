import XCTest

/// iPad quer: eigene Layouts (Rezeptraster, Rezept zweispaltig, Wochen-Board, Einkauf in Spalten, Kochmodus mit Zutaten).
final class IPadLayoutTests: NomiUITestCase {
    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    /// Ganzer Bildschirm: `app.screenshot()` liefert im Querformat ein verschobenes Bild
    private func screen(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    @MainActor
    func testLandscapeLayouts() async throws {
        try XCTSkipIf(UIDevice.current.userInterfaceIdiom != .pad, "Nur auf dem iPad")
        let app = try launchWithNewHousehold()
        XCUIDevice.shared.orientation = .landscapeLeft
        let codeText = inviteCodeText(app)
        XCTAssertTrue(codeText.waitForExistence(timeout: 10))

        // Volle Einkaufsliste über die zweite Person
        let sam = try await apiSignIn(email: "sam-\(run)@nomi.test")
        let household = try await api("POST", "/rest/v1/rpc/join_household", body: ["code": codeText.label, "display_name": "Sam"], as: sam)
        let householdId = try XCTUnwrap(household["id"] as? String)
        for (name, aisle) in [("Bananen", "obst_gemuese"), ("Zwiebeln", "obst_gemuese"), ("Paprika", "obst_gemuese"),
                              ("Brötchen", "backwaren"), ("Hafermilch", "kuehlregal"), ("Joghurt", "kuehlregal"),
                              ("Halloumi", "kuehlregal"), ("Spaghetti", "trockenwaren"), ("Reis", "trockenwaren"),
                              ("Kombucha", "getraenke"), ("Sprudel", "getraenke")] {
            _ = try await api("POST", "/rest/v1/shopping_items", body: ["household_id": householdId, "name": name, "aisle": aisle], as: sam)
        }

        createRecipe(app, title: "Shakshuka", ingredients: "6 Eier\n1 Dose Tomaten\n1 Paprika",
                     steps: ["Paprika und Zwiebel in Olivenöl weich dünsten.", "Tomaten dazu, Eier hineinsetzen und stocken lassen."])

        // Rezepte als Raster
        app.tab("Rezepte").tap()
        let tile = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Shakshuka")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        screen("90-ipad-recipes")

        // Rezept zweispaltig: Zutaten links neben den Schritten
        tile.tap()
        let cook = app.buttons["Jetzt kochen"]
        XCTAssertTrue(cook.waitForExistence(timeout: 5))
        let ingredientsHeading = app.staticTexts["Zutaten"]
        let stepsHeading = app.staticTexts["Zubereitung"]
        XCTAssertLessThan(ingredientsHeading.frame.maxX, stepsHeading.frame.minX, "Zutaten stehen nicht links neben den Schritten")
        screen("91-ipad-recipe")

        // Kochmodus: Zutaten links, Schritt rechts
        cook.tap()
        app.buttons["Los geht's"].tap()
        XCTAssertTrue(app.staticTexts["SCHRITT 1 VON 2"].waitForExistence(timeout: 5))
        screen("92-ipad-cooking")
        app.buttons["Kochmodus beenden"].tap()

        // Woche als Board: Tage nebeneinander
        app.tab("Woche").tap()
        let wednesday = app.buttons["Gericht für Mittwoch planen"]
        XCTAssertTrue(wednesday.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(wednesday.frame.minX, app.buttons["Gericht für Montag planen"].frame.maxX, "Woche ist kein Board")
        wednesday.tap()
        let pick = app.collectionViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Shakshuka")).firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()
        XCTAssertTrue(app.buttons["plan-Shakshuka"].waitForExistence(timeout: 5))
        screen("93-ipad-week")

        // Einkauf in drei Spalten
        app.tab("Einkauf").tap()
        let bananas = app.buttons["item-Bananen"]
        XCTAssertTrue(bananas.waitForExistence(timeout: 10))
        let drinks = app.buttons["item-Kombucha"]
        XCTAssertGreaterThan(drinks.frame.minX, bananas.frame.maxX, "Abteilungen stehen nicht in Spalten")
        screen("94-ipad-shopping")
    }
}
