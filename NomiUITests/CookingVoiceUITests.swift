import XCTest

/// „Hey nomi“ im Kochmodus. Ein Mikrofon gibt es im Test nicht: Mit NOMI_VOICE_TEST=1 hört die App nicht
/// wirklich zu, und jeder Tipp auf Chefi „sagt“ den nächsten Satz aus NOMI_VOICE_SCRIPT – so, wie die
/// Erkennung ihn sonst liefern würde. Danach ist der Tipp wieder der normale („zuhören ohne Weckwort“).
/// Geprüft wird alles dahinter: Weckwort, Sprechpause, Befehle, Anzeige und die Frage an nomi (echtes Claude).
final class CookingVoiceUITests: NomiUITestCase {
    @MainActor
    func testHeyNomiInCookingMode() throws {
        let script = [
            "Hey nomi, weiter",
            "Hey nomi, Timer starten",
            "Hey nomi, wie lange noch?",
            "Hey nomi, wie viel Spaghetti?",
            "Hey nomi, zurück",
            "Hey nomi, kann ich statt Olivenöl auch Butter nehmen?",
        ]
        let app = try launchWithNewHousehold(extraEnvironment: [
            "NOMI_VOICE_TEST": "1",
            "NOMI_VOICE_SCRIPT": script.joined(separator: "|"),
        ])
        createRecipe(
            app,
            title: "Pasta Aglio e Olio",
            ingredients: "200 g Spaghetti\n2 Zehen Knoblauch\n4 EL Olivenöl\nSalz",
            steps: ["Spaghetti 3 Minuten in Salzwasser kochen.", "Knoblauch in Olivenöl anbraten und alles mischen."]
        )
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Pasta Aglio e Olio")).firstMatch.tap()
        let cook = app.buttons["Jetzt kochen"]
        XCTAssertTrue(cook.waitForExistence(timeout: 5))
        cook.tap()
        XCTAssertTrue(app.staticTexts["Erst mal alles bereitstellen"].waitForExistence(timeout: 5))

        // Einschalten: Chefi lugt unten rechts herein und erklärt kurz
        app.buttons["voice-toggle"].tap()
        XCTAssertTrue(app.buttons["voice-chefi"].waitForExistence(timeout: 3), "Chefi lugt nicht herein")
        XCTAssertTrue(app.descendants(matching: .any)["voice-hint"].waitForExistence(timeout: 2), "Kein Hinweis „Hey nomi, weiter“")
        snapshot(app, "70-voice-ready")

        // „Hey nomi, weiter“: erst Zuhören mit Leuchtrand, nach der Sprechpause blättert es um
        say(app, "Hey nomi, weiter")
        XCTAssertTrue(app.descendants(matching: .any)["voice-listening"].waitForExistence(timeout: 2), "Kein Zuhören nach „Hey nomi“")
        let listeningShot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        listeningShot.name = "71-voice-listening"
        listeningShot.lifetime = .keepAlways
        add(listeningShot)
        XCTAssertTrue(app.staticTexts["SCHRITT 1 VON 2"].waitForExistence(timeout: 5), "„weiter“ blättert nicht um")
        expectReply(app, containing: "Schritt 1")
        snapshot(app, "72-voice-reply")

        // Timer per Sprache
        say(app, "Hey nomi, Timer starten")
        XCTAssertTrue(app.buttons["Timer Schritt 1"].waitForExistence(timeout: 5), "Timer startet nicht per Sprache")
        expectReply(app, containing: "Läuft")
        say(app, "Hey nomi, wie lange noch?")
        expectReply(app, containing: "Noch")

        // Menge aus dem Rezept
        say(app, "Hey nomi, wie viel Spaghetti?")
        expectReply(app, containing: "200 g Spaghetti")
        snapshot(app, "73-voice-amount")

        // Zurück zur Vorbereitung
        say(app, "Hey nomi, zurück")
        XCTAssertTrue(app.staticTexts["VORBEREITUNG"].waitForExistence(timeout: 5), "„zurück“ blättert nicht zurück")

        // Freie Frage geht an nomi (Claude) – die Antwort steht in der Blase
        say(app, "Hey nomi, kann ich statt Olivenöl auch Butter nehmen?")
        let reply = app.descendants(matching: .any)["voice-reply"]
        XCTAssertTrue(reply.waitForExistence(timeout: 60), "Keine Antwort von nomi auf die Frage")
        XCTAssertGreaterThan(reply.label.count, 20, "Antwort von nomi ist leer: \(reply.label)")
        snapshot(app, "74-voice-answer")

        // Skript ist durch: Tipp auf Chefi hört ohne „Hey nomi“ zu, Tipp daneben bricht ab
        let listening = app.descendants(matching: .any)["voice-listening"]
        let gone = NSPredicate(format: "exists == false")
        // Auch während die Antwort noch steht
        XCTAssertTrue(reply.exists)
        app.buttons["voice-chefi"].tap()
        XCTAssertTrue(listening.waitForExistence(timeout: 3), "Tipp auf Chefi hört nicht zu")
        XCTAssertTrue(app.staticTexts["„Ich höre …“"].exists || app.descendants(matching: .any)["voice-heard"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: gone, evaluatedWith: listening)], timeout: 3), .completed, "Zuhören lässt sich nicht abbrechen")

        // Ausschalten: Chefi geht
        app.buttons["voice-toggle"].tap()
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: gone, evaluatedWith: app.buttons["voice-chefi"])], timeout: 3), .completed)
    }

    /// „Sagen“: Tipp auf Chefi schickt den nächsten Satz aus dem Skript wie ein fertiges Segment ab.
    /// `text` steht nur zur Lesbarkeit da und muss zur Reihenfolge im Skript passen.
    @MainActor
    private func say(_ app: XCUIApplication, _ text: String) {
        // Eine vorige Antwort darf noch stehen – Zuhören darf aber nicht mehr laufen
        let listening = app.descendants(matching: .any)["voice-listening"]
        let gone = NSPredicate(format: "exists == false")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: gone, evaluatedWith: listening)], timeout: 30), .completed)
        let button = app.buttons["voice-chefi"]
        XCTAssertTrue(button.waitForExistence(timeout: 3))
        button.tap()
    }

    @MainActor
    private func expectReply(_ app: XCUIApplication, containing text: String) {
        let reply = app.descendants(matching: .any).matching(identifier: "voice-reply")
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
        XCTAssertTrue(reply.waitForExistence(timeout: 6), "Antwort mit „\(text)“ fehlt")
    }
}
