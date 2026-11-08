import Foundation

/// „Hey nomi“ im Gehörten finden. Die Erkennung schreibt den Namen mal so, mal so
/// („Nomi“, „Nomie“, „Naomi“, „No mi“) – alles zählt.
enum WakeWord {
    private static let pattern = try! NSRegularExpression(
        pattern: #"(?:\b(?:hey|hei|hej|he|hallo|ok|okay)[\s,.!]+)?\b(?:nomi|nomie|nomy|nommi|nommie|naomi|noemi|no mi)\b[\s,.!?:;-]*"#,
        options: [.caseInsensitive]
    )

    /// Was nach dem letzten „nomi“ gesagt wurde („“ wenn noch nichts), nil ohne Weckwort
    static func command(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = pattern.matches(in: text, range: range).last,
              let end = Range(match.range, in: text)?.upperBound else { return nil }
        return String(text[end...]).trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
}

/// Was die Person im Kochmodus will. Kurze Befehle erkennt die App selbst, alles andere ist eine Frage an nomi.
enum CookingCommand: Equatable {
    case next
    case back
    case repeatStep
    case ingredients
    /// „Wie viel Salz?“ → „salz“
    case amount(String)
    case startTimer
    case stopTimer
    case timeLeft
    /// „Alles klar“, „Stopp“ – beendet vor allem den Alarm
    case okay
    case finish
    case question(String)
    case unknown

    static func parse(_ text: String) -> CookingCommand {
        let normalized = text.lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        let words = normalized.split(separator: " ").map(String.init)
        guard !words.isEmpty else { return .unknown }
        let padded = " \(normalized) "
        func has(_ phrase: String) -> Bool { padded.contains(" \(phrase) ") }
        func hasPrefix(_ prefix: String) -> Bool { words.contains { $0.hasPrefix(prefix) } }
        // Navigation nur bei kurzen Sätzen – „kann ich weiter rühren?“ ist eine Frage, kein Umblättern
        let short = words.count <= 5

        if has("wie lange") || has("wie lang") || hasPrefix("restzeit") || has("wie viel zeit") || has("wieviel zeit") {
            return .timeLeft
        }
        if hasPrefix("timer") || hasPrefix("wecker") || hasPrefix("countdown") || hasPrefix("stoppuhr") {
            let stop = ["stopp", "stop", "paus", "anhalt", "halt", "aus", "beend", "abbrech"]
            return words.contains { word in stop.contains { word.hasPrefix($0) } } ? .stopTimer : .startTimer
        }
        for phrase in ["wie viel", "wieviel", "wie viele", "wieviele"] where has(phrase) {
            let rest = padded.components(separatedBy: " \(phrase) ").last ?? ""
            let fillers: Set = [
                "brauche", "brauch", "brauchen", "braucht", "ich", "wir", "man", "du", "denn", "kommt", "kommen", "rein",
                "hinein", "davon", "von", "an", "der", "die", "das", "den", "dem", "des", "noch", "nehme", "nehmen",
                "nimmt", "muss", "müssen", "insgesamt", "gibt", "es", "soll", "sollen", "für", "bitte", "eigentlich", "nomi",
            ]
            let query = rest.split(separator: " ").map(String.init).filter { !fillers.contains($0) }.joined(separator: " ")
            return query.isEmpty ? .ingredients : .amount(query)
        }
        if has("was brauch") || has("was brauche") || has("was brauchen") || hasPrefix("zutat") { return .ingredients }
        if has("nochmal") || has("noch mal") || has("noch einmal") || hasPrefix("wiederhol") || hasPrefix("vorles")
            || has("lies") || has("vorlesen") || has("was steht") {
            return .repeatStep
        }
        if short {
            if hasPrefix("weiter") || hasPrefix("nächst") || has("vorwärts") || has("next") { return .next }
            if hasPrefix("zurück") || hasPrefix("vorherig") || hasPrefix("vorig") { return .back }
            // „Ist das gut so?“ ist eine Frage – Bestätigungen sind höchstens drei Wörter
            if words.count <= 3, has("alles klar") || has("ok") || has("okay") || has("stopp") || has("stop") || has("danke")
                || has("ruhe") || has("verstanden") || has("aus") || has("gut") {
                return .okay
            }
            if words.count <= 2 && (hasPrefix("fertig") || hasPrefix("geschafft")) { return .finish }
        }
        return words.count >= 2 ? .question(text.trimmingCharacters(in: .whitespacesAndNewlines)) : .unknown
    }
}

extension Ingredient {
    /// Beste Zutat zu „salz“, „knoblauch“, „spaghetti“ – nil ohne Treffer
    static func best(matching query: String, in ingredients: [Ingredient]) -> Ingredient? {
        func fold(_ text: String) -> String {
            text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "de-DE"))
        }
        /// Grobe Stammform: „Zwiebeln“ → „zwiebel“, „Tomaten“ → „tomat“
        func stem(_ word: String) -> String {
            for suffix in ["en", "n", "e", "s"] where word.count > 4 && word.hasSuffix(suffix) {
                return String(word.dropLast(suffix.count))
            }
            return word
        }
        func words(_ text: String) -> [String] {
            fold(text).split { !$0.isLetter }.map(String.init).filter { $0.count >= 3 }.map(stem)
        }
        let target = fold(query).trimmingCharacters(in: .whitespaces)
        let targetWords = words(query)
        guard !target.isEmpty else { return nil }
        var best: (score: Int, ingredient: Ingredient)?
        for ingredient in ingredients {
            let name = fold(ingredient.name)
            let nameWords = words(ingredient.name)
            var score = 0
            if name == target {
                score = 4
            } else if name.contains(target) || (target.contains(name) && name.count >= 3) {
                score = 3
            } else if targetWords.contains(where: { word in nameWords.contains(word) }) {
                score = 2
            } else if targetWords.contains(where: { word in nameWords.contains { $0.hasPrefix(word) || word.hasPrefix($0) } }) {
                score = 1
            }
            if score > (best?.score ?? 0) { best = (score, ingredient) }
        }
        return best?.ingredient
    }

    /// Zum Vorlesen und Anzeigen: „200 g Spaghetti“, „Salz nach Geschmack“
    var spokenAmount: String {
        let amount = amountText
        return amount.isEmpty ? "\(name) nach Geschmack" : "\(amount) \(name)"
    }
}

