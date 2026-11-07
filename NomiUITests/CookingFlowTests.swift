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
        // Chefi klopft von innen ans Display: Bildfolge, ohne auf „idle“ zu warten (die Animation läuft)
        for index in 0..<14 {
            let frame = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            frame.name = String(format: "62-alarm-%02d", index)
            frame.lifetime = .keepAlways
            add(frame)
            Thread.sleep(forTimeInterval: 0.25)
        }
        let ok = app.buttons["timer-alarm-ok"]
        XCTAssertTrue(ok.waitForExistence(timeout: 8), "Kein Alarm, als der Timer abgelaufen ist")
        XCTAssertEqual(app.staticTexts["timer-alarm-title"].label, "Schritt 1 ist fertig!")
        snapshot(app, "62-cooking-timer-done")
        ok.tap()
        let gone = NSPredicate(format: "exists == false")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: gone, evaluatedWith: ok)], timeout: 3), .completed, "Alarm geht nicht weg")

        // Schritt 2 zeigt beide Zutaten
        app.buttons["Weiter"].tap()
        XCTAssertTrue(app.staticTexts["SCHRITT 2 VON 2"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["2 Zehen Knoblauch"].exists)
        XCTAssertTrue(app.staticTexts["4 EL Olivenöl"].exists)
        snapshot(app, "63-cooking-step2")

        app.buttons["Weiter"].tap()
        // Chefi tanzt vor Glück: Bildfolge ohne Warten auf „idle“
        for index in 0..<12 {
            let frame = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            frame.name = String(format: "64-done-%02d", index)
            frame.lifetime = .keepAlways
            add(frame)
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertTrue(app.staticTexts["Guten Appetit!"].waitForExistence(timeout: 3))
        app.buttons["Fertig"].tap()
        XCTAssertTrue(cook.waitForExistence(timeout: 3), "Nach dem Kochen zurück in der Rezeptansicht")
    }

    /// Mit Erlaubnis klingelt der Timer als System-Timer (AlarmKit) – auch wenn nomi im Hintergrund ist.
    @MainActor
    func testTimerRingsAsSystemAlarm() throws {
        let app = try launchWithNewHousehold(extraEnvironment: ["NOMI_DISABLE_NOTIFICATIONS": "0"])
        createRecipe(app, title: "Tee", ingredients: "1 Beutel Tee", steps: ["Tee 6 Sekunden ziehen lassen."])
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Tee")).firstMatch.tap()
        let cook = app.buttons["Jetzt kochen"]
        XCTAssertTrue(cook.waitForExistence(timeout: 5))
        cook.tap()
        app.buttons["Los geht's"].tap()
        app.buttons["Timer starten"].tap()

        // Einmalige Rückfrage von AlarmKit
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(NSPredicate(format: "label IN {'Erlauben', 'Allow'}")).firstMatch
        if allow.waitForExistence(timeout: 5) { allow.tap() }

        // nomi in den Hintergrund – geklingelt wird trotzdem
        XCUIDevice.shared.press(.home)
        let alarm = springboard.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "Schritt 1 ist fertig")).firstMatch
        let rang = alarm.waitForExistence(timeout: 15)
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "63-cooking-system-alarm"
        shot.lifetime = .keepAlways
        add(shot)
        XCTAssertTrue(rang, "Kein System-Timer im Hintergrund")
    }
}
