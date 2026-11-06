import XCTest

final class ShoppingFlowTests: NomiUITestCase {
    @MainActor
    func testShoppingListFromRecipeWithLivePartner() async throws {
        let app = try launchWithNewHousehold()

        // Einladungscode für die zweite Person merken
        let codeText = inviteCodeText(app)
        XCTAssertTrue(codeText.waitForExistence(timeout: 10))
        let inviteCode = codeText.label

        createRecipe(app, title: "Halloumi-Tacos", ingredients: "250 g Halloumi\n8 kleine Tortillas\n2 EL Olivenöl\nSalz")

        // Aus dem Rezept auf die Liste – Gewürze & Öle sind abgewählt
        app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "Halloumi-Tacos")).firstMatch.tap()
        app.buttons["Einkaufen"].tap()
        XCTAssertTrue(app.staticTexts["Gewürze & Öle sind abgewählt – die habt ihr meist schon."].waitForExistence(timeout: 15))
        snapshot(app, "30-add-to-list")
        app.buttons["2 Zutaten hinzufügen"].tap()

        // Einkaufsliste nach Abteilungen
        app.tabBars.buttons["Einkauf"].tap()
        XCTAssertTrue(app.buttons["item-Halloumi"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-kleine Tortillas"].exists)
        XCTAssertTrue(app.staticTexts["KÜHLREGAL"].exists)
        XCTAssertTrue(app.staticTexts["BACKWAREN"].exists)
        XCTAssertFalse(app.buttons["item-Olivenöl"].exists)

        // Freitext, und Zusammenführen: noch einmal Halloumi → 500 g statt zweiter Zeile
        let field = app.textFields["Was fehlt? z. B. 2 l Milch"]
        field.tap()
        field.typeText("2 l Milch\n")
        field.typeText("250 g Halloumi\n")
        XCTAssertTrue(app.buttons["item-Milch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-Halloumi"].label.contains("500 g"), "Halloumi wurde nicht zusammengeführt: \(app.buttons["item-Halloumi"].label)")

        // Abhaken
        app.buttons["item-Milch"].tap()
        // „Im Wagen“ ist zugeklappt: Milch verschwindet aus der Liste
        let cart = app.buttons["cart-toggle"]
        XCTAssertTrue(cart.waitForExistence(timeout: 3))
        XCTAssertTrue(cart.label.contains("IM WAGEN · 1"), cart.label)
        XCTAssertEqual(cart.value as? String, "zugeklappt")
        XCTAssertFalse(app.buttons["item-Milch"].exists)
        snapshot(app, "31-shopping-list")
        cart.tap()
        XCTAssertTrue(app.buttons["item-Milch"].waitForExistence(timeout: 3))
        snapshot(app, "31b-cart-open")

        // Zweite Person, live: tritt bei, fügt hinzu, hakt ab, löscht
        let sam = try await apiSignIn(email: "sam-\(run)@nomi.test")
        let household = try await api("POST", "/rest/v1/rpc/join_household", body: ["code": inviteCode, "display_name": "Sam"], as: sam)
        let householdId = try XCTUnwrap(household["id"] as? String)

        let kaffee = try await api("POST", "/rest/v1/shopping_items", body: [
            "household_id": householdId, "name": "Kaffee", "aisle": "getraenke",
        ], as: sam)
        XCTAssertTrue(app.buttons["item-Kaffee"].waitForExistence(timeout: 10), "Eintrag der anderen Person kommt nicht live an")
        // Beitritt kommt ebenfalls live an: Einladungskarte im Heute-Tab ist weg
        app.tabBars.buttons["Heute"].tap()
        let invite = app.staticTexts["EINLADUNGSCODE"]
        await fulfillment(of: [expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: invite)], timeout: 10)
        app.tabBars.buttons["Einkauf"].tap()

        let tortillas = try await api("GET", "/rest/v1/shopping_items?name=eq.kleine%20Tortillas&select=id", as: sam)
        let samRow = try await api("GET", "/rest/v1/household_members?display_name=eq.Sam&select=user_id", as: sam)
        let samId = try XCTUnwrap(samRow["user_id"] as? String)
        try await api("PATCH", "/rest/v1/shopping_items?id=eq.\(try XCTUnwrap(tortillas["id"] as? String))",
                      body: ["checked": true, "checked_by": samId], as: sam)
        XCTAssertTrue(app.descendants(matching: .any)["abgehakt von Sam"].waitForExistence(timeout: 10), "Abhaken der anderen Person kommt nicht live an")
        XCTAssertTrue(app.buttons["cart-toggle"].label.contains("IM WAGEN · 2"))
        snapshot(app, "32-live-partner")

        try await api("DELETE", "/rest/v1/shopping_items?id=eq.\(try XCTUnwrap(kaffee["id"] as? String))", as: sam)
        let gone = NSPredicate(format: "exists == false")
        await fulfillment(of: [expectation(for: gone, evaluatedWith: app.buttons["item-Kaffee"])], timeout: 10)

        // Erledigte entfernen
        app.buttons["Leeren"].tap()
        let cartGone = expectation(for: gone, evaluatedWith: app.buttons["item-Milch"])
        await fulfillment(of: [cartGone], timeout: 5)
    }

    @MainActor
    func testCartHasRoomAtEndOfLongList() async throws {
        let app = try launchWithNewHousehold()
        let codeText = inviteCodeText(app)
        XCTAssertTrue(codeText.waitForExistence(timeout: 10))

        // Lange Liste über die zweite Person, ein Eintrag schon im Wagen
        let sam = try await apiSignIn(email: "sam-\(run)@nomi.test")
        let household = try await api("POST", "/rest/v1/rpc/join_household", body: ["code": codeText.label, "display_name": "Sam"], as: sam)
        let householdId = try XCTUnwrap(household["id"] as? String)
        let names = ["Äpfel", "Bananen", "Brot", "Butter", "Eier", "Gurke", "Joghurt", "Kaffee", "Käse", "Milch",
                     "Nudeln", "Paprika", "Reis", "Salat", "Tomaten", "Zwiebeln"]
        for name in names {
            _ = try await api("POST", "/rest/v1/shopping_items", body: [
                "household_id": householdId, "name": name, "aisle": "sonstiges", "checked": name == "Milch",
            ], as: sam)
        }

        app.tabBars.buttons["Einkauf"].tap()
        XCTAssertTrue(app.buttons["item-Äpfel"].waitForExistence(timeout: 10))
        // Ganz nach unten scrollen; vorher legt die Liste „Im Wagen“ noch gar nicht an
        for _ in 0..<3 { app.swipeUp() }
        try await Task.sleep(for: .seconds(1))
        let cart = app.buttons["cart-toggle"]
        XCTAssertTrue(cart.waitForExistence(timeout: 5))
        snapshot(app, "31c-cart-closed-bottom")

        let gap = app.tabBars.firstMatch.frame.minY - cart.frame.maxY
        XCTAssertGreaterThanOrEqual(gap, 40, "„Im Wagen“ klebt an der Tab-Leiste (Abstand \(gap) pt)")
    }

    @MainActor
    func testLiveShoppingWithPartner() async throws {
        let app = try launchWithNewHousehold()
        let codeText = inviteCodeText(app)
        XCTAssertTrue(codeText.waitForExistence(timeout: 10))

        let sam = try await apiSignIn(email: "sam-\(run)@nomi.test")
        let household = try await api("POST", "/rest/v1/rpc/join_household", body: ["code": codeText.label, "display_name": "Sam"], as: sam)
        let householdId = try XCTUnwrap(household["id"] as? String)
        var ids: [String: String] = [:]
        for (name, aisle) in [("Bananen", "obst_gemuese"), ("Äpfel", "obst_gemuese"), ("Brot", "backwaren"),
                              ("Milch", "kuehlregal"), ("Joghurt", "kuehlregal")] {
            let row = try await api("POST", "/rest/v1/shopping_items", body: ["household_id": householdId, "name": name, "aisle": aisle], as: sam)
            ids[name] = row["id"] as? String
        }
        let samRow = try await api("GET", "/rest/v1/household_members?display_name=eq.Sam&select=user_id", as: sam)
        let samId = try XCTUnwrap(samRow["user_id"] as? String)

        app.tabBars.buttons["Einkauf"].tap()
        let start = app.buttons["live-start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        snapshot(app, "36-live-start")
        start.tap()

        // Erste Abteilung, Fortschritt im Kopf
        XCTAssertTrue(app.staticTexts["Obst & Gemüse"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["live-progress"].label.contains("0 VON 5"), app.staticTexts["live-progress"].label)
        snapshot(app, "37-live-first-aisle")

        // Letztes Offene der Abteilung abhaken → weiter zur nächsten
        app.buttons["live-item-Bananen"].tap()
        app.buttons["live-item-Äpfel"].tap()
        XCTAssertTrue(app.staticTexts["Backwaren"].waitForExistence(timeout: 5), "Nicht zur nächsten Abteilung gesprungen")

        // Sam hakt im Kühlregal ab und kommt live an
        app.buttons["live-next"].tap()
        XCTAssertTrue(app.staticTexts["Kühlregal"].waitForExistence(timeout: 5))
        try await api("PATCH", "/rest/v1/shopping_items?id=eq.\(try XCTUnwrap(ids["Milch"]))",
                      body: ["checked": true, "checked_by": samId], as: sam)
        let milk = app.buttons["live-item-Milch"]
        await fulfillment(of: [expectation(for: NSPredicate(format: "value == 'erledigt'"), evaluatedWith: milk)], timeout: 6)
        XCTAssertTrue(app.descendants(matching: .any)["abgehakt von Sam"].exists)
        XCTAssertTrue(app.staticTexts["live-progress"].label.contains("3 VON 5"), app.staticTexts["live-progress"].label)
        snapshot(app, "38-live-partner")

        // Auge: „Im Wagen“ ausblenden – Milch verschwindet, sobald sie nicht mehr aufleuchtet
        let eye = app.buttons["live-toggle-cart"]
        XCTAssertEqual(eye.label, "Im Wagen ausblenden")
        eye.tap()
        let gone = NSPredicate(format: "exists == false")
        await fulfillment(of: [expectation(for: gone, evaluatedWith: milk)], timeout: 8)
        XCTAssertTrue(app.buttons["live-item-Joghurt"].exists)
        XCTAssertEqual(eye.label, "Im Wagen einblenden")
        snapshot(app, "38b-live-cart-hidden")
        eye.tap()
        XCTAssertTrue(milk.waitForExistence(timeout: 3))
        eye.tap() // für den Rest wieder ausgeblendet: Abgehaktes verschwindet beim Tippen

        // Rest abhaken → alles im Wagen
        app.buttons["live-item-Joghurt"].tap()
        await fulfillment(of: [expectation(for: gone, evaluatedWith: app.buttons["live-item-Joghurt"])], timeout: 3)
        XCTAssertTrue(app.staticTexts["Alles aus dieser Abteilung ist im Wagen."].waitForExistence(timeout: 3))
        app.buttons["live-prev"].tap()
        XCTAssertTrue(app.staticTexts["Backwaren"].waitForExistence(timeout: 5))
        app.buttons["live-item-Brot"].tap()
        XCTAssertTrue(app.staticTexts["Alles im Wagen!"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["5 Dinge, Sam hat 1 davon geholt."].exists)
        snapshot(app, "39-live-done")

        // Liste leeren und zurück
        app.buttons["live-finish-clear"].tap()
        XCTAssertTrue(app.staticTexts["Einkauf"].firstMatch.waitForExistence(timeout: 5))
        await fulfillment(of: [expectation(for: gone, evaluatedWith: app.buttons["item-Brot"])], timeout: 5)
        let left = try await apiList("/rest/v1/shopping_items?household_id=eq.\(householdId)&select=id", as: sam)
        XCTAssertTrue(left.isEmpty, "Liste wurde nicht geleert")
    }

    @MainActor
    func testAutocompleteKeepsAmount() throws {
        let app = try launchWithNewHousehold()
        createRecipe(app, title: "Tomatensuppe", ingredients: "1 Dose San-Marzano-Tomaten\n1 Zwiebel")
        app.tabBars.buttons["Einkauf"].tap()

        // Menge tippen, Name aus den Vorschlägen – auch Zutaten aus euren Rezepten
        let field = app.textFields["Was fehlt? z. B. 2 l Milch"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("2 Dosen San")
        let fromRecipe = app.buttons["Vorschlag: 2 Dosen San-Marzano-Tomaten"]
        XCTAssertTrue(fromRecipe.waitForExistence(timeout: 3))
        snapshot(app, "33-autocomplete")
        fromRecipe.tap()
        XCTAssertTrue(app.buttons["item-San-Marzano-Tomaten"].waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Was fehlt? z. B. 2 l Milch", "Feld wurde nach dem Vorschlag nicht geleert")

        // Grundwortschatz, Umlaute egal
        field.typeText("1 l hafe")
        let oat = app.buttons["Vorschlag: 1 l Hafermilch"]
        XCTAssertTrue(oat.waitForExistence(timeout: 3))
        oat.tap()
        XCTAssertTrue(app.buttons["item-Hafermilch"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-Hafermilch"].label.contains("1 l"))
    }

    @MainActor
    func testDragItemToAnotherAisleIsRemembered() throws {
        let app = try launchWithNewHousehold()
        app.tabBars.buttons["Einkauf"].tap()
        let field = app.textFields["Was fehlt? z. B. 2 l Milch"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Kombucha\n")
        field.typeText("Milch\n")
        field.typeText("Bananen\n")
        app.staticTexts["Einkauf"].firstMatch.tap() // Tastatur weg
        let kombucha = app.buttons["item-Kombucha"]
        XCTAssertTrue(kombucha.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["SONSTIGES"].exists)

        // Halten und auf die Milch ziehen → Kühlregal
        // Langsam ziehen: Wer zu schnell ist, bekommt im Simulator nur das Halte-Menü
        kombucha.press(forDuration: 0.8, thenDragTo: app.buttons["item-Milch"], withVelocity: .slow, thenHoldForDuration: 0.5)
        let gone = NSPredicate(format: "exists == false")
        if XCTWaiter.wait(for: [expectation(for: gone, evaluatedWith: app.staticTexts["SONSTIGES"])], timeout: 5) != .completed {
            snapshot(app, "fail-drag")
            XCTFail("Kombucha wurde nicht verschoben")
        }
        snapshot(app, "34-dragged-aisle")

        // Leere Abteilungen per Wischen nach rechts
        app.buttons["item-Bananen"].swipeRight()
        app.buttons["Abteilung"].tap()
        app.buttons["Getränke"].tap()
        XCTAssertTrue(app.staticTexts["GETRÄNKE"].waitForExistence(timeout: 5))
        snapshot(app, "35-aisle-dialog-done")

        // Gemerkt: neu eingetippte Kombucha landet gleich im Kühlregal
        kombucha.swipeLeft()
        app.buttons["Löschen"].tap()
        XCTAssertTrue(XCTWaiter.wait(for: [expectation(for: gone, evaluatedWith: kombucha)], timeout: 5) == .completed)
        field.tap()
        field.typeText("Kombucha\n")
        XCTAssertTrue(kombucha.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["SONSTIGES"].exists, "Abteilung wurde nicht gemerkt")
    }

    @MainActor
    func testStoresWithOwnOrderAndCategories() throws {
        let app = try launchWithNewHousehold()
        app.tabBars.buttons["Einkauf"].tap()
        let field = app.textFields["Was fehlt? z. B. 2 l Milch"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Bananen\n")
        field.typeText("Milch\n")
        field.typeText("Orangensaft\n")
        XCTAssertTrue(app.buttons["item-Orangensaft"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Sortiert für")).firstMatch.exists)

        // Zahnrad → Supermarkt anlegen
        app.buttons["Einstellungen fürs Einkaufen"].tap()
        app.buttons["Supermarkt hinzufügen"].tap()
        app.alerts.textFields.firstMatch.typeText("Rewe")
        app.alerts.buttons["Sichern"].tap()
        let rewe = app.collectionViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Rewe")).firstMatch
        XCTAssertTrue(rewe.waitForExistence(timeout: 5))
        snapshot(app, "36-shopping-settings")

        // Reihenfolge: Getränke am Griff ganz nach oben ziehen
        rewe.tap()
        let drinks = app.cells.containing(.staticText, identifier: "Getränke").firstMatch
        let first = app.cells.containing(.staticText, identifier: "Obst & Gemüse").firstMatch
        XCTAssertTrue(drinks.waitForExistence(timeout: 5))
        drinks.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: first.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.2)), withVelocity: .slow, thenHoldForDuration: 0.5)
        XCTAssertLessThan(drinks.frame.minY, first.frame.minY, "Getränke steht nicht oben")
        snapshot(app, "37-store-order")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        // Kategorien: eigene anlegen, feste umbenennen
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kategorien bearbeiten")).firstMatch.tap()
        app.buttons["Kategorie hinzufügen"].tap()
        app.alerts.textFields.firstMatch.typeText("Bio-Ecke")
        app.alerts.buttons["Sichern"].tap()
        XCTAssertTrue(app.staticTexts["Bio-Ecke"].waitForExistence(timeout: 5))
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Kühlregal")).firstMatch.tap()
        let nameField = app.alerts.textFields.firstMatch
        // Alten Namen löschen (Cursor steht am Ende)
        nameField.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Kühlregal".count) + "Kühltheke")
        app.alerts.buttons["Sichern"].tap()
        XCTAssertTrue(app.staticTexts["Kühltheke"].waitForExistence(timeout: 5))
        snapshot(app, "38-categories")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.navigationBars.buttons["Fertig"].firstMatch.tap()

        // Liste in Rewe-Reihenfolge, mit neuem Namen
        let picker = app.buttons["Sortiert für Rewe"]
        XCTAssertTrue(picker.waitForExistence(timeout: 5))
        let drinksHeader = app.staticTexts["GETRÄNKE"]
        XCTAssertTrue(drinksHeader.waitForExistence(timeout: 5))
        XCTAssertLessThan(drinksHeader.frame.minY, app.staticTexts["OBST & GEMÜSE"].frame.minY)
        XCTAssertTrue(app.staticTexts["KÜHLTHEKE"].exists)

        // In die eigene Kategorie legen
        app.buttons["item-Milch"].swipeRight()
        app.buttons["Abteilung"].tap()
        app.buttons["Bio-Ecke"].tap()
        XCTAssertTrue(app.staticTexts["BIO-ECKE"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["KÜHLTHEKE"].exists)
        snapshot(app, "39-list-by-store")
    }

    @MainActor
    func testDragPlanEntryToAnotherDay() throws {
        let app = try launchWithNewHousehold()
        createRecipe(app, title: "Linsensuppe", ingredients: "200 g rote Linsen")

        app.tabBars.buttons["Woche"].tap()
        // Montag planen
        let planMonday = app.buttons["Gericht für Montag planen"]
        XCTAssertTrue(planMonday.waitForExistence(timeout: 5))
        planMonday.tap()
        let pick = app.collectionViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Linsensuppe")).firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        pick.tap()

        let entry = app.buttons["plan-Linsensuppe"]
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        func header(_ weekday: String) -> XCUIElement {
            app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", weekday + ",")).firstMatch
        }
        XCTAssertLessThan(entry.frame.minY, header("Dienstag").frame.minY)

        // Halten und auf den Mittwoch ziehen
        entry.press(forDuration: 0.8, thenDragTo: header("Mittwoch"), withVelocity: .slow, thenHoldForDuration: 0.5)
        let onWednesday = NSPredicate { _, _ in
            entry.frame.minY > header("Mittwoch").frame.minY && entry.frame.minY < header("Donnerstag").frame.minY
        }
        if XCTWaiter.wait(for: [expectation(for: onWednesday, evaluatedWith: entry)], timeout: 5) != .completed {
            snapshot(app, "fail-plan-drag")
            XCTFail("Eintrag wurde nicht auf den Mittwoch verschoben")
        }
        snapshot(app, "44-week-dragged")

        // Bleibt nach dem Neuladen dort (gespeichert)
        app.buttons["Nächste Woche"].tap()
        let back = app.buttons["Zur aktuellen Woche"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        sleep(1) // Der Knopf kommt animiert herein; ein früher Tipp geht ins Leere
        back.tap()
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(entry.frame.minY, header("Mittwoch").frame.minY)
    }

    @MainActor
    func testWeekPlanAndShoppingForTheWeek() async throws {
        let app = try launchWithNewHousehold()
        createRecipe(app, title: "Shakshuka", ingredients: "6 Eier\n1 Dose Tomaten\n1 Paprika")

        app.tabBars.buttons["Woche"].tap()
        if !app.staticTexts["Diese Woche"].waitForExistence(timeout: 5) {
            snapshot(app, "fail-week")
            XCTFail("Wochenplan nicht sichtbar: \(app.staticTexts.allElementsBoundByIndex.prefix(12).map(\.label))")
            return
        }
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Gericht für")).firstMatch.tap()
        // Auf die Liste im Sheet beschränken – die Rezept-Kachel im (verborgenen) Rezepte-Tab ist auch ein Button
        let pick = app.collectionViews.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Shakshuka")).firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 5))
        snapshot(app, "41-recipe-picker")
        pick.tap()

        XCTAssertTrue(app.buttons.containing(NSPredicate(format: "label CONTAINS %@", "FÜR ZWEI")).firstMatch.waitForExistence(timeout: 5))
        snapshot(app, "40-week")

        // Nächste Woche ist leer, zurück zur aktuellen
        app.buttons["Nächste Woche"].tap()
        XCTAssertTrue(app.staticTexts["Nächste Woche"].waitForExistence(timeout: 3))
        snapshot(app, "43-next-week")
        XCTAssertFalse(app.buttons["Zutaten der Woche einkaufen"].exists)
        app.buttons["Zur aktuellen Woche"].tap()

        let shopWeek = app.buttons["Zutaten der Woche einkaufen"]
        XCTAssertTrue(shopWeek.waitForExistence(timeout: 5))
        while !shopWeek.isHittable { app.swipeUp() }
        snapshot(app, "42-week-scrolled")
        shopWeek.tap()
        app.buttons["3 Zutaten hinzufügen"].tap()

        app.tabBars.buttons["Einkauf"].tap()
        XCTAssertTrue(app.buttons["item-Eier"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["item-Tomaten"].exists)
        XCTAssertTrue(app.buttons["item-Paprika"].exists)
    }
}
