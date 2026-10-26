import XCTest

/// Beide Personen: A legt den Haushalt an und verschickt die Einladung, B tritt mit dem Code bei – ohne E-Mail.
final class OnboardingFlowTests: NomNomUITestCase {
    /// Nach dem Anlegen steht die Einladung mit Code und Teilen-Button auf dem Heute-Screen.
    @MainActor
    func testNewHouseholdShowsInvite() throws {
        let a = launchFresh()
        snapshot(a, "01-welcome")
        try signIn(a, email: "a-\(run)@nomnom.test", screenshotPrefix: "0")
        snapshot(a, "04-household-setup")

        let name = a.textFields["Vorname"]
        name.tap()
        name.typeText("Alex")
        a.buttons["Haushalt anlegen"].tap()

        XCTAssertTrue(a.staticTexts["EINLADUNG"].waitForExistence(timeout: 10), "Nach dem Anlegen sollte die Einladung erscheinen")
        let codeText = a.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[A-Z0-9]{4}-[A-Z0-9]{4}$")).firstMatch
        XCTAssertTrue(codeText.waitForExistence(timeout: 10), "Kein Einladungscode auf dem Screen")
        XCTAssertTrue(a.buttons["Einladung verschicken"].exists)
        snapshot(a, "05-home-with-invite")
    }

    /// B löst den Code ein, kommt später per Anmeldecode auf einem „neuen Handy“ ins selbe Konto,
    /// und ein verbrauchter Code geht kein zweites Mal.
    @MainActor
    func testInvitedPersonJoinsWithoutEmail() async throws {
        let alex = try await apiSignIn(email: "alex-\(run)@nomnom.test")
        try await api("POST", "/rest/v1/rpc/create_household", body: ["display_name": "Alex"], as: alex)
        let invite = try await api("POST", "/rest/v1/rpc/create_invite", body: [String: String](), as: alex)
        let code = try XCTUnwrap(invite["code"] as? String)

        let b = launchFresh()
        b.buttons["Ich habe eine Einladung"].tap()
        // Fokus startet im Code-Feld und springt nach vollständigem Code zum Namen
        let codeField = b.textFields["XXXX-XXXX"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 5))
        codeField.typeText(code.lowercased())
        XCTAssertEqual(codeField.value as? String, code.prefix(4) + "-" + code.dropFirst(4), "Der Code wird beim Tippen formatiert")
        b.textFields["Vorname"].typeText("Sam")
        snapshot(b, "06-invite")
        b.buttons["Los geht's"].tap()

        XCTAssertTrue(b.staticTexts["Was gibt es heute?"].waitForExistence(timeout: 15))
        XCTAssertFalse(b.staticTexts["EINLADUNG"].exists, "Zu zweit braucht es keine Einladung mehr")
        b.buttons["Haushalt und Konto"].tap()
        XCTAssertTrue(b.staticTexts["Alex"].waitForExistence(timeout: 5))
        XCTAssertTrue(b.staticTexts["Sam"].exists)
        let note = b.staticTexts.containing(NSPredicate(format: "label BEGINSWITH %@", "Du bist per Einladung ohne E-Mail angemeldet")).firstMatch
        XCTAssertTrue(note.exists)
        snapshot(b, "07-household-sheet")

        // Neues Handy: Alex schickt Sam einen Anmeldecode
        let members = try await apiList("/rest/v1/household_members?display_name=eq.Sam", as: alex)
        let sam = try XCTUnwrap(members.first?["user_id"] as? String)
        let relogin = try await api("POST", "/rest/v1/rpc/create_invite", body: ["member": sam], as: alex)
        let reloginCode = try XCTUnwrap(relogin["code"] as? String)

        b.buttons["Abmelden"].tap()
        XCTAssertTrue(b.buttons["Ich habe eine Einladung"].waitForExistence(timeout: 10))
        try redeem(b, name: "Sam", code: reloginCode)
        XCTAssertTrue(b.staticTexts["Was gibt es heute?"].waitForExistence(timeout: 15))
        b.buttons["Haushalt und Konto"].tap()
        XCTAssertTrue(b.staticTexts["Alex"].waitForExistence(timeout: 5))
        XCTAssertEqual(b.staticTexts.matching(identifier: "Sam").count, 1, "Dasselbe Konto, kein zweites Mitglied")

        // Der erste Code ist verbraucht
        b.buttons["Abmelden"].tap()
        XCTAssertTrue(b.buttons["Ich habe eine Einladung"].waitForExistence(timeout: 10))
        try redeem(b, name: "Eve", code: code)
        XCTAssertTrue(b.staticTexts["Diesen Code gibt es nicht oder er ist abgelaufen. Lass dir einen neuen schicken."].waitForExistence(timeout: 10))
    }

    @MainActor
    private func redeem(_ app: XCUIApplication, name: String, code: String) throws {
        app.buttons["Ich habe eine Einladung"].tap()
        let codeField = app.textFields["XXXX-XXXX"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 5))
        codeField.typeText(code)
        app.textFields["Vorname"].typeText(name + "\n")
    }
}
