import AVFoundation
import CoreMedia
import Speech

/// Durchgehendes Zuhören im Kochmodus – ganz auf dem Gerät über den SpeechAnalyzer von iOS 26.
/// Liefert Zwischenergebnisse je Segment (siehe `VoiceTurn`) und den Pegel fürs Wackeln der Balken.
/// Läuft auf Audio-Threads, deshalb nicht an den Main-Actor gebunden.
nonisolated final class CookingListener: @unchecked Sendable {
    struct Heard: Sendable {
        let text: String
        /// Beginn des Segments in Sekunden seit Start – gleich für alle Fassungen desselben Segments
        let segment: Double
        let isFinal: Bool
    }

    enum Failure: Error {
        case unsupported
        case microphone
    }

    let heard: AsyncStream<Heard>
    private let heardContinuation: AsyncStream<Heard>.Continuation
    let levels: AsyncStream<Float>
    private let levelContinuation: AsyncStream<Float>.Continuation

    private let engine = AVAudioEngine()
    private var analyzer: SpeechAnalyzer?
    private var inputContinuation: AsyncStream<AnalyzerInput>.Continuation?
    private var resultsTask: Task<Void, Never>?

    init() {
        (heard, heardContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(20))
        (levels, levelContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    /// Lädt bei Bedarf das deutsche Sprachmodell (einmalig) und startet Mikrofon und Erkennung.
    func start() async throws {
        let locale = Locale(identifier: "de-DE")
        let module: any SpeechModule
        let heardContinuation = self.heardContinuation
        // SpeechTranscriber ist genauer, gibt es aber nicht auf jedem Gerät – sonst die Diktat-Erkennung
        if SpeechTranscriber.isAvailable, let supported = await SpeechTranscriber.supportedLocale(equivalentTo: locale) {
            let transcriber = SpeechTranscriber(locale: supported, transcriptionOptions: [], reportingOptions: [.volatileResults, .fastResults], attributeOptions: [])
            module = transcriber
            resultsTask = Task {
                do {
                    for try await result in transcriber.results {
                        heardContinuation.yield(Heard(text: String(result.text.characters), segment: result.range.start.seconds, isFinal: result.isFinal))
                    }
                } catch {}
            }
        } else if let supported = await DictationTranscriber.supportedLocale(equivalentTo: locale) {
            let transcriber = DictationTranscriber(locale: supported, preset: .progressiveLongDictation)
            module = transcriber
            resultsTask = Task {
                do {
                    for try await result in transcriber.results {
                        heardContinuation.yield(Heard(text: String(result.text.characters), segment: result.range.start.seconds, isFinal: result.isFinal))
                    }
                } catch {}
            }
        } else {
            throw Failure.unsupported
        }

        if let request = try await AssetInventory.assetInstallationRequest(supporting: [module]) {
            try await request.downloadAndInstall()
        }

        let session = AVAudioSession.sharedInstance()
        // Aufnehmen und gleichzeitig vorlesen; Musik läuft weiter, Ton kommt aus dem Lautsprecher
        try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .mixWithOthers, .allowBluetoothA2DP])
        try session.setActive(true)

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0,
              let analyzerFormat = await SpeechAnalyzer.bestAvailableAudioFormat(compatibleWith: [module], considering: inputFormat),
              let converter = AVAudioConverter(from: inputFormat, to: analyzerFormat) else {
            throw Failure.microphone
        }

        let analyzer = SpeechAnalyzer(modules: [module])
        self.analyzer = analyzer
        let context = AnalysisContext()
        // Den Namen kennt die Erkennung nicht – so schreibt sie öfter „nomi“ statt „Naomi“
        context.contextualStrings[.general] = ["nomi", "Hey nomi", "Timer", "weiter", "zurück"]
        try? await analyzer.setContext(context)

        let (inputSequence, inputContinuation) = AsyncStream.makeStream(of: AnalyzerInput.self)
        self.inputContinuation = inputContinuation
        try await analyzer.start(inputSequence: inputSequence)

        let levelContinuation = self.levelContinuation
        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { @Sendable buffer, _ in
            levelContinuation.yield(Self.level(of: buffer))
            if let converted = Self.convert(buffer, with: converter, to: analyzerFormat) {
                inputContinuation.yield(AnalyzerInput(buffer: converted))
            }
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        if engine.isRunning { engine.stop() }
        engine.inputNode.removeTap(onBus: 0)
        inputContinuation?.finish()
        inputContinuation = nil
        resultsTask?.cancel()
        if let analyzer {
            Task { await analyzer.cancelAndFinishNow() }
        }
        analyzer = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    /// Lautstärke 0…1 für die Pegelbalken
    private static func level(of buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0], buffer.frameLength > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<Int(buffer.frameLength) { sum += data[index] * data[index] }
        let rms = (sum / Float(buffer.frameLength)).squareRoot()
        // Sprache liegt etwa bei -40…-10 dB
        let db = 20 * log10(max(rms, 0.000_01))
        return min(1, max(0, (db + 50) / 40))
    }

    private static func convert(_ buffer: AVAudioPCMBuffer, with converter: AVAudioConverter, to format: AVAudioFormat) -> AVAudioPCMBuffer? {
        if buffer.format == format { return buffer }
        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount((Double(buffer.frameLength) * ratio).rounded(.up)) + 16
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return nil }
        let provider = BufferProvider(buffer)
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            provider.next(inputStatus)
        }
        return status == .error || output.frameLength == 0 ? nil : output
    }
}

/// Gibt dem Konverter genau einen Puffer und meldet danach „gerade nichts“ –
/// so bleibt der Konverter für den nächsten Puffer offen.
private nonisolated final class BufferProvider: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?

    init(_ buffer: AVAudioPCMBuffer) {
        self.buffer = buffer
    }

    func next(_ status: UnsafeMutablePointer<AVAudioConverterInputStatus>) -> AVAudioBuffer? {
        guard let buffer else {
            status.pointee = .noDataNow
            return nil
        }
        self.buffer = nil
        status.pointee = .haveData
        return buffer
    }
}
