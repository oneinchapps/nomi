import XCTest

/// Braucht `supabase functions serve` mit ANTHROPIC_API_KEY in supabase/functions/.env.
final class ImportFlowTests: NomiUITestCase {
    /// Rezeptseite mit schema.org-Daten, die zuverlässig erreichbar ist.
    private let recipeURL = "https://www.chefkoch.de/rezepte/2133281343053838/Rinderrouladen-klassisch.html"

    @MainActor
    func testImportRecipeFromLink() throws {
        let app = try launchWithNewHousehold()

        app.tabBars.buttons["Rezepte"].tap()
        app.buttons["Rezept aus Link"].tap()
        let field = app.textFields["https://…"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText(recipeURL)
        snapshot(app, "20-import-link")
        app.buttons["Rezept auslesen"].tap()

        XCTAssertTrue(app.staticTexts["nomi liest mit"].waitForExistence(timeout: 5))
        snapshot(app, "21-importing")

        let save = app.buttons["Sichern"]
        if !save.waitForExistence(timeout: 90) {
            snapshot(app, "fail-import")
            XCTFail("Editor erscheint nicht. Sichtbar: \(app.staticTexts.allElementsBoundByIndex.map(\.label))")
            return
        }
        // Zutaten sind vorausgefüllt
        let ingredients = app.textViews["editor-ingredients"]
        XCTAssertFalse((ingredients.value as? String ?? "").isEmpty, "Keine Zutaten ausgelesen")
        snapshot(app, "22-import-editor")

        save.tap()
        XCTAssertTrue(app.staticTexts["1 Rezept"].waitForExistence(timeout: 15))
        // Foto laden lassen, dann prüfen: Kachel bleibt im Bildschirm (Fotos dürfen das Raster nicht sprengen)
        sleep(2)
        let tile = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Rouladen")).firstMatch
        XCTAssertGreaterThanOrEqual(tile.frame.minX, 0, "Kachel ragt links aus dem Bildschirm")
        XCTAssertLessThanOrEqual(tile.frame.maxX, app.frame.maxX / 2 + 10, "Kachel ist breiter als ihre Spalte")
        snapshot(app, "23-imported-grid")

        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Rouladen")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Zutaten"].waitForExistence(timeout: 5))
        snapshot(app, "24-imported-detail")
    }
}
