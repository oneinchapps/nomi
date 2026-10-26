import XCTest

/// nomi als Assistent: plant, füllt die Einkaufsliste, springt in den Wochenplan und macht es rückgängig.
/// Außerdem „Das nehmen wir“ im Heute-Tab. Braucht `supabase functions serve` mit ANTHROPIC_API_KEY.
final class NomiFlowTests: NomiUITestCase {
    @MainActor
    func testNomiPlansShopsAndUndoes() async throws {
        let app = try launchWithNewHousehold()
        let (sam, householdId) = try await joinAsSam(app)
        for (title, ingredient) in [("Linsen-Dal", "rote Linsen"), ("Spaghetti Carbonara", "Spaghetti")] {
            try await api("POST", "/rest/v1/recipes", body: [
                "household_id": householdId,
                "title": title,
                "total_minutes": 25,
                "ingredients": [["name": ingredient, "quantity": 200, "unit": "g", "aisle": "trockenwaren"]],
                "steps": [["text": "Kochen."]],
            ], as: sam)
        }

        app.tabBars.buttons["nomi"].tap()
        let input = app.textFields["Frag nomi"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        snapshot(app, "100-nomi-start")
        input.tap()
        input.typeText("Plan uns für morgen Linsen-Dal und setz die Zutaten auf die Einkaufsliste\n")

        // nomi trägt ein und springt in den Wochenplan
        let week = app.tabBars.buttons["Woche"]
        let switched = expectation(for: NSPredicate(format: "isSelected == true"), evaluatedWith: week)
        await fulfillment(of: [switched], timeout: 90)
        XCTAssertTrue(app.staticTexts["Linsen-Dal"].waitForExistence(timeout: 10), "Linsen-Dal steht nicht im Plan")
        snapshot(app, "101-nomi-week")
        let planned = try await apiList("/rest/v1/meal_plan_entries?household_id=eq.\(householdId)&select=id", as: sam)
        XCTAssertEqual(planned.count, 1)
        let items = try await apiList("/rest/v1/shopping_items?household_id=eq.\(householdId)&select=name", as: sam)
        XCTAssertTrue(items.contains { ($0["name"] as? String) == "rote Linsen" }, "Zutaten fehlen auf der Einkaufsliste")

        // Zurück zu nomi: Karte mit Rückgängig
        app.tabBars.buttons["nomi"].tap()
        let undo = app.buttons["Rückgängig"]
        XCTAssertTrue(undo.waitForExistence(timeout: 10))
        snapshot(app, "102-nomi-action-card")
        undo.tap()
        XCTAssertTrue(app.staticTexts["RÜCKGÄNGIG GEMACHT"].waitForExistence(timeout: 10))
        let after = try await apiList("/rest/v1/meal_plan_entries?household_id=eq.\(householdId)&select=id", as: sam)
        XCTAssertTrue(after.isEmpty, "Plan-Eintrag wurde nicht entfernt")
        let itemsAfter = try await apiList("/rest/v1/shopping_items?household_id=eq.\(householdId)&select=id", as: sam)
        XCTAssertTrue(itemsAfter.isEmpty, "Einkaufsliste wurde nicht zurückgesetzt")
    }

    @MainActor
    func testDecideAloneWithoutMatch() async throws {
        let app = try launchWithNewHousehold()
        _ = try await joinAsSam(app)

        app.buttons["Vorschläge fürs Mittagessen"].tap()
        let quick = app.buttons["Was Schnelles"]
        XCTAssertTrue(quick.waitForExistence(timeout: 5))
        quick.tap()
        let decideAlone = app.buttons["Das nehmen wir"]
        XCTAssertTrue(decideAlone.waitForExistence(timeout: 90), "Keine Vorschläge")
        snapshot(app, "103-today-deck")
        // Das Blatt scrollt nach dem Eintreffen der Karten noch animiert nach unten –
        // ein Tipp in dieser Zeit landet neben dem Knopf
        sleep(2)
        decideAlone.tap()

        // Ohne dass Sam abstimmt: entschieden
        XCTAssertTrue(app.staticTexts["DU HAST ENTSCHIEDEN"].waitForExistence(timeout: 15), "Allein festlegen kommt nicht an")
        snapshot(app, "104-today-decided")
    }

    /// Zweite Person über die API, damit es ohne sie kein Match gäbe.
    @MainActor
    private func joinAsSam(_ app: XCUIApplication) async throws -> (APIUser, String) {
        let codeText = inviteCodeText(app)
        XCTAssertTrue(codeText.waitForExistence(timeout: 10))
        let sam = try await apiSignIn(email: "sam-\(run)@nomi.test")
        let household = try await api("POST", "/rest/v1/rpc/join_household", body: ["code": codeText.label, "display_name": "Sam"], as: sam)
        return (sam, try XCTUnwrap(household["id"] as? String))
    }
}
