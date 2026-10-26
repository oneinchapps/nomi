import Foundation
import Testing
@testable import nomi

struct SilenceDetectorTests {
    let start = Date(timeIntervalSinceReferenceDate: 0)

    @Test func schicktNachSprechpauseAb() {
        var detector = SilenceDetector(startedAt: start)
        detector.update("Was essen", at: start + 1)
        detector.update("Was essen wir heute", at: start + 2)
        #expect(detector.decision(at: start + 3) == .keepListening)
        #expect(detector.decision(at: start + 3.6) == .finish)
    }

    @Test func gleicherTextVerlaengertDiePauseNicht() {
        var detector = SilenceDetector(startedAt: start)
        detector.update("Was essen wir heute", at: start + 1)
        // Die Erkennung meldet dasselbe noch einmal, nur mit Satzzeichen
        detector.update("Was essen wir heute?", at: start + 2)
        detector.update("Was essen wir heute?", at: start + 2.4)
        #expect(detector.decision(at: start + 2.6) == .finish)
    }

    @Test func ohneWorteNachEinerWeileAbbrechen() {
        let detector = SilenceDetector(startedAt: start)
        #expect(detector.decision(at: start + 5) == .keepListening)
        #expect(detector.decision(at: start + 8) == .cancel)
    }

    @Test func spaetestensNachDreissigSekunden() {
        var detector = SilenceDetector(startedAt: start)
        for second in stride(from: 1.0, through: 29.0, by: 1.0) {
            detector.update("Wort \(Int(second))", at: start + second)
        }
        #expect(detector.decision(at: start + 30) == .finish)
    }
}
