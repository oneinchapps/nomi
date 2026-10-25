import XCTest

final class RecipeFlowTests: NomNomUITestCase {
    @MainActor
    func testCreateRecipeAndScaleServings() throws {
        let app = try launchWithNewHousehold()

        app.tabBars.buttons["Rezepte"].tap()
        XCTAssertTrue(app.staticTexts["Noch keine Rezepte"].waitForExistence(timeout: 5))
        snapshot(app, "10-recipes-empty")
        app.buttons["Erstes Rezept anlegen"].tap()

        let title = app.textFields["z. B. Halloumi-Tacos"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("Halloumi-Tacos")

        let minutes = app.textFields["30"]
        minutes.tap()
        minutes.typeText("25")

        let ingredients = app.textViews["editor-ingredients"]
        ingredients.tap()
        ingredients.typeText("250 g Halloumi\n8 kleine Tortillas\n1 1/2 EL Olivenöl\nSalz")
        let steps = app.textViews["editor-steps"]
        steps.tap()
        steps.typeText("Halloumi in Scheiben schneiden und goldbraun braten.\nTortillas erwärmen und belegen.")
        snapshot(app, "11-editor")

        app.buttons["Sichern"].tap()

        // Kachel in der Sammlung
        let tile = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Halloumi-Tacos")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10), "Neues Rezept erscheint nicht in der Sammlung")
        XCTAssertTrue(app.staticTexts["1 REZEPT"].exists)
        snapshot(app, "12-recipes-grid")

        // Detail mit Originalmengen
        tile.tap()
        XCTAssertTrue(row(app, "250 g").waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, "1 ½ EL").exists)
        XCTAssertTrue(app.staticTexts["25 MIN"].exists)
        snapshot(app, "13-detail")

        // Für vier Personen
        let more = app.buttons["Mehr Portionen"]
        XCTAssertTrue(more.exists)
        more.tap()
        more.tap()
        XCTAssertTrue(app.staticTexts["4 Portionen"].waitForExistence(timeout: 3))
        XCTAssertTrue(row(app, "500 g").waitForExistence(timeout: 3))
        XCTAssertTrue(row(app, "3 EL").exists)
        XCTAssertTrue(row(app, "16").exists)
        snapshot(app, "14-detail-scaled")
    }

    /// Zutatenzeilen sind für VoiceOver zusammengefasst („250 g, Halloumi“), daher Präfix-Suche.
    @MainActor
    private func row(_ app: XCUIApplication, _ amount: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", amount + ",")).firstMatch
    }
}
