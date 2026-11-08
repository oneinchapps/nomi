import XCTest

/// Screenshots für den App Store: ein gut gefüllter Haushalt, acht Bildschirme. Läuft nur über
/// `scripts/store-screenshots.sh`, das den lokalen Service-Schlüssel hereinreicht (Daten an RLS vorbei anlegen,
/// z. B. Antworten von nomi und eine Vorschlagsrunde – ohne Claude, damit die Bilder immer gleich aussehen).
final class StoreScreenshotTests: NomiUITestCase {
    private var serviceKey: String? { ProcessInfo.processInfo.environment["NOMI_SERVICE_KEY"] }
    private var isPad: Bool { UIDevice.current.userInterfaceIdiom == .pad }

    override func tearDown() {
        XCUIDevice.shared.orientation = .portrait
        super.tearDown()
    }

    @MainActor
    func testStoreScreenshots() async throws {
        let key = try XCTUnwrap(serviceKey, "Nur über scripts/store-screenshots.sh starten")
        let app = try launchWithNewHousehold(name: "Alex")
        // iPad quer: zeigt Raster, Board und den zweispaltigen Kochmodus
        if isPad { XCUIDevice.shared.orientation = .landscapeLeft }

        let codeText = inviteCodeText(app)
        XCTAssertTrue(codeText.waitForExistence(timeout: 10))
        let sam = try await apiSignIn(email: "sam-\(run)@nomi.test")
        let household = try await api("POST", "/rest/v1/rpc/join_household", body: ["code": codeText.label, "display_name": "Sam"], as: sam)
        let householdId = try XCTUnwrap(household["id"] as? String)
        let members = try await apiList("/rest/v1/household_members?household_id=eq.\(householdId)&select=user_id,display_name", as: sam)
        let alexId = try XCTUnwrap(members.first { $0["display_name"] as? String == "Alex" }?["user_id"] as? String)
        let samId = try XCTUnwrap(members.first { $0["display_name"] as? String == "Sam" }?["user_id"] as? String)

        let seed = Seed(apiURL: apiURL, publishableKey: localKey, serviceKey: key, samToken: sam.token,
                        householdId: householdId, alexId: alexId, samId: samId)
        let recipes = try await seed.recipes()
        try await seed.plan(recipes)
        try await seed.cookingLog(recipes)
        let shopping = try await seed.shoppingList(recipes)
        try await seed.decideRound(recipes)
        try await seed.assistantChat()

        // 1 · Heute
        app.tab("Heute").tap()
        XCTAssertTrue(app.staticTexts["Linsen-Dal mit Kokosmilch"].waitForExistence(timeout: 15))
        pause()
        screen("01-heute")

        // 2 · Gemeinsam entscheiden
        // Die offene Runde zeigt sich am Abend als „Vorschläge laufen“
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Vorschläge laufen")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Ofengemüse mit Feta"].firstMatch.waitForExistence(timeout: 15))
        pause(2)
        screen("02-vorschlaege")
        app.buttons["Fertig"].firstMatch.tap()
        pause()

        // 3 · Rezepte, 4 · ein Rezept
        app.tab("Rezepte").tap()
        let dal = app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Halloumi-Tacos")).firstMatch
        XCTAssertTrue(dal.waitForExistence(timeout: 10))
        pause()
        screen("03-rezepte")
        dal.tap()
        XCTAssertTrue(app.buttons["Jetzt kochen"].waitForExistence(timeout: 5))
        pause()
        screen("04-rezept")

        // 7 · Kochen mit Timer (vorgezogen, das Rezept ist gerade offen)
        app.buttons["Jetzt kochen"].tap()
        app.buttons["Los geht's"].tap()
        XCTAssertTrue(app.buttons["Timer starten"].waitForExistence(timeout: 5))
        app.buttons["Timer starten"].tap()
        pause(2)
        screen("07-kochen")
        app.buttons["Kochmodus beenden"].tap()

        // 5 · Woche
        app.tab("Woche").tap()
        XCTAssertTrue(app.buttons["plan-Shakshuka"].waitForExistence(timeout: 10))
        pause()
        screen("05-woche")

        // 6 · Live einkaufen, Sam hakt gerade etwas ab
        app.tab("Einkauf").tap()
        let start = app.buttons["live-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()
        XCTAssertTrue(app.buttons["live-item-Kürbis"].waitForExistence(timeout: 10))
        app.buttons["live-item-Kürbis"].tap()
        try await seed.check(shopping["Ingwer"], by: samId)
        XCTAssertTrue(app.descendants(matching: .any)["abgehakt von Sam"].waitForExistence(timeout: 8))
        pause(0.5)
        screen("06-einkaufen")
        app.buttons["live-close"].tap()

        // 8 · nomi fragen
        app.tab("nomi").tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "restlichen Feta")).firstMatch.waitForExistence(timeout: 10))
        pause()
        screen("08-nomi")
    }

    /// Kurz warten, bis Animationen und Live-Updates durch sind
    private func pause(_ seconds: Double = 1) {
        Thread.sleep(forTimeInterval: seconds)
    }

    /// Ganzer Bildschirm (im Querformat liefert `app.screenshot()` ein verschobenes Bild)
    private func screen(_ name: String) {
        let shot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        shot.name = "store-\(isPad ? "ipad" : "iphone")-\(name)"
        shot.lifetime = .keepAlways
        add(shot)
    }
}

