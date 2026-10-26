import XCTest

/// Profil oben rechts: steht auf jedem Hauptscreen ganz rechts, Profilfoto hochladen und entfernen.
final class ProfileTests: NomiUITestCase {
    private let photo = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent()
        .appendingPathComponent("Fixtures/avatar.jpg")
        .path

    @MainActor
    func testProfileButtonRightmostAndAvatarUpload() throws {
        let app = try launchWithNewHousehold(extraEnvironment: ["NOMI_TEST_PHOTOS": photo])
        let profile = app.buttons["Haushalt und Konto"].firstMatch

        // Ganz rechts – auch neben den eigenen Knöpfen von Rezepte und nomi
        app.tabBars.buttons["Rezepte"].tap()
        let add = app.buttons["Rezept hinzufügen"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(profile.frame.minX, add.frame.maxX, "Profil steht bei Rezepte nicht ganz rechts")
        app.tabBars.buttons["nomi"].tap()
        let speaker = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Vorlesen'")).firstMatch
        XCTAssertTrue(speaker.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(profile.frame.minX, speaker.frame.maxX, "Profil steht bei nomi nicht ganz rechts")
        snapshot(app, "120-profile-initials")

        // Foto hochladen
        profile.tap()
        let edit = app.buttons["Profilfoto ändern"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        app.buttons["Foto auswählen"].tap()
        XCTAssertTrue(app.images["avatar-photo"].firstMatch.waitForExistence(timeout: 15), "Profilfoto erscheint nicht")
        snapshot(app, "121-profile-sheet-photo")
        app.buttons["Fertig"].tap()
        XCTAssertTrue(profile.descendants(matching: .image)["avatar-photo"].waitForExistence(timeout: 10) || app.images["avatar-photo"].exists)
        snapshot(app, "122-profile-photo-header")

        // Und wieder entfernen
        profile.tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        app.buttons["Foto entfernen"].tap()
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.images["avatar-photo"].firstMatch)
        wait(for: [gone], timeout: 10)
    }

    /// Konto löschen (Pflicht für den App Store): danach zurück zum Willkommensbildschirm
    @MainActor
    func testDeleteAccount() throws {
        let app = try launchWithNewHousehold()
        app.buttons["Haushalt und Konto"].firstMatch.tap()
        let delete = app.buttons["Konto löschen"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        let confirm = app.buttons["Konto endgültig löschen"]
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        snapshot(app, "123-delete-account")
        confirm.tap()
        XCTAssertTrue(app.buttons["Gemeinsam Essen finden"].waitForExistence(timeout: 20), "Nach dem Löschen sollte der Willkommensbildschirm kommen")
    }
}
