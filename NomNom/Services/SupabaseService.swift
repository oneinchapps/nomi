import Foundation
import Supabase

/// Projekt „nomnom“ (eu-central-1). Der Publishable Key ist für Clients gedacht und darf in der App stehen;
/// alle Zugriffe sind per Row Level Security auf den eigenen Haushalt beschränkt.
let supabase = SupabaseClient(
    supabaseURL: SupabaseEnvironment.url,
    supabaseKey: SupabaseEnvironment.key,
    options: SupabaseClientOptions(
        auth: .init(
            // Gemeinsamer Keychain-Bereich, damit die Teilen-Erweiterung die Anmeldung der App mitnutzt
            storage: KeychainLocalStorage(service: "nomnom.auth", accessGroup: SupabaseEnvironment.keychainGroup),
            emitLocalSessionAsInitialSession: true
        )
    )
)

enum SupabaseEnvironment {
    /// „<TeamID>.de.gregorzoller.nomnom.shared“, aus der Info.plist, weil die Team-ID erst beim Signieren feststeht.
    static var keychainGroup: String? {
        (Bundle.main.object(forInfoDictionaryKey: "KeychainAccessGroup") as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    static var url: URL {
        #if DEBUG
        // UI-Tests und lokale Entwicklung zeigen per Umgebungsvariable auf `supabase start`
        if let local = ProcessInfo.processInfo.environment["NOMNOM_SUPABASE_URL"], let url = URL(string: local) {
            return url
        }
        #endif
        return URL(string: "https://pohguhbhqvurdhnflpek.supabase.co")!
    }

    static var key: String {
        #if DEBUG
        if let local = ProcessInfo.processInfo.environment["NOMNOM_SUPABASE_KEY"] {
            return local
        }
        #endif
        return "sb_publishable_Hv2JSw9p_1q10ldOqVRe_A_ho1pa1pH"
    }
}

/// Übersetzt Fehler aus Auth und Datenbank in Sätze, die man in der App zeigen kann.
func userMessage(for error: Error) -> String {
    if let auth = error as? AuthError {
        switch auth.errorCode {
        case .overEmailSendRateLimit, .overRequestRateLimit:
            return "Zu viele Versuche. Warte kurz und probier es dann noch mal."
        case .otpExpired:
            return "Der Code ist abgelaufen oder falsch. Fordere einfach einen neuen an."
        case .emailAddressNotAuthorized:
            return "An diese Adresse kann noch keine Mail verschickt werden. Dafür muss im Supabase-Projekt ein eigener Mailversand eingerichtet sein."
        default:
            break
        }
    }
    if let db = error as? PostgrestError {
        if db.message.contains("invalid invite code") {
            return "Diesen Einladungscode gibt es nicht. Prüf ihn noch mal."
        }
        if db.message.contains("already in a household") {
            return "Du bist schon in einem Haushalt."
        }
    }
    if (error as? URLError) != nil {
        return "Keine Verbindung. Prüf dein Internet."
    }
    return "Da ist etwas schiefgelaufen. Probier es noch mal."
}
