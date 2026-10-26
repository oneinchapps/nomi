import XCTest

/// Spielt beide Personen durch: A legt den Haushalt an, B tritt mit dem angezeigten Code bei.
final class OnboardingFlowTests: NomNomUITestCase {
    @MainActor
    func testTwoPeopleShareAHousehold() throws {
        // Person A
        let a = launchFresh()
        snapshot(a, "01-welcome")
        try signIn(a, email: "a-\(run)@nomnom.test", screenshotPrefix: "0")
        snapshot(a, "04-household-setup")

        let name = a.textFields["Vorname"]
        name.tap()
        name.typeText("Alex")
        a.buttons["Haushalt anlegen"].tap()

        XCTAssertTrue(a.staticTexts["EINLADUNGSCODE"].waitForExistence(timeout: 10), "Nach dem Anlegen sollte der Einladungscode erscheinen")
        let codeText = a.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[A-Z0-9]{6}$")).firstMatch
        XCTAssertTrue(codeText.waitForExistence(timeout: 5), "Kein 6-stelliger Code auf dem Screen")
        let code = codeText.label
        snapshot(a, "05-home-with-invite")

        // Person B
        let b = launchFresh()
        try signIn(b, email: "b-\(run)@nomnom.test")

        let bName = b.textFields["Vorname"]
        bName.tap()
        bName.typeText("Sam")
        b.buttons["Ich habe einen Code"].tap()
        let codeField = b.textFields["ABC123"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 3))
        codeField.tap()
        codeField.typeText(code.lowercased())
        snapshot(b, "06-join")
        b.buttons["Beitreten"].tap()

        // B ist drin, der Einladungs-Hinweis verschwindet, beide stehen im Haushalt
        XCTAssertTrue(b.staticTexts["Was gibt es heute?"].waitForExistence(timeout: 10))
        XCTAssertFalse(b.staticTexts["EINLADUNGSCODE"].exists)
        b.buttons["Haushalt und Konto"].tap()
        XCTAssertTrue(b.staticTexts["Alex"].waitForExistence(timeout: 5))
        XCTAssertTrue(b.staticTexts["Sam"].exists)
        snapshot(b, "07-household-sheet")
    }
}
