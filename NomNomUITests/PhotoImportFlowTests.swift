import XCTest

/// Braucht `supabase functions serve` mit ANTHROPIC_API_KEY (echtes Auslesen per Claude).
final class PhotoImportFlowTests: NomNomUITestCase {
    /// Handgeschriebene Karteikarte aus Fixtures/ – der Simulator liest direkt vom Mac.
    private let card = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/handwritten-card.jpg")
        .path

    @MainActor
    func testHandwrittenRecipeFromPhoto() throws {
        let app = try launchWithNewHousehold(extraEnvironment: ["NOMNOM_TEST_PHOTOS": card])

        app.tabBars.buttons["Rezepte"].tap()
        app.buttons["Rezept vom Foto"].tap()
        XCTAssertTrue(app.buttons["Foto 1 entfernen"].waitForExistence(timeout: 5), "Testfoto wurde nicht geladen")
        snapshot(app, "70-photo-picked")
        app.buttons["Rezept auslesen"].tap()

        let save = app.buttons["Sichern"]
        XCTAssertTrue(save.waitForExistence(timeout: 90), "Rezept wurde nicht vom Foto gelesen")
        XCTAssertEqual(app.textFields["z. B. Halloumi-Tacos"].value as? String, "Omas Apfelpfannkuchen")
        let ingredients = app.textViews["editor-ingredients"].value as? String ?? ""
        XCTAssertTrue(ingredients.contains("250 g Mehl"), "Zutaten: \(ingredients)")
        XCTAssertTrue(ingredients.contains("2 EL Zucker"), "„Essl.“ sollte als EL gelesen werden: \(ingredients)")
        snapshot(app, "71-photo-editor")
        save.tap()

        let tile = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Apfelpfannkuchen")).firstMatch
        XCTAssertTrue(tile.waitForExistence(timeout: 10))
        tile.tap()
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "VOM FOTO")).firstMatch.waitForExistence(timeout: 5))
        snapshot(app, "72-photo-detail")

        // Kochmodus: Portionen ändern rechnet die Mengen um (4 → 2 Personen: 250 g Mehl → 130 g)
        app.buttons["Jetzt kochen"].tap()
        XCTAssertTrue(app.staticTexts["250 g"].waitForExistence(timeout: 5))
        // Die Rezeptansicht darunter hat ebenfalls einen Regler – den im Kochmodus nehmen
        let fewer = app.otherElements["cooking-servings"].buttons["Weniger Portionen"]
        fewer.tap()
        fewer.tap()
        XCTAssertTrue(app.staticTexts["2 Portionen"].waitForExistence(timeout: 3))
        // Ab 100 g wird auf Zehner gerundet: 125 g → 130 g
        XCTAssertTrue(app.staticTexts["130 g"].exists, "Mehl nicht umgerechnet")
        snapshot(app, "73-cooking-scaled")
    }
}
