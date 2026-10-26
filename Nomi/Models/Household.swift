import Foundation

struct Household: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    var name: String
    let inviteCode: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case inviteCode = "invite_code"
    }
}

struct HouseholdMember: Codable, Identifiable, Hashable, Sendable {
    let householdId: UUID
    let userId: UUID
    var displayName: String
    /// Profilfoto (öffentliche URL im Bucket `avatars`); nil = Initialen
    var avatarURL: URL?

    var id: UUID { userId }

    var initials: String {
        String(displayName.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case userId = "user_id"
        case displayName = "display_name"
        case avatarURL = "avatar_url"
    }
}

/// Einmal-Code für WhatsApp/Nachricht, 7 Tage gültig.
struct HouseholdInvite: Codable, Hashable, Sendable {
    let code: String
    let memberId: UUID?
    let expiresAt: Date

    /// „K7MP-4QXR“ – leichter abzutippen
    var formattedCode: String { InviteCode.format(code) }

    enum CodingKeys: String, CodingKey {
        case code
        case memberId = "member_id"
        case expiresAt = "expires_at"
    }
}

enum InviteCode {
    static let length = 8

    /// Nur Buchstaben und Ziffern, groß, höchstens 8 Zeichen
    static func normalize(_ input: String) -> String {
        String(input.uppercased().filter { $0.isASCII && ($0.isLetter || $0.isNumber) }.prefix(length))
    }

    static func format(_ code: String) -> String {
        let normalized = normalize(code)
        guard normalized.count > 4 else { return normalized }
        return normalized.prefix(4) + "-" + normalized.dropFirst(4)
    }

    /// Code aus einer eingefügten Nachricht fischen („… Code: K7MP-4QXR (gilt bis …)“).
    /// In der Nachricht steht er immer mit Bindestrich und nur aus Zeichen des Code-Alphabets.
    static func find(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalize(trimmed).count == length, trimmed.count <= length + 1 { return normalize(trimmed) }
        let pattern = /\b([A-HJ-NP-Z2-9]{4})-([A-HJ-NP-Z2-9]{4})\b/
        return text.firstMatch(of: pattern).map { String($0.output.1) + String($0.output.2) }
    }
}
