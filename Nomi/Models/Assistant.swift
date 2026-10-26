import Foundation

/// Eine Nachricht im gemeinsamen Gespräch mit nomi.
struct AssistantMessage: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let householdId: UUID
    /// nil = nomi
    let userId: UUID?
    var content: String
    /// Was nomi tun wollte – von der Function geprüft
    var actions: AssistantActions?
    /// Was die App daraus gemacht hat; nil, solange es noch nicht ausgeführt ist
    var result: AssistantOutcome?
    var createdAt: Date?

    var isFromNomi: Bool { userId == nil }

    enum CodingKeys: String, CodingKey {
        case id, content, actions, result
        case householdId = "household_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }
}

/// Bereiche der App, in die nomi wechseln kann
enum AppTab: String, Codable, Hashable, Sendable {
    case nomi, today, recipes, shopping, week
}

struct AssistantActions: Codable, Hashable, Sendable {
    var plan: [PlanAction]?
    var shopping: ShoppingAction?
    var today: TodayAction?
    var navigate: AppTab?

    struct PlanAction: Codable, Hashable, Sendable {
        /// „2026-10-27“
        var date: String
        var meal: Meal
        var recipeId: UUID?
        var servings: Int
        var note: String?

        enum CodingKeys: String, CodingKey {
            case date, meal, servings, note
            case recipeId = "recipe_id"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            date = try c.decode(String.self, forKey: .date)
            // Nachrichten von vor den Mahlzeiten hatten kein meal
            meal = try c.decodeIfPresent(Meal.self, forKey: .meal) ?? .abend
            recipeId = try c.decodeIfPresent(UUID.self, forKey: .recipeId)
            servings = try c.decode(Int.self, forKey: .servings)
            note = try c.decodeIfPresent(String.self, forKey: .note)
        }
    }

    struct ShoppingAction: Codable, Hashable, Sendable {
        var recipes: [RecipeServings]
        /// Zutaten aller in derselben Antwort geplanten Gerichte
        var includeNewPlan: Bool
        var items: [String]

        struct RecipeServings: Codable, Hashable, Sendable {
            var recipeId: UUID
            var servings: Int

            enum CodingKeys: String, CodingKey {
                case servings
                case recipeId = "recipe_id"
            }
        }

        enum CodingKeys: String, CodingKey {
            case recipes, items
            case includeNewPlan = "include_new_plan"
        }
    }

    struct TodayAction: Codable, Hashable, Sendable {
        var wish: String?
        var meal: Meal

        enum CodingKeys: String, CodingKey { case wish, meal }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            wish = try c.decodeIfPresent(String.self, forKey: .wish)
            meal = try c.decodeIfPresent(Meal.self, forKey: .meal) ?? .abend
        }
    }

    /// Aktionen, die Daten ändern (und sich deshalb rückgängig machen lassen)
    var changesData: Bool { !(plan ?? []).isEmpty || shopping != nil }
}

struct AssistantOutcome: Codable, Hashable, Sendable {
    var planEntryIds: [UUID] = []
    var shopping: ShoppingChange?
    var undone = false

    enum CodingKeys: String, CodingKey {
        case shopping, undone
        case planEntryIds = "plan_entry_ids"
    }
}
