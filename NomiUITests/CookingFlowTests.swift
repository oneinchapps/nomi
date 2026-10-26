import XCTest

final class CookingFlowTests: NomiUITestCase {
    @MainActor
    func testCookingModeWithTimer() throws {
        let app = try launchWithNewHousehold()
        createRecipe(
            app,
            title: "Pasta Aglio e Olio",
            ingredients: "200 g Spaghetti\n2 Zehen Knoblauch\n4 EL Olivenöl",
            // „2 Sekunden“ wird beim Sichern als Timer erkannt
            steps: ["Spaghetti 2 Sekunden kochen.", "Knoblauch in Olivenöl anbraten und alles mischen."]
        )

        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Pasta Aglio e Olio")).firstMatch.tap()
        let cook = app.buttons["Jetzt kochen"]
        XCTAssertTrue(cook.waitForExistence(timeout: 5))
        cook.tap()

        // Vorbereitung
        XCTAssertTrue(app.staticTexts["Erst mal alles bereitstellen"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["VORBEREITUNG"].exists)
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Spaghetti")).firstMatch.tap()
        snapshot(app, "60-cooking-prep")
        app.buttons["Los geht's"].tap()

        // Schritt 1 mit Zutat und Timer
        XCTAssertTrue(app.staticTexts["SCHRITT 1 VON 2"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["200 g Spaghetti"].exists)
        app.buttons["Timer starten"].tap()
        XCTAssertTrue(app.buttons["Timer Schritt 1"].waitForExistence(timeout: 2), "Laufender Timer erscheint nicht oben")
        snapshot(app, "61-cooking-timer")
        let banner = app.buttons["Timer abgelaufen, Schritt 1"]
        XCTAssertTrue(banner.waitForExistence(timeout: 6), "Kein Hinweis, als der Timer abgelaufen ist")
        snapshot(app, "62-cooking-timer-done")
        banner.tap()

        // Schritt 2 zeigt beide Zutaten
        app.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["SCHRITT 2 VON 2"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2 Zehen Knoblauch"].exists)
        XCTAssertTrue(app.staticTexts["4 EL Olivenöl"].exists)
        snapshot(app, "63-cooking-step2")

        app.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["Guten Appetit!"].waitForExistence(timeout: 3))
        app.buttons["Fertig"].tap()
        XCTAssertTrue(cook.waitForExistence(timeout: 3), "Nach dem Kochen zurück in der Rezeptansicht")
    }
}
