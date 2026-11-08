import AVFoundation
import Observation
import Speech

/// „Hey nomi“ im Kochmodus: hört durchgehend zu (auf dem Gerät), erkennt Weckwort und Befehl,
/// lässt die Ansicht den Befehl ausführen und liest die Antwort vor.
@Observable
final class CookingVoice {
    enum Phase: Equatable {
        case off
        /// Mikrofon und Sprachmodell starten (beim ersten Mal lädt iOS das Modell)
        case starting
        /// Wartet auf „Hey nomi“
        case ready
        /// „Hey nomi“ gehört, der Befehl kommt
        case listening
        /// Befehl wird ausgeführt bzw. nomi überlegt (Frage an die Cloud)
        case thinking
        /// Antwort steht da und wird vorgelesen
        case answering
        case unavailable(String)
    }

    struct Reply: Equatable {
        /// Kurz für die Sprechblase
        var display: String
        /// Zum Vorlesen; nil = still
        var speech: String?

        init(_ display: String, speech: String? = nil) {
            self.display = display
            self.speech = speech
        }

        /// Anzeigen und genauso vorlesen
        static func said(_ text: String) -> Reply { Reply(text, speech: text) }
    }

    private(set) var phase: Phase = .off
    /// Was nach „Hey nomi“ verstanden wurde
    private(set) var heardText = ""
    private(set) var reply: Reply?
    /// Pegel 0…1 fürs Zuhören
    private(set) var level: Float = 0

    var isOn: Bool {
        switch phase {
        case .off, .unavailable: false
        default: true
        }
    }

    /// Führt den Befehl aus (in der Kochansicht) – bekommt auch den gesprochenen Text für Fragen
    @ObservationIgnored var perform: ((CookingCommand, String) async -> Reply)?

    @ObservationIgnored private var listener: CookingListener?
    @ObservationIgnored private var turn = VoiceTurn()
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []
    @ObservationIgnored private var replyTask: Task<Void, Never>?
    @ObservationIgnored private var interruptionObserver: NSObjectProtocol?
    @ObservationIgnored private let speaker = Speaker()
    /// Kurz nach dem Vorlesen klingt nomis Stimme noch nach – so lange zählt nichts
    @ObservationIgnored private var mutedUntil = Date.distantPast
    /// UI-Tests: kein Mikrofon, Gesagtes kommt über `inject`
    @ObservationIgnored private let isSimulated: Bool
    @ObservationIgnored private var injectedSegment = 0.0

    init() {
        speaker.managesSession = false
        #if DEBUG
        isSimulated = ProcessInfo.processInfo.environment["NOMI_VOICE_TEST"] == "1"
        #else
        isSimulated = false
        #endif
    }

    // MARK: - Ein und aus

    func start() async {
        switch phase {
        case .off, .unavailable: break
        default: return
        }
        phase = .starting
        if isSimulated {
            begin(with: nil)
            return
        }
        guard await Self.authorize() else {
            phase = .unavailable("Erlaube nomi das Mikrofon in den Einstellungen, dann hört nomi beim Kochen zu.")
            return
        }
        let listener = CookingListener()
        do {
            try await listener.start()
        } catch CookingListener.Failure.unsupported {
            listener.stop()
            phase = .unavailable("Auf diesem Gerät gibt es die Sprachsteuerung leider nicht.")
            return
        } catch {
            listener.stop()
            phase = .unavailable("Das Mikrofon lässt sich gerade nicht nutzen. Probier es gleich noch mal.")
            return
        }
        // Inzwischen ausgeschaltet?
        guard phase == .starting else {
            listener.stop()
            return
        }
        begin(with: listener)
    }

