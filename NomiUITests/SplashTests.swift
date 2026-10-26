import XCTest

/// Splash mit Chefi: Nach der Animation (rund eine Sekunde) übernimmt der Willkommensscreen.
/// Die Animation selbst ist kürzer, als XCUITest zum Starten braucht – geprüft wird die Übergabe.
final class SplashTests: NomiUITestCase {
    @MainActor
    func testSplashHandsOverToWelcome() {
        let app = XCUIApplication()
        app.launchEnvironment = [
            "NOMI_SUPABASE_URL": apiURL,
            "NOMI_SUPABASE_KEY": localKey,
            "NOMI_RESET_SESSION": "1",
            "NOMI_DISABLE_NOTIFICATIONS": "1",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Gemeinsam Essen finden"].waitForExistence(timeout: 10))
        let splash = app.descendants(matching: .any)["splash"]
        let gone = expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: splash)
        wait(for: [gone], timeout: 5)
        XCTAssertTrue(app.buttons["Gemeinsam Essen finden"].isHittable, "Willkommensscreen liegt noch unter dem Splash")
    }
}
