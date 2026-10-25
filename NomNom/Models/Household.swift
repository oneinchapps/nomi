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

    var id: UUID { userId }

    var initials: String {
        String(displayName.trimmingCharacters(in: .whitespaces).prefix(1)).uppercased()
    }

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case userId = "user_id"
        case displayName = "display_name"
    }
}