    private func begin(with listener: CookingListener?) {
        self.listener = listener
        turn = VoiceTurn()
        // UI-Tests: Zuhören länger stehen lassen, damit der Test es sicher sieht
        if isSimulated { turn.pause = 3 }
        phase = .ready
        if let listener {
            tasks.append(Task { [weak self] in
                for await heard in listener.heard { self?.receive(heard) }
            })
            tasks.append(Task { [weak self] in
                for await level in listener.levels { self?.level = level }
            })
            observeInterruptions()
        }
        // Fünfmal pro Sekunde: Sprechpause erreicht?
        tasks.append(Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                self?.tick()
            }
        })
    }

    func stop() {
        tasks.forEach { $0.cancel() }
        tasks = []
        replyTask?.cancel()
        listener?.stop()
        listener = nil
        speaker.stop()
        if let interruptionObserver { NotificationCenter.default.removeObserver(interruptionObserver) }
        interruptionObserver = nil
        turn.finish()
        heardText = ""
        reply = nil
        level = 0
        phase = .off
    }

    /// Meldung („gibt es nicht“) wegtippen
    func clearProblem() {
        if case .unavailable = phase { phase = .off }
    }

    // MARK: - Zuhören

    /// Tipp auf Chefi: zuhören ohne „Hey nomi“ – hilft, wenn die Dunstabzugshaube laut ist
    func listenNow() {
        guard phase == .ready || phase == .answering else { return }
        speaker.stop()
        replyTask?.cancel()
        reply = nil
        turn.wake(at: .now)
        heardText = ""
        phase = .listening
    }

    /// Tipp auf die gedimmte Fläche: doch nichts sagen
    func dismiss() {
        guard phase == .listening else { return }
        turn.finish()
        heardText = ""
        phase = .ready
    }

    #if DEBUG
    /// UI-Tests: so tun, als wäre das gerade gesagt worden (ein abgeschlossenes Segment)
    func inject(_ text: String) {
        injectedSegment += 1
        receive(CookingListener.Heard(text: text, segment: injectedSegment, isFinal: true))
    }
    #endif

    private func receive(_ heard: CookingListener.Heard) {
        // Eigene Stimme und alles während nomi überlegt, gehört nicht zum nächsten Befehl
        if speaker.isSpeaking || Date.now < mutedUntil || phase == .thinking {
            turn.ignore(segment: heard.segment)
            return
        }
        guard phase == .ready || phase == .listening || phase == .answering else { return }
        switch turn.update(text: heard.text, segment: heard.segment, at: .now) {
        case .woke(let text):
            replyTask?.cancel()
            reply = nil
            heardText = text
            phase = .listening
        case .heard(let text):
            heardText = text
        default:
            break
        }
    }

    private func tick() {
        switch turn.tick(at: .now) {
        case .command(let text):
            Task { await run(text) }
        case .timeout:
            heardText = ""
            if phase == .listening { phase = .ready }
        default:
            break
        }
    }

    private func run(_ text: String) async {
        heardText = text
        phase = .thinking
        let reply = await perform?(CookingCommand.parse(text), text) ?? Reply("Das hab ich nicht verstanden.")
        guard phase == .thinking else { return }
        show(reply)
    }

    private func show(_ reply: Reply) {
        self.reply = reply
        phase = .answering
        if let speech = reply.speech, !isSimulated {
            speaker.speak(speech)
        }
        replyTask?.cancel()
        replyTask = Task { [weak self] in
            // Warten, bis fertig vorgelesen ist, dann noch kurz stehen lassen
            while self?.speaker.isSpeaking == true {
                try? await Task.sleep(for: .milliseconds(200))
            }
            guard let self, !Task.isCancelled else { return }
            mutedUntil = .now.addingTimeInterval(0.6)
            try? await Task.sleep(for: .seconds(isSimulated ? 4 : (reply.speech == nil ? 2.5 : 2)))
            guard !Task.isCancelled, phase == .answering else { return }
            self.reply = nil
            phase = .ready
        }
    }

    // MARK: - System

    /// Ein Anruf oder ein System-Alarm unterbricht die Aufnahme – danach neu starten
    private func observeInterruptions() {
        interruptionObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification, object: nil, queue: .main
        ) { [weak self] note in
            let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            MainActor.assumeIsolated {
                guard let self, raw == AVAudioSession.InterruptionType.ended.rawValue else { return }
                self.restart()
            }
        }
    }

    /// Nach Unterbrechung oder Rückkehr in die App
    func restart() {
        guard isOn, !isSimulated else { return }
        stop()
        Task { await start() }
    }

    private static func authorize() async -> Bool {
        guard await AVAudioApplication.requestRecordPermission() else { return false }
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .authorized { return true }
        if status != .notDetermined { return false }
        return await withCheckedContinuation { continuation in
            // Kommt auf einem beliebigen Thread zurück – darf nicht an den Main-Actor gebunden sein
            SFSpeechRecognizer.requestAuthorization { @Sendable status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }
}
