import XCTest

/// Mehrgängiges Menü aus dem Chat. Braucht `supabase functions serve` mit ANTHROPIC_API_KEY.
final class MenuFlowTests: NomiUITestCase {
    @MainActor
    func testThreeCourseMenuFromChat() async throws {
        let app = try launchWithNewHousehold()
        let codeText = inviteCodeText(app)
        XCTAssertTrue(codeText.waitForExistence(timeout: 10))
        let sam = try await apiSignIn(email: "sam-\(run)@nomi.test")
        let household = try await api("POST", "/rest/v1/rpc/join_household", body: ["code": codeText.label, "display_name": "Sam"], as: sam)
        let householdId = try XCTUnwrap(household["id"] as? String)

        // Menüwunsch im Chat
        let input = app.textFields["Worauf habt ihr Lust?"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        // Eingabetaste schickt ab (die Tastatur hat selbst eine „Senden“-Taste, daher nicht über den Button)
        input.typeText("Drei-Gänge-Menü für heute Abend\n")

        let like = app.buttons["Lecker"]
        XCTAssertTrue(like.waitForExistence(timeout: 90), "Keine Vorschläge")
        XCTAssertTrue(app.descendants(matching: .any)["Vorspeise: offen"].exists, "Gänge werden nicht angezeigt")
        XCTAssertTrue(app.descendants(matching: .any)["Dessert: offen"].exists)
        snapshot(app, "80-menu-deck")

        // Pro Gang die erste Idee (sonst die erste Karte) – die mögen am Ende beide
        let session = try await api("GET", "/rest/v1/decide_sessions?household_id=eq.\(householdId)&status=eq.open&select=id,courses", as: sam)
        let sessionId = try XCTUnwrap(session["id"] as? String)
        let courses = try XCTUnwrap(session["courses"] as? [String])
        XCTAssertEqual(courses.count, 3)
        let cards = try await apiList("/rest/v1/session_candidates?session_id=eq.\(sessionId)&order=position&select=id,course,ai_recipe", as: sam)
        let picks = try courses.map { course in
            let inCourse = cards.filter { $0["course"] as? String == course }
            return try XCTUnwrap((inCourse.first { !($0["ai_recipe"] is NSNull) } ?? inCourse.first)?["id"] as? String)
        }

        // Alex mag alles
        while like.waitForExistence(timeout: 2) {
            like.tap()
            sleep(1)
        }
        XCTAssertTrue(app.staticTexts["Warte auf Sam"].waitForExistence(timeout: 5))

        // Sam entscheidet Gang für Gang – der Fortschritt kommt live an
        for (index, pick) in picks.enumerated() {
            try await api("POST", "/rest/v1/session_votes", body: [
                "candidate_id": pick, "session_id": sessionId, "household_id": householdId, "liked": true,
            ], as: sam)
            if index == 0 {
                XCTAssertTrue(app.descendants(matching: .any)["\(courses[0]): entschieden"].waitForExistence(timeout: 10))
                snapshot(app, "81-menu-progress")
            }
        }
        XCTAssertTrue(app.staticTexts["Euer Menü"].waitForExistence(timeout: 10), "Menü kommt nicht live an")
        snapshot(app, "82-menu-match")

        // Ideen ausarbeiten (parallel), dann alles für heute einplanen
        let expand = app.buttons.matching(NSPredicate(format: "label ENDSWITH 'ausarbeiten'")).firstMatch
        if expand.exists { expand.tap() }
        let planAll = app.buttons["Für heute einplanen"]
        XCTAssertTrue(planAll.waitForExistence(timeout: 120), "Ideen wurden nicht ausgearbeitet")
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'nicht ausarbeiten'")).firstMatch.exists,
                       "Fehlermeldung trotz erfolgreichem Ausarbeiten")
        planAll.tap()
        XCTAssertTrue(app.staticTexts["Für heute eingeplant"].waitForExistence(timeout: 5))
        snapshot(app, "83-menu-planned")

        // Im Wochenplan stehen alle drei Gänge, mit Gang als Hinweis
        app.tabBars.buttons["Woche"].tap()
        for course in courses {
            let entry = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", course)).firstMatch
            XCTAssertTrue(entry.waitForExistence(timeout: 5), "\(course) fehlt im Wochenplan")
        }
        snapshot(app, "84-menu-week")
    }
}
