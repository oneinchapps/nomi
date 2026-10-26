import AVFoundation
import Observation
import Speech

/// Spracheingabe auf Deutsch – wenn das iPhone es kann, ganz auf dem Gerät.
/// Antippen startet, eine kurze Pause (oder erneutes Antippen) beendet und liefert den Text.
@Observable
final class VoiceInput {
    enum State: Equatable {
        case idle
        case listening
        case unavailable(String)
    }

    private(set) var state: State = .idle
    /// Was bisher verstanden wurde – live, während man spricht
    private(set) var transcript = ""
    /// Bekommt den fertigen Text, sobald die Aufnahme endet
    var onFinished: ((String) -> Void)?

    private var session: RecognitionSession?
    private var silence: Task<Void, Never>?

    /// So lange Stille nach dem letzten Wort beendet die Aufnahme
    static let pause: Duration = .milliseconds(1600)
    static let maxDuration: Duration = .seconds(30)

    var isListening: Bool { state == .listening }

    func toggle() {
        if isListening {
            finish()
        } else {
            Task { await start() }
        }
    }

    func start() async {
        guard !isListening else { return }
        guard await Self.authorize() else {
            state = .unavailable("Erlaube nomi Mikrofon und Spracherkennung in den Einstellungen.")
            return
        }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "de-DE")), recognizer.isAvailable else {
            state = .unavailable("Die Spracherkennung ist gerade nicht verfügbar.")
            return
        }
        transcript = ""
        let session: RecognitionSession
        do {
            session = try RecognitionSession(recognizer: recognizer)
        } catch {
            state = .unavailable("Das Mikrofon lässt sich gerade nicht nutzen.")
            return
        }
        self.session = session
        state = .listening
        restartSilenceTimer(after: Self.maxDuration)
        for await text in session.transcripts {
            transcript = text
            restartSilenceTimer(after: Self.pause)
        }
        finish()
    }

    /// Beenden und den bisherigen Text abschicken
    func finish() {
        guard isListening else { return }
        silence?.cancel()
        session?.stop()
        session = nil
        state = .idle
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty { onFinished?(text) }
    }

    /// Beenden, ohne etwas zu schicken
    func cancel() {
        transcript = ""
        finish()
    }

    private func restartSilenceTimer(after duration: Duration) {
        silence?.cancel()
        silence = Task { [weak self] in
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            self?.finish()
        }
    }

    private static func authorize() async -> Bool {
        let speech = await withCheckedContinuation { continuation in
            // Kommt auf einem beliebigen Thread zurück – darf nicht an den Main-Actor gebunden sein
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speech else { return false }
        return await AVAudioApplication.requestRecordPermission()
    }
}

/// Mikrofon → Spracherkennung. Läuft auf Audio-Threads, deshalb nicht an den Main-Actor gebunden.
nonisolated final class RecognitionSession: @unchecked Sendable {
    let transcripts: AsyncStream<String>
    private let continuation: AsyncStream<String>.Continuation
    private let engine = AVAudioEngine()
    private let request = SFSpeechAudioBufferRecognitionRequest()
    private var task: SFSpeechRecognitionTask?

    init(recognizer: SFSpeechRecognizer) throws {
        (transcripts, continuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))

        let audio = AVAudioSession.sharedInstance()
        try audio.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audio.setActive(true, options: .notifyOthersOnDeactivation)

        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        let request = self.request
        let input = engine.inputNode
        input.installTap(onBus: 0, bufferSize: 1024, format: input.outputFormat(forBus: 0)) { @Sendable buffer, _ in
            request.append(buffer)
        }
        engine.prepare()
        try engine.start()

        let continuation = self.continuation
        task = recognizer.recognitionTask(with: request) { @Sendable result, error in
            if let result {
                continuation.yield(result.bestTranscription.formattedString)
            }
            if error != nil || result?.isFinal == true {
                continuation.finish()
            }
        }
    }

    func stop() {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        request.endAudio()
        task?.finish()
        continuation.finish()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}

/// nomi liest Antworten vor – mit der besten installierten deutschen Stimme.
@Observable
final class Speaker: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var isSpeaking = false
    private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        stop()
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
        try? AVAudioSession.sharedInstance().setActive(true)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = Self.voice
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        isSpeaking = false
    }

    /// Premium vor Erweitert vor Standard
    private static var voice: AVSpeechSynthesisVoice? {
        AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == "de-DE" }
            .max { $0.quality.rawValue < $1.quality.rawValue }
            ?? AVSpeechSynthesisVoice(language: "de-DE")
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in self.isSpeaking = false }
    }
}
