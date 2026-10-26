import XCTest

/// Heute-Tab: feste Mahlzeiten, Frühstück bei Bedarf, Gerichte aus der Sammlung, weitere Gänge, „Jetzt kochen“.
final class TodayMealsTests: NomiUITestCase {
    @MainActor
    func testMealsCoursesAndCooking() throws {
        let app = try launchWithNewHousehold()
        createRecipe(app, title: "Linsen-Dal", ingredients: "200 g rote Linsen\n1 Dose Kokosmilch\n1 Zwiebel", steps: ["Linsen in Kokosmilch weich köcheln."])

        app.tabBars.buttons["Heute"].tap()
        XCTAssertTrue(app.staticTexts["Mittagessen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Abendessen"].exists)
        XCTAssertFalse(app.staticTexts["Frühstück"].exists, "Frühstück gibt es nur bei Bedarf")
        snapshot(app, "110-today-empty")

        // Mittagessen aus der Sammlung
        app.buttons["Rezept fürs Mittagessen"].tap()
        let dal = app.buttons.containing(NSPredicate(format: "label CONTAINS 'Linsen-Dal'")).firstMatch
        XCTAssertTrue(dal.waitForExistence(timeout: 5))
        dal.tap()
        let cook = app.buttons["Jetzt kochen"]
        XCTAssertTrue(cook.waitForExistence(timeout: 5), "Gericht steht nicht beim Mittagessen")

        // Weiterer Gang: Platzhalter erscheint und lässt sich wieder schließen
        app.buttons["Gang zum Mittagessen hinzufügen"].tap()
        XCTAssertTrue(app.staticTexts["Noch ein Gang?"].waitForExistence(timeout: 3))
        app.buttons["Abbrechen"].tap()
        XCTAssertFalse(app.staticTexts["Noch ein Gang?"].waitForExistence(timeout: 2))

        // Frühstück bei Bedarf
        app.buttons["Frühstück hinzufügen"].tap()
        XCTAssertTrue(app.staticTexts["Frühstück"].waitForExistence(timeout: 3))
        snapshot(app, "111-today-meals")

        // Jetzt kochen öffnet den Kochmodus
        cook.tap()
        XCTAssertTrue(app.buttons["Los geht's"].waitForExistence(timeout: 5), "Kochmodus öffnet nicht")
        app.buttons["Kochmodus beenden"].tap()
        XCTAssertTrue(cook.waitForExistence(timeout: 5))

        // Im Wochenplan steht der Eintrag mit Mahlzeit
        app.tabBars.buttons["Woche"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'MITTAG'")).firstMatch.waitForExistence(timeout: 5))
        snapshot(app, "112-week-with-meal")
    }
}
