import XCTest

/// Braucht `supabase functions serve` mit ANTHROPIC_API_KEY (echte Vorschläge von Claude).
final class DecideFlowTests: NomiUITestCase {
    @MainActor
    func testChatSwipeMatchAndExpand() async throws {
        let app = try launchWithNewHousehold()
        let codeText = inviteCodeText(app)
        XCTAssertTrue(codeText.waitForExistence(timeout: 10))
        let inviteCode = codeText.label

        createRecipe(app, title: "Halloumi-Tacos", ingredients: "250 g Halloumi\n8 kleine Tortillas\n1 Avocado")

        // Sam tritt bei und schreibt im Chat mit
        let sam = try await apiSignIn(email: "sam-\(run)@nomi.test")
        let household = try await api("POST", "/rest/v1/rpc/join_household", body: ["code": inviteCode, "display_name": "Sam"], as: sam)
        let householdId = try XCTUnwrap(household["id"] as? String)

        // Heute: Vorschläge fürs Abendessen öffnen das Auswahlblatt
        app.tabBars.buttons["Heute"].tap()
        let suggest = app.buttons["Vorschläge fürs Abendessen"]
        XCTAssertTrue(suggest.waitForExistence(timeout: 5))
        snapshot(app, "50-today-start")
        suggest.tap()
        XCTAssertTrue(app.buttons["Was Schnelles"].waitForExistence(timeout: 5))
        app.buttons["Was Schnelles"].tap()

        XCTAssertTrue(app.descendants(matching: .any)["nomi überlegt"].waitForExistence(timeout: 5))
        let like = app.buttons["Lecker"]
        XCTAssertTrue(like.waitForExistence(timeout: 60), "Keine Vorschläge von nomi")
        snapshot(app, "51-deck")

        // Welche Karten gibt es? Ziel: die erste neue Idee
        let session = try await api("GET", "/rest/v1/decide_sessions?household_id=eq.\(householdId)&status=eq.open&select=id", as: sam)
        let sessionId = try XCTUnwrap(session["id"] as? String)
        let cards = try await apiList("/rest/v1/session_candidates?session_id=eq.\(sessionId)&order=position&select=id,ai_recipe", as: sam)
        let targetIndex = try XCTUnwrap(cards.firstIndex { !($0["ai_recipe"] is NSNull) }, "nomi hat keine neue Idee vorgeschlagen")
        let targetId = try XCTUnwrap(cards[targetIndex]["id"] as? String)

        // Alex: alles davor ablehnen (erste Karte per Wischgeste), dann die Idee liken
        for index in 0..<targetIndex {
            if index == 0 {
                let topCard = app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label CONTAINS 'AUS EURER SAMMLUNG' OR label CONTAINS 'IDEE VON NOMI'"))
                    .firstMatch
                topCard.swipeLeft(velocity: .fast)
            } else {
                app.buttons["Nein danke"].tap()
            }
            sleep(1)
        }
        like.tap()

        // Noch kein Match – Sam hat noch nicht abgestimmt
        XCTAssertFalse(app.staticTexts["Heute gibt's"].waitForExistence(timeout: 2))

        // Sam mag dieselbe Idee → Match erscheint live
        try await api("POST", "/rest/v1/session_votes", body: [
            "candidate_id": targetId, "session_id": sessionId, "household_id": householdId, "liked": true,
        ], as: sam)
        XCTAssertTrue(app.staticTexts["Heute gibt's"].waitForExistence(timeout: 10), "Match kommt nicht live an")
        snapshot(app, "52-match")

        // Idee ausarbeiten → steht danach von selbst beim Abendessen → Rezept ansehen
        app.buttons["Rezept ausarbeiten"].tap()
        let view = app.buttons["Rezept ansehen"]
        XCTAssertTrue(view.waitForExistence(timeout: 90), "Rezept wurde nicht ausgearbeitet")
        XCTAssertTrue(app.staticTexts["Steht beim Abend"].waitForExistence(timeout: 10), "Entscheidung steht nicht beim Abendessen")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'nicht ausarbeiten'")).firstMatch.exists,
                       "Fehlermeldung trotz erfolgreichem Ausarbeiten")
        snapshot(app, "53-match-expanded")
        view.tap()
        XCTAssertTrue(app.staticTexts["Zutaten"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Zubereitung"].exists || { app.swipeUp(); return app.staticTexts["Zubereitung"].exists }())
        snapshot(app, "54-ai-recipe")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Blatt schließen: Das Gericht steht im Heute-Tab beim Abendessen, mit „Jetzt kochen“
        app.buttons["Fertig"].tap()
        XCTAssertTrue(app.buttons["Jetzt kochen"].waitForExistence(timeout: 10), "Gericht fehlt im Heute-Tab")
        XCTAssertTrue(app.buttons["Gang zum Abendessen hinzufügen"].exists)
        snapshot(app, "55-today-planned")

        // Das neue Rezept liegt in der Sammlung
        app.tabBars.buttons["Rezepte"].tap()
        XCTAssertTrue(app.staticTexts["2 Rezepte"].waitForExistence(timeout: 5))
    }
}
