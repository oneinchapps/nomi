import XCTest

/// Kein Funktionstest – fotografiert alle Illustrationen für Design-Reviews (hell und dunkel).
final class IllustrationGalleryTests: XCTestCase {
    @MainActor
    func testGallerySnapshot() {
        for appearance in ["light", "dark"] {
            let app = XCUIApplication()
            // Dark Mode in der Galerie erzwungen – die Simulator-Einstellung kommt nicht zuverlässig an
            app.launchEnvironment = ["NOMNOM_GALLERY": appearance]
            app.launch()
            XCTAssertTrue(app.staticTexts["teller"].waitForExistence(timeout: 5))
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "gallery-\(appearance)"
            attachment.lifetime = .keepAlways
            add(attachment)
            app.terminate()
        }
    }
}
