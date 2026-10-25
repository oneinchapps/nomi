import Foundation

/// Eine Runde „Was essen wir?“: Chat mit nomnom, Vorschläge, Stimmen, ggf. Match.
struct DecideSession: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let householdId: UUID
    var status: Status
    var matchedCandidateId: UUID?
    var createdAt: Date?

    enum Status: String, Codable, Sendable {
        case open, matched, closed
    }

    enum CodingKeys: String, CodingKey {
        case id, status
        case householdId = "household_id"
        case matchedCandidateId = "matched_candidate_id"
        case createdAt = "created_at"
    }
}

struct ChatMessage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let sessionId: UUID
    let householdId: UUID
    /// nil = nomnom
    let userId: UUID?
    let content: String
    var createdAt: Date?

    init(id: UUID = UUID(), sessionId: UUID, householdId: UUID, userId: UUID?, content: String, createdAt: Date? = .now) {
        self.id = id
        self.sessionId = sessionId
        self.householdId = householdId
        self.userId = userId
        self.content = content
        self.createdAt = createdAt
    }

    enum CodingKeys: String, CodingKey {
        case id, content
        case sessionId = "session_id"
        case householdId = "household_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(sessionId, forKey: .sessionId)
        try c.encode(householdId, forKey: .householdId)
        try c.encode(userId, forKey: .userId)
        try c.encode(content, forKey: .content)
    }
}

/// Neue Gericht-Idee von nomnom, noch ohne Zutaten und Schritte (die kommen beim Ausarbeiten).
struct RecipeIdea: Codable, Hashable, Sendable {
    var title: String
    var summary: String
    var totalMinutes: Int?
    var tags: [String]
    var emoji: String

    enum CodingKeys: String, CodingKey {
        case title, summary, tags, emoji
        case totalMinutes = "total_minutes"
    }
}

/// Eine Karte im Swipe-Stapel: entweder ein Rezept aus der Sammlung oder eine Idee.
struct SessionCandidate: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let sessionId: UUID
    var recipeId: UUID?
    var aiRecipe: RecipeIdea?
    var reason: String?
    var position: Int

    enum CodingKeys: String, CodingKey {
        case id, reason, position
        case sessionId = "session_id"
        case recipeId = "recipe_id"
        case aiRecipe = "ai_recipe"
    }
}

struct SessionVote: Codable, Hashable, Sendable {
    let candidateId: UUID
    let sessionId: UUID
    let householdId: UUID
    var userId: UUID
    var liked: Bool

    enum CodingKeys: String, CodingKey {
        case liked
        case candidateId = "candidate_id"
        case sessionId = "session_id"
        case householdId = "household_id"
        case userId = "user_id"
    }
}
