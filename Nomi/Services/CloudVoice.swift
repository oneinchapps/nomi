import Foundation
import Supabase

/// Holt nomis Stimme (ElevenLabs) über die Function `speak`. Der Schlüssel bleibt im Backend.
/// Klappt es nicht – kein Netz, nicht eingerichtet, Tageslimit –, liest der Speaker mit der Gerätestimme vor.
enum CloudVoice {
    /// Kurze Sätze wiederholen sich („Läuft.“, ein Schritt nach „zurück“) – die gibt es dann sofort und gratis
    private static var cache: [String: Data] = [:]
    private static var cacheOrder: [String] = []
    private static let cacheLimit = 40
    /// Nicht eingerichtet oder Limit erreicht: bis zum nächsten Start nicht mehr fragen
    private static var isDisabled = false

    /// Länger warten lohnt nicht – dann lieber gleich die Gerätestimme
    static let timeout: TimeInterval = 8

    static func audio(for text: String) async -> Data? {
        if let cached = cache[text] { return cached }
        guard !isDisabled, !isSkippedForTests else { return nil }
        do {
            let data: Data = try await supabase.functions.invoke(
                "speak",
                options: FunctionInvokeOptions(body: ["text": text], timeoutInterval: timeout)
            ) { @Sendable data, _ in data }
            guard !data.isEmpty else { return nil }
            remember(data, for: text)
            return data
        } catch let FunctionsError.httpError(code, _) {
            // 503 = keine Stimme eingerichtet, 429 = Tageslimit; 502 kann ein Aussetzer sein
            if code == 503 || code == 429 { isDisabled = true }
            return nil
        } catch {
            return nil
        }
    }

    private static func remember(_ data: Data, for text: String) {
        cache[text] = data
        cacheOrder.append(text)
        if cacheOrder.count > cacheLimit {
            cache[cacheOrder.removeFirst()] = nil
        }
    }

    /// UI-Tests sollen kein Geld für Stimmen ausgeben
    private static var isSkippedForTests: Bool {
        #if DEBUG
        ProcessInfo.processInfo.environment["NOMI_LOCAL_VOICE"] == "1"
        #else
        false
        #endif
    }
}
