import AlarmKit
import AVFoundation
import SwiftUI

/// Koch-Timer als echter System-Timer (AlarmKit): klingelt wie der Timer der Uhr-App,
/// auch wenn das iPhone stumm, gesperrt oder die App im Hintergrund ist.
/// Ohne Erlaubnis fällt `CookingTimers` auf Mitteilung und eigenen Ton zurück.
enum CookingAlarm {
    /// Keine Daten nötig; AlarmKit verlangt trotzdem einen Typ
    nonisolated struct Metadata: AlarmMetadata {}

    static var isAvailable: Bool {
        #if DEBUG
        // UI-Tests: keine Rückfrage, die den Ablauf blockiert
        if ProcessInfo.processInfo.environment["NOMI_DISABLE_NOTIFICATIONS"] == "1" { return false }
        #endif
        return true
    }

    /// Fragt beim ersten Timer einmal nach; danach gilt die Antwort aus den Einstellungen.
    static func authorize() async -> Bool {
        guard isAvailable else { return false }
        switch AlarmManager.shared.authorizationState {
        case .authorized: return true
        case .denied: return false
        case .notDetermined: return (try? await AlarmManager.shared.requestAuthorization()) == .authorized
        @unknown default: return false
        }
    }

    /// Plant einen Timer; false, wenn AlarmKit nicht erlaubt ist oder das Planen scheitert.
    static func schedule(id: UUID, title: String, in seconds: TimeInterval) async -> Bool {
        guard seconds >= 1, await authorize() else { return false }
        let alert: AlarmPresentation.Alert
        if #available(iOS 26.1, *) {
            alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: title))
        } else {
            // iOS 26.0 braucht noch einen eigenen Stopp-Knopf
            alert = AlarmPresentation.Alert(
                title: LocalizedStringResource(stringLiteral: title),
                stopButton: AlarmButton(text: "Stopp", textColor: .white, systemImageName: "stop.fill")
            )
        }
        // Feste Farbe statt Color.brand: die Attribute werden kodiert, dynamische Farben gehen dabei verloren
        let attributes = AlarmAttributes<Metadata>(
            presentation: AlarmPresentation(alert: alert),
            tintColor: Color(red: 0.8, green: 0.2, blue: 0.37)
        )
        do {
            _ = try await AlarmManager.shared.schedule(id: id, configuration: .timer(duration: seconds, attributes: attributes))
            return true
        } catch {
            return false
        }
    }

    static func cancel(_ id: UUID) {
        try? AlarmManager.shared.cancel(id: id)
    }

    /// Klingelnden Timer verstummen lassen (in der App „Alles klar“ getippt)
    static func stop(_ id: UUID) {
        try? AlarmManager.shared.stop(id: id)
    }
}

/// Eigener Timer-Ton für die offene App, wenn AlarmKit nicht erlaubt ist. Die Audio-Sitzung `.playback`
/// spielt auch bei Stummschaltung – anders als System-Töne, die der Schalter verschluckt.
final class TimerChime {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?

    init() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1) else { return }
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        buffer = Self.makeChime(format: format)
    }

    /// Zweimal „di-di-dong“, gut zwei Sekunden
    func play() {
        guard let buffer else { return }
        let session = AVAudioSession.sharedInstance()
        do {
            // Hört nomi im Kochmodus gerade zu, bleibt die Sitzung mit Aufnahme – die übergeht die
            // Stummschaltung genauso, und das Mikrofon läuft weiter
            if session.category != .playAndRecord {
                try session.setCategory(.playback, options: [.duckOthers])
            }
            try session.setActive(true)
            if !engine.isRunning { try engine.start() }
        } catch {
            return
        }
        player.stop()
        player.scheduleBuffer(buffer, at: nil)
        player.scheduleBuffer(buffer, at: nil)
        player.play()
        // Kein Completion-Handler: der käme auf dem Audio-Thread an (Swift-6-Falle), Warten reicht hier
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.6))
            self?.player.stop()
            self?.engine.stop()
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    private static func makeChime(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let rate = format.sampleRate
        // (Frequenz, Dauer) – Pause als Frequenz 0
        let notes: [(Double, Double)] = [(880, 0.12), (0, 0.06), (880, 0.12), (0, 0.06), (1320, 0.32), (0, 0.42)]
        // Länge aus denselben gerundeten Einzelwerten wie unten – sonst ist der Puffer ein paar Samples zu kurz
        let counts = notes.map { Int($0.1 * rate) }
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(counts.reduce(0, +))),
              let samples = buffer.floatChannelData?[0] else { return nil }
        var index = 0
        for ((frequency, duration), count) in zip(notes, counts) {
            for n in 0..<count {
                let t = Double(n) / rate
                // Weich ein- und ausblenden, sonst knackt es
                let envelope = min(1, t / 0.01) * min(1, (duration - t) / 0.04)
                samples[index + n] = frequency == 0 ? 0 : Float(sin(2 * .pi * frequency * t) * 0.5 * envelope)
            }
            index += count
        }
        buffer.frameLength = AVAudioFrameCount(index)
        return buffer
    }
}