/// Wann ein gesprochener Befehl fertig ist. Bekommt die Zwischenergebnisse der Erkennung,
/// die in Abschnitte (Segmente) zerfallen: Ein Segment wird so lange überarbeitet, bis es endgültig ist.
/// Ablauf: „Hey nomi“ weckt auf, danach zählt alles bis zu einer kurzen Sprechpause als Befehl –
/// auch über mehrere Segmente („Hey nomi.“ … „Wie viel Salz?“).
struct VoiceTurn {
    enum Event: Equatable {
        /// „nomi“ gehört; Text danach (oft noch leer)
        case woke(String)
        /// Der Befehl wächst
        case heard(String)
        /// Sprechpause: fertiger Befehl
        case command(String)
        /// Nach „Hey nomi“ kam nichts mehr
        case timeout
    }

    var pause: TimeInterval = 1.2
    var wakeTimeout: TimeInterval = 7

    private(set) var isAwake = false
    private var wakeSegment: Double?
    /// Befehlstext je Segment seit dem Weckwort (beim Weck-Segment nur der Teil danach)
    private var segments: [Double: String] = [:]
    private var lastChange = Date.distantPast
    private var awakeSince = Date.distantPast
    /// Segmente bis hier sind erledigt – ihre Nachzügler (endgültige Fassung) lösen nichts mehr aus
    private var handledThrough = -Double.infinity
    /// Segmente, in denen nomi selbst gesprochen hat
    private var ignored: Set<Double> = []

