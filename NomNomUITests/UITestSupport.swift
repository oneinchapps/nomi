import XCTest

/// Gemeinsame Helfer. Alle UI-Tests laufen gegen ein lokales `supabase start`
/// (API auf 55321, Mailpit auf 55324).
class NomNomUITestCase: XCTestCase {
    let apiURL = "http://127.0.0.1:55321"
    let mailpitURL = "http://127.0.0.1:55324"
    let localKey = "sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"

    /// Eindeutig pro Testlauf, damit sich Mailadressen nicht überschneiden.
    let run = UUID().uuidString.prefix(8).lowercased()

    override func setUp() {
        continueAfterFailure = false
    }

    @MainActor
    func launchFresh() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "NOMNOM_SUPABASE_URL": apiURL,
            "NOMNOM_SUPABASE_KEY": localKey,
            "NOMNOM_RESET_SESSION": "1",
        ]
        app.launch()
        XCTAssertTrue(app.buttons["Gemeinsam Essen finden"].waitForExistence(timeout: 10))
        return app
    }

    /// Neustart ohne Abmelden – prüft, dass die Sitzung im (gemeinsamen) Keychain liegt.
    @MainActor
    func relaunchKeepingSession(_ app: XCUIApplication) -> XCUIApplication {
        app.terminate()
        let again = XCUIApplication()
        again.launchEnvironment = [
            "NOMNOM_SUPABASE_URL": apiURL,
            "NOMNOM_SUPABASE_KEY": localKey,
        ]
        again.launch()
        return again
    }

    /// Welcome → E-Mail → Code. Endet auf der Haushalts-Einrichtung.
    @MainActor
    func signIn(_ app: XCUIApplication, email: String, screenshotPrefix: String? = nil) throws {
        app.buttons["Gemeinsam Essen finden"].tap()
        let emailField = app.textFields["name@beispiel.de"]
        XCTAssertTrue(emailField.waitForExistence(timeout: 5))
        emailField.typeText(email)
        if let p = screenshotPrefix { snapshot(app, "\(p)2-email") }
        app.buttons["Code schicken"].tap()

        let codeField = app.textFields["Code aus der Mail"]
        XCTAssertTrue(codeField.waitForExistence(timeout: 10), "Code-Screen erscheint nicht")
        let otp = try fetchCode(for: email)
        if let p = screenshotPrefix { snapshot(app, "\(p)3-code") }
        codeField.typeText(otp)
        XCTAssertTrue(app.textFields["Vorname"].waitForExistence(timeout: 10), "Nach dem Code sollte die Haushalts-Einrichtung kommen")
    }

    /// Kompletter Weg bis in die App mit eigenem, neuem Haushalt.
    @MainActor
    func launchWithNewHousehold(name: String = "Alex") throws -> XCUIApplication {
        let app = launchFresh()
        try signIn(app, email: "\(name.lowercased())-\(run)@nomnom.test")
        let field = app.textFields["Vorname"]
        field.tap()
        field.typeText(name)
        app.buttons["Haushalt anlegen"].tap()
        XCTAssertTrue(app.staticTexts["Worauf habt ihr Lust?"].waitForExistence(timeout: 10))
        return app
    }

    /// Holt den Code aus der neuesten Mail an diese Adresse in Mailpit.
    func fetchCode(for email: String) throws -> String {
        let deadline = Date.now.addingTimeInterval(15)
        while Date.now < deadline {
            let query = "to:\"\(email)\"".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            if let list = try? json("\(mailpitURL)/api/v1/search?query=\(query)"),
               let id = (list["messages"] as? [[String: Any]])?.first?["ID"] as? String,
               let message = try? json("\(mailpitURL)/api/v1/message/\(id)"),
               let text = (message["Text"] as? String) ?? (message["HTML"] as? String),
               let range = text.range(of: #"\b\d{6}\b"#, options: .regularExpression) {
                return String(text[range])
            }
            Thread.sleep(forTimeInterval: 0.5)
        }
        throw XCTSkip("Keine Mail für \(email) in Mailpit – läuft `supabase start`?")
    }

    private func json(_ url: String) throws -> [String: Any] {
        let data = try Data(contentsOf: URL(string: url)!)
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }

    @MainActor
    func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
