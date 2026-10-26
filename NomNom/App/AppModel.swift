import Foundation
import Observation
import Supabase

/// Hält Anmeldung und Haushalt und entscheidet damit, welcher Bereich der App sichtbar ist.
@Observable
final class AppModel {
    enum Phase: Equatable {
        case loading
        case signedOut
        case needsHousehold
        case ready
    }

    private(set) var phase: Phase = .loading
    private(set) var userId: UUID?
    private(set) var household: Household?
    private(set) var members: [HouseholdMember] = []
    /// Per Einladungscode angemeldet, ohne echte Mailadresse
    private(set) var signedInWithoutEmail = false

    var me: HouseholdMember? { members.first { $0.userId == userId } }
    var partner: HouseholdMember? { members.first { $0.userId != userId } }

    /// Läuft für die Lebensdauer der App und folgt jeder Änderung der Anmeldung.
    func observeAuth() async {
        #if DEBUG
        // UI-Tests starten jeweils frisch abgemeldet
        if ProcessInfo.processInfo.environment["NOMNOM_RESET_SESSION"] == "1" {
            try? await supabase.auth.signOut(scope: .local)
        }
        #endif
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .userUpdated:
                if let session {
                    userId = session.user.id
                    signedInWithoutEmail = session.user.email?.hasSuffix("@einladung.nomnom.invalid") ?? false
                    await loadHousehold()
                } else {
                    reset()
                }
            case .signedOut:
                reset()
            default:
                break
            }
        }
    }

    func loadHousehold() async {
        guard let userId else { return }
        do {
            let mine: [HouseholdMember] = try await supabase
                .from("household_members")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            guard let membership = mine.first else {
                household = nil
                members = []
                phase = .needsHousehold
                return
            }
            try await loadHousehold(id: membership.householdId)
            phase = .ready
        } catch {
            // Ohne Verbindung lieber den letzten Stand zeigen als zurück zum Login
            if household != nil {
                phase = .ready
            } else if error is AuthError {
                reset()
            } else {
                phase = .needsHousehold
            }
        }
    }

    func createHousehold(displayName: String) async throws {
        let created: Household = try await supabase
            .rpc("create_household", params: ["display_name": displayName])
            .single()
            .execute()
            .value
        try await loadHousehold(id: created.id)
        phase = .ready
    }

    func joinHousehold(code: String, displayName: String) async throws {
        let joined: Household = try await supabase
            .rpc("join_household", params: ["code": code, "display_name": displayName])
            .single()
            .execute()
            .value
        try await loadHousehold(id: joined.id)
        phase = .ready
    }

    /// Einmal-Code aus WhatsApp/Nachricht einlösen: legt bei Bedarf das Konto an und meldet an.
    /// Den Rest übernimmt observeAuth, sobald die Sitzung da ist.
    func redeemInvite(code: String, displayName: String) async throws {
        struct Body: Encodable { let code: String; let display_name: String }
        struct Response: Decodable { let token_hash: String }
        let response: Response = try await callFunction(
            "invite",
            body: Body(code: code, display_name: displayName),
            timeout: 30,
            fallbackMessage: "Das hat nicht geklappt. Probier es gleich noch mal."
        )
        try await supabase.auth.verifyOTP(tokenHash: response.token_hash, type: .magiclink)
    }

    /// Code zum Weitergeben. Mit `member` meldet er dieses Mitglied auf einem neuen Gerät an.
    func invite(for member: UUID? = nil) async throws -> HouseholdInvite {
        try await supabase
            .rpc("create_invite", params: ["member": member])
            .single()
            .execute()
            .value
    }

    /// Mitglieder, die per Einladung ohne E-Mail beigetreten sind, kommen nur mit neuem Code zurück ins Konto.
    func isInvitedAccount(_ userId: UUID) async -> Bool {
        (try? await supabase.rpc("is_invited_account", params: ["uid": userId]).execute().value) ?? false
    }

    func signOut() async {
        try? await supabase.auth.signOut()
        reset()
    }

    private func loadHousehold(id: UUID) async throws {
        household = try await supabase
            .from("households")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
        members = try await supabase
            .from("household_members")
            .select()
            .eq("household_id", value: id)
            .order("joined_at")
            .execute()
            .value
    }

    private func reset() {
        userId = nil
        signedInWithoutEmail = false
        household = nil
        members = []
        phase = .signedOut
    }
}