    var commandText: String {
        segments.sorted { $0.key < $1.key }.map(\.value).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// Ohne „Hey nomi“ zuhören, z. B. nach einem Tipp auf Chefi
    mutating func wake(at now: Date) {
        isAwake = true
        wakeSegment = nil
        segments = [:]
        awakeSince = now
        lastChange = now
    }

    /// Alles, was gerade in diesem Segment läuft, gehört nicht zur Person (nomi spricht selbst)
    mutating func ignore(segment: Double) {
        ignored.insert(segment)
    }

    mutating func update(text: String, segment: Double, at now: Date) -> Event? {
        guard segment > handledThrough, !ignored.contains(segment) else { return nil }
        if !isAwake {
            guard let command = WakeWord.command(in: text) else { return nil }
            isAwake = true
            wakeSegment = segment
            segments = [segment: command]
            awakeSince = now
            lastChange = now
            return .woke(command)
        }
        let command: String
        if let afterWake = WakeWord.command(in: text) {
            command = afterWake
            if segment != wakeSegment, (wakeSegment ?? -.infinity) < segment {
                // Nochmal „Hey nomi“ gesagt: neu anfangen
                wakeSegment = segment
                segments = [:]
            }
        } else if segment == wakeSegment {
            // Die Erkennung hat das Weckwort umgeschrieben – das Bisherige bleibt
            return nil
        } else {
            command = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let before = Self.words(commandText)
        segments[segment] = command
        guard Self.words(commandText) != before else { return nil }
        lastChange = now
        return .heard(commandText)
    }

    mutating func tick(at now: Date) -> Event? {
        guard isAwake else { return nil }
        let text = commandText
        if Self.words(text).isEmpty {
            guard now.timeIntervalSince(awakeSince) >= wakeTimeout else { return nil }
            finish()
            return .timeout
        }
        guard now.timeIntervalSince(lastChange) >= pause else { return nil }
        finish()
        return .command(text)
    }

    /// Zurück zum Warten auf „Hey nomi“
    mutating func finish() {
        if let last = segments.keys.max() ?? wakeSegment { handledThrough = max(handledThrough, last) }
        isAwake = false
        wakeSegment = nil
        segments = [:]
    }

    private static func words(_ text: String) -> [String] {
        text.lowercased().split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }
}

extension CookingFormat {
    /// Zum Vorlesen: „4 Minuten 30 Sekunden“, „1 Stunde 5 Minuten“, „40 Sekunden“
    static func spoken(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        var parts: [String] = []
        if h > 0 { parts.append(h == 1 ? "1 Stunde" : "\(h) Stunden") }
        if m > 0 { parts.append(m == 1 ? "1 Minute" : "\(m) Minuten") }
        // Sekunden nur bei kurzen Restzeiten, sonst wird es zu lang
        if s > 0 && h == 0 && m < 5 { parts.append(s == 1 ? "1 Sekunde" : "\(s) Sekunden") }
        return parts.isEmpty ? "0 Sekunden" : parts.joined(separator: " ")
    }
}

/// Texte zum Vorlesen im Kochmodus
enum CookingSpeech {
    private static let units: [(String, String)] = [
        ("EL", "Esslöffel"), ("TL", "Teelöffel"), ("kg", "Kilogramm"), ("g", "Gramm"), ("ml", "Milliliter"),
        ("cl", "Zentiliter"), ("l", "Liter"), ("Msp", "Messerspitze"), ("Pck", "Packung"), ("Pkg", "Packung"),
        ("Stk", "Stück"), ("St", "Stück"),
    ]

    /// „2 EL Öl, 200 g Mehl, 180 °C“ → „2 Esslöffel Öl, 200 Gramm Mehl, 180 Grad“ –
    /// die Sprachausgabe buchstabiert Abkürzungen sonst
    static func speakable(_ text: String) -> String {
        var result = text.replacingOccurrences(of: #"\s?°\s?C\b"#, with: " Grad", options: .regularExpression)
        for (short, long) in units {
            result = result.replacingOccurrences(
                of: #"(?<=[\d½¼¾⅓⅔])\s?"# + short + #"\.?(?![\p{L}])"#,
                with: " " + long,
                options: .regularExpression
            )
        }
        return result.replacingOccurrences(of: #"\bca\."#, with: "circa", options: .regularExpression)
    }

    /// „Salz, Pfeffer und Öl“
    static func list(_ parts: [String]) -> String {
        guard parts.count > 1 else { return parts.first ?? "" }
        return parts.dropLast().joined(separator: ", ") + " und " + parts.last!
    }
}
