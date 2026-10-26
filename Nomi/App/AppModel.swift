import Foundation
import Observation
import Supabase
import UIKit

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
        if ProcessInfo.processInfo.environment["NOMI_RESET_SESSION"] == "1" {
            try? await supabase.auth.signOut(scope: .local)
        }
        #endif
        for await (event, session) in supabase.auth.authStateChanges {
            switch event {
            case .initialSession, .signedIn, .userUpdated:
                if let session {
                    userId = session.user.id
                    signedInWithoutEmail = session.user.email?.hasSuffix("@einladung.nomi.invalid") ?? false
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

    // MARK: - Profilfoto

    private static let avatarBucket = "avatars"

    /// Quadratisch zuschneiden, auf 600 px verkleinern, hochladen und am eigenen Mitgliedseintrag speichern.
    /// Pfad <household>/<user>/<uuid>.jpg – ein neuer Name pro Foto, damit kein altes Bild im Cache hängt.
    func setAvatar(_ image: UIImage) async throws {
        guard let userId, let household else { return }
        let data = image.squareCropped().jpegData(maxSide: 600, quality: 0.82)
        let folder = "\(household.id.uuidString.lowercased())/\(userId.uuidString.lowercased())"
        let path = "\(folder)/\(UUID().uuidString.lowercased()).jpg"
        let bucket = supabase.storage.from(Self.avatarBucket)
        try await bucket.upload(path, data: data, options: FileOptions(cacheControl: "31536000", contentType: "image/jpeg"))
        let url = try bucket.getPublicURL(path: path)
        let previous = me?.avatarURL
        try await updateAvatar(url)
        await removeAvatarFile(previous)
    }

    func removeAvatar() async throws {
        let previous = me?.avatarURL
        try await updateAvatar(nil)
        await removeAvatarFile(previous)
    }

    private func updateAvatar(_ url: URL?) async throws {
        guard let userId, let household else { return }
        struct Change: Encodable {
            let avatarURL: URL?
            enum CodingKeys: String, CodingKey { case avatarURL = "avatar_url" }
            // Auch nil schreiben (als null) – sonst bliebe das alte Foto stehen
            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(avatarURL, forKey: .avatarURL)
            }
        }
        try await supabase.from("household_members")
            .update(Change(avatarURL: url))
            .eq("household_id", value: household.id)
            .eq("user_id", value: userId)
            .execute()
        if let index = members.firstIndex(where: { $0.userId == userId }) {
            members[index].avatarURL = url
        }
    }

    private func removeAvatarFile(_ url: URL?) async {
        guard let url, let range = url.path.range(of: "/\(Self.avatarBucket)/") else { return }
        _ = try? await supabase.storage.from(Self.avatarBucket).remove(paths: [String(url.path[range.upperBound...])])
    }

    /// Konto endgültig löschen (Edge Function `account`), danach lokal abmelden.
    func deleteAccount() async throws {
        struct Body: Encodable { let action = "delete" }
        struct Response: Decodable { let deleted: Bool }
        let _: Response = try await callFunction(
            "account",
            body: Body(),
            timeout: 60,
            fallbackMessage: "Das Konto ließ sich gerade nicht löschen. Probier es gleich noch mal."
        )
        try? await supabase.auth.signOut(scope: .local)
        reset()
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