/// JSON kennt kein Optional: nil als null schreiben
private func orNull(_ value: Any?) -> Any { value ?? NSNull() }

/// Beispieldaten über die REST-API. Normale Daten legt Sam als Mitglied an (RLS wie in echt);
/// den Service-Schlüssel braucht es nur für Chat-Zeilen von nomi und Alex (dafür hat service_role Rechte).
private struct Seed {
    let apiURL: String
    let publishableKey: String
    let serviceKey: String
    let samToken: String
    let householdId: String
    let alexId: String
    let samId: String

    @discardableResult
    func insert(_ table: String, _ rows: [[String: Any]], service: Bool = false) async throws -> [[String: Any]] {
        var request = URLRequest(url: URL(string: "\(apiURL)/rest/v1/\(table)")!)
        request.httpMethod = "POST"
        request.setValue(service ? serviceKey : publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(service ? serviceKey : samToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("return=representation", forHTTPHeaderField: "Prefer")
        request.httpBody = try JSONSerialization.data(withJSONObject: rows)
        let (data, response) = try await URLSession.shared.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            throw NSError(domain: "seed", code: status, userInfo: [NSLocalizedDescriptionKey: "\(table): " + (String(data: data, encoding: .utf8) ?? "")])
        }
        return (try JSONSerialization.jsonObject(with: data) as? [[String: Any]]) ?? []
    }

    func check(_ itemId: String?, by userId: String) async throws {
        guard let itemId else { return }
        var request = URLRequest(url: URL(string: "\(apiURL)/rest/v1/shopping_items?id=eq.\(itemId)")!)
        request.httpMethod = "PATCH"
        request.setValue(publishableKey, forHTTPHeaderField: "apikey")
        request.setValue("Bearer \(samToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["checked": true, "checked_by": userId])
        _ = try await URLSession.shared.data(for: request)
    }

    private static func ingredient(_ name: String, _ quantity: Double?, _ unit: String?, _ aisle: String, note: String? = nil) -> [String: Any] {
        ["name": name, "quantity": orNull(quantity), "unit": orNull(unit), "note": orNull(note), "aisle": aisle]
    }

    private static func step(_ text: String, timer: Int? = nil) -> [String: Any] {
        ["text": text, "timer_seconds": orNull(timer)]
    }

    /// Titel → ID
    func recipes() async throws -> [String: String] {
        // Lokale Kurzformen; eine Funktionsreferenz verlöre die Standardwerte
        func i(_ name: String, _ quantity: Double?, _ unit: String?, _ aisle: String, note: String? = nil) -> [String: Any] {
            Seed.ingredient(name, quantity, unit, aisle, note: note)
        }
        func s(_ text: String, timer: Int? = nil) -> [String: Any] { Seed.step(text, timer: timer) }
        let list: [(String, String, Int, String, String, [[String: Any]], [[String: Any]])] = [
            ("Linsen-Dal mit Kokosmilch", "Cremig, wärmend und in einer halben Stunde fertig.", 30, "hauptgericht", "vegan",
             [i("rote Linsen", 200, "g", "trockenwaren"), i("Kokosmilch", 1, "Dose", "konserven"), i("Zwiebel", 1, nil, "obst_gemuese", note: "fein gewürfelt"), i("Currypulver", 2, "TL", "gewuerze_oele")],
             [s("Zwiebel in etwas Öl glasig dünsten, Currypulver kurz mitrösten."), s("Linsen, Kokosmilch und 300 ml Wasser dazugeben und 20 Minuten köcheln lassen.", timer: 1200), s("Mit Salz abschmecken und mit Reis servieren.")]),
            ("Halloumi-Tacos", "Knuspriger Halloumi, Limette, frischer Koriander.", 20, "hauptgericht", "vegetarisch",
             [i("Halloumi", 250, "g", "kuehlregal"), i("kleine Tortillas", 8, nil, "backwaren"), i("Limette", 1, nil, "obst_gemuese"), i("Koriander", 1, "Bund", "obst_gemuese"), i("Olivenöl", 2, "EL", "gewuerze_oele")],
             [s("Halloumi in Scheiben schneiden und in Olivenöl 4 Minuten goldbraun braten.", timer: 240), s("Tortillas in einer trockenen Pfanne kurz erwärmen."), s("Mit Halloumi und Koriander belegen, Limette darüber träufeln.")]),
            ("Spaghetti Carbonara", "Der Klassiker – ohne Sahne, mit Ei und Pecorino.", 20, "hauptgericht", "fleisch",
             [i("Spaghetti", 250, "g", "trockenwaren"), i("Guanciale", 100, "g", "kuehlregal"), i("Eier", 3, nil, "kuehlregal"), i("Pecorino", 50, "g", "kuehlregal")],
             [s("Spaghetti in Salzwasser 9 Minuten kochen.", timer: 540), s("Guanciale knusprig braten. Eier mit Pecorino verquirlen."), s("Nudeln mit etwas Kochwasser zum Speck geben, vom Herd nehmen und die Eimasse unterrühren.")]),
            ("Ofengemüse mit Feta", "Bunt, einfach und fast ohne Arbeit.", 40, "hauptgericht", "vegetarisch",
             [i("Paprika", 2, nil, "obst_gemuese"), i("Zucchini", 1, nil, "obst_gemuese"), i("Feta", 200, "g", "kuehlregal"), i("Olivenöl", 3, "EL", "gewuerze_oele")],
             [s("Gemüse in Stücke schneiden, mit Öl, Salz und Pfeffer mischen."), s("Feta in die Mitte legen und bei 200 °C 30 Minuten backen.", timer: 1800)]),
            ("Shakshuka", "Eier in würziger Tomatensauce, mit Brot zum Tunken.", 25, "hauptgericht", "vegetarisch",
             [i("Eier", 4, nil, "kuehlregal"), i("stückige Tomaten", 1, "Dose", "konserven"), i("Paprika", 1, nil, "obst_gemuese"), i("Kreuzkümmel", 1, "TL", "gewuerze_oele")],
             [s("Paprika weich dünsten, Tomaten und Kreuzkümmel dazugeben."), s("Mulden formen, Eier hineinsetzen und zugedeckt 8 Minuten stocken lassen.", timer: 480)]),
            ("Kürbissuppe mit Ingwer", "Samtig, leicht scharf, perfekt für den Herbst.", 35, "suppe", "vegan",
             [i("Hokkaido-Kürbis", 1, nil, "obst_gemuese"), i("Ingwer", 1, "Stück", "obst_gemuese"), i("Kokosmilch", 1, "Dose", "konserven"), i("Gemüsebrühe", 500, "ml", "gewuerze_oele")],
             [s("Kürbis würfeln, mit Ingwer anschwitzen."), s("Mit Brühe aufgießen und 20 Minuten köcheln lassen.", timer: 1200), s("Kokosmilch dazu und fein pürieren.")]),
            ("Pesto-Pasta mit Erbsen", "Grün, schnell und immer eine gute Idee.", 15, "hauptgericht", "vegetarisch",
             [i("Pasta", 250, "g", "trockenwaren"), i("Pesto", 1, "Glas", "konserven"), i("Erbsen", 150, "g", "tiefkuehl"), i("Parmesan", 30, "g", "kuehlregal")],
             [s("Pasta kochen, Erbsen die letzten 2 Minuten mitgaren.", timer: 600), s("Abgießen, mit Pesto und Parmesan mischen.")]),
            ("Kaiserschmarrn", "Fluffig, karamellisiert, mit Puderzucker.", 30, "dessert", "vegetarisch",
             [i("Mehl", 125, "g", "trockenwaren"), i("Milch", 250, "ml", "kuehlregal"), i("Eier", 3, nil, "kuehlregal", note: "getrennt"), i("Butter", 30, "g", "kuehlregal")],
             [s("Mehl, Milch und Eigelb verrühren, Eiweiß steif schlagen und unterheben."), s("Teig in Butter 5 Minuten stocken lassen, wenden, in Stücke reißen.", timer: 300)]),
        ]
        let rows = list.map { r -> [String: Any] in
            ["household_id": householdId, "title": r.0, "summary": r.1, "total_minutes": r.2, "servings": 2,
             "dish_type": r.3, "diet": r.4, "ingredients": r.5, "steps": r.6, "created_by": samId]
        }
        let inserted = try await insert("recipes", rows)
        return Dictionary(uniqueKeysWithValues: inserted.compactMap { row in
            (row["title"] as? String).flatMap { title in (row["id"] as? String).map { (title, $0) } }
        })
    }

    private static func day(_ offset: Int, from base: Date = .now) -> String {
        let date = Calendar(identifier: .gregorian).date(byAdding: .day, value: offset, to: base)!
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Heute Mittag Dal (Abend bleibt offen für die Vorschläge), dazu die Woche
    func plan(_ recipes: [String: String]) async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let monday = calendar.dateInterval(of: .weekOfYear, for: .now)!.start
        let todayKey = Seed.day(0)
        var rows: [[String: Any]] = [
            ["day": todayKey, "meal": "mittag", "recipe": "Linsen-Dal mit Kokosmilch"],
        ]
        let week: [(Int, String, String)] = [
            (0, "abend", "Shakshuka"), (1, "abend", "Pesto-Pasta mit Erbsen"), (3, "abend", "Spaghetti Carbonara"),
            (4, "abend", "Halloumi-Tacos"), (5, "mittag", "Kürbissuppe mit Ingwer"), (5, "abend", "Kaiserschmarrn"),
        ]
        for (offset, meal, title) in week where Seed.day(offset, from: monday) != todayKey {
            rows.append(["day": Seed.day(offset, from: monday), "meal": meal, "recipe": title])
        }
        try await insert("meal_plan_entries", rows.map { row in
            ["household_id": householdId, "day": row["day"]!, "meal": row["meal"]!, "recipe_id": recipes[row["recipe"] as! String]!,
             "servings": 2, "position": 0]
        })
    }

    func cookingLog(_ recipes: [String: String]) async throws {
        try await insert("cooking_log", [("Spaghetti Carbonara", -1), ("Ofengemüse mit Feta", -3), ("Kaiserschmarrn", -6)].map { title, offset in
            ["household_id": householdId, "recipe_id": recipes[title]!, "cooked_by": samId, "cooked_on": Seed.day(offset), "servings": 2]
        })
    }

    /// Name → ID
    func shoppingList(_ recipes: [String: String]) async throws -> [String: String] {
        let items: [(String, Double?, String?, String, String?, Bool)] = [
            ("Kürbis", 1, nil, "obst_gemuese", "Kürbissuppe mit Ingwer", false),
            ("Ingwer", 1, "Stück", "obst_gemuese", "Kürbissuppe mit Ingwer", false),
            ("Limetten", 2, nil, "obst_gemuese", "Halloumi-Tacos", false),
            ("Koriander", 1, "Bund", "obst_gemuese", "Halloumi-Tacos", false),
            ("kleine Tortillas", 8, nil, "backwaren", "Halloumi-Tacos", false),
            ("Halloumi", 250, "g", "kuehlregal", "Halloumi-Tacos", false),
            ("Pecorino", 50, "g", "kuehlregal", "Spaghetti Carbonara", false),
            ("Eier", 10, nil, "kuehlregal", nil, false),
            ("Hafermilch", 1, "l", "kuehlregal", nil, true),
            ("Spaghetti", 500, "g", "trockenwaren", "Spaghetti Carbonara", false),
            ("Kokosmilch", 2, "Dose", "konserven", nil, false),
            ("Erbsen", 150, "g", "tiefkuehl", "Pesto-Pasta mit Erbsen", false),
        ]
        let inserted = try await insert("shopping_items", items.map { item in
            ["household_id": householdId, "name": item.0, "quantity": orNull(item.1), "unit": orNull(item.2), "aisle": item.3,
             "recipe_id": orNull(item.4.flatMap { recipes[$0] }), "checked": item.5, "checked_by": item.5 ? samId : NSNull()]
        })
        return Dictionary(uniqueKeysWithValues: inserted.compactMap { row in
            (row["name"] as? String).flatMap { name in (row["id"] as? String).map { (name, $0) } }
        })
    }

    /// Offene Runde fürs Abendessen mit fünf Karten und einem kurzen Austausch
    func decideRound(_ recipes: [String: String]) async throws {
        let session = try await insert("decide_sessions", [["household_id": householdId, "status": "open", "meal": "abend", "created_by": samId]])
        let sessionId = try XCTUnwrap(session.first?["id"] as? String)
        let cards: [(String, String)] = [
            ("Ofengemüse mit Feta", "Viel Gemüse, und der Ofen macht die Arbeit."),
            ("Halloumi-Tacos", "In 20 Minuten auf dem Tisch."),
            ("Pesto-Pasta mit Erbsen", "Schnell und grün – passt zu „was Leichtes“."),
            ("Shakshuka", "Wärmt und braucht nur eine Pfanne."),
            ("Kürbissuppe mit Ingwer", "Leicht, aber satt machend."),
        ]
        try await insert("session_candidates", cards.enumerated().map { index, card in
            ["session_id": sessionId, "household_id": householdId, "recipe_id": recipes[card.0]!, "reason": card.1, "position": index]
        })
        try await insert("chat_messages", [
            ["session_id": sessionId, "household_id": householdId, "user_id": alexId, "content": "Was Leichtes mit Gemüse, bitte nicht zu lang"],
            ["session_id": sessionId, "household_id": householdId, "user_id": NSNull(), "content": "Fünf Ideen für heute Abend – swipt los!"],
        ], service: true)
    }

    func assistantChat() async throws {
        let base = Date.now.addingTimeInterval(-600)
        let iso = ISO8601DateFormatter()
        let messages: [(String?, String)] = [
            (alexId, "Plan uns für Donnerstag was Schnelles."),
            (nil, "Donnerstag gibt's Spaghetti Carbonara – in 20 Minuten fertig. Die Zutaten stehen schon auf eurer Liste."),
            (samId, "Und was machen wir mit dem restlichen Feta?"),
            (nil, "Zerbrösel ihn über die Shakshuka am Montag oder macht morgen Ofengemüse mit Feta – beides steht schon in eurer Sammlung."),
        ]
        try await insert("assistant_messages", messages.enumerated().map { index, message in
            ["household_id": householdId, "user_id": orNull(message.0), "content": message.1,
             "created_at": iso.string(from: base.addingTimeInterval(Double(index) * 40))]
        }, service: true)
    }
}
