import XCTest

/// Braucht `supabase functions serve` mit ANTHROPIC_API_KEY in supabase/functions/.env.
final class ImportFlowTests: NomNomUITestCase {
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

        XCTAssertTrue(app.staticTexts["nomnom liest mit"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.staticTexts["1 REZEPT"].waitForExistence(timeout: 15))
        snapshot(app, "23-imported-grid")

        app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Rouladen")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Zutaten"].waitForExistence(timeout: 5))
        snapshot(app, "24-imported-detail")
    }
}
