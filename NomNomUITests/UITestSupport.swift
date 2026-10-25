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

    /// Rezept über den Editor anlegen; endet in der Rezeptsammlung.
    @MainActor
    func createRecipe(_ app: XCUIApplication, title: String, ingredients: String, steps: [String] = []) {
        app.tabBars.buttons["Rezepte"].tap()
        let firstRecipe = app.buttons["Erstes Rezept anlegen"]
        if firstRecipe.waitForExistence(timeout: 5) {
            firstRecipe.tap()
        } else {
            app.buttons["Rezept hinzufügen"].tap()
            app.buttons["Von Hand anlegen"].tap()
        }
        let titleField = app.textFields["z. B. Halloumi-Tacos"]
        XCTAssertTrue(titleField.waitForExistence(timeout: 5))
        titleField.tap()
        titleField.typeText(title)
        let ingredientsField = app.textViews["editor-ingredients"]
        ingredientsField.tap()
        ingredientsField.typeText(ingredients)
        for (index, step) in steps.enumerated() {
            if index > 0 { app.buttons["Schritt hinzufügen"].tap() }
            let field = app.descendants(matching: .any)["step-\(index + 1)"]
            field.tap()
            field.typeText(step)
        }
        app.buttons["Sichern"].tap()
        XCTAssertTrue(
            app.buttons.containing(NSPredicate(format: "label CONTAINS %@", title)).firstMatch.waitForExistence(timeout: 10)
        )
    }

    // MARK: - Zweite Person über die API (für Realtime-Tests)

    struct APIUser {
        let token: String
    }

    /// Meldet eine Person per Mail-Code an der lokalen Auth-API an.
    func apiSignIn(email: String) async throws -> APIUser {
        _ = try await api("POST", "/auth/v1/otp", body: ["email": email, "create_user": true])
        let code = try fetchCode(for: email)
        let session = try await api("POST", "/auth/v1/verify", body: ["type": "email", "email": email, "token": code])
        return APIUser(token: try XCTUnwrap(session["access_token"] as? String))
    }

    @discardableResult
    func api(_ method: String, _ path: String, body: Any? = nil, as user: APIUser? = nil) async throws -> [String: Any] {
        var request = URLRequest(url: URL(string: apiURL + path)!)
        request.httpMethod = method
        request.setValue(localKey, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        if let user { request.setValue("Bearer \(user.token)", forHTTPHeaderField: "Authorization") }
        if let body { request.httpBody = try JSONSerialization.data(withJSONObject: body) }
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw NSError(domain: "api", code: status, userInfo: [NSLocalizedDescriptionKey: String(data: data, encoding: .utf8) ?? ""])
        }
        let json = data.isEmpty ? nil : try JSONSerialization.jsonObject(with: data)
        if let object = json as? [String: Any] { return object }
        if let array = json as? [[String: Any]], let first = array.first { return first }
        return [:]
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
