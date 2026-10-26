import Foundation

/// Ein Eintrag der Kochhistorie: Rezept X wurde an Tag Y gekocht.
struct CookLogEntry: Codable, Identifiable, Hashable, Sendable {
    let id: UUID
    let householdId: UUID
    let recipeId: UUID
    var cookedBy: UUID?
    /// Postgres-`date`, „2026-10-26“
    let cookedOn: String
    var servings: Int?

    init(id: UUID = UUID(), householdId: UUID, recipeId: UUID, cookedBy: UUID?, cookedOn: String, servings: Int?) {
        self.id = id
        self.householdId = householdId
        self.recipeId = recipeId
        self.cookedBy = cookedBy
        self.cookedOn = cookedOn
        self.servings = servings
    }

    enum CodingKeys: String, CodingKey {
        case id, servings
        case householdId = "household_id"
        case recipeId = "recipe_id"
        case cookedBy = "cooked_by"
        case cookedOn = "cooked_on"
    }

    var date: Date? { CookingHistory.date(from: cookedOn) }
}

enum CookingHistory {
    static func date(from key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return PlanCalendar.calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// „heute“, „gestern“, „vor 3 Tagen“, „vor 2 Wochen“, „vor 4 Monaten“, „vor über einem Jahr“
    static func relative(_ date: Date, now: Date = .now) -> String {
        let calendar = PlanCalendar.calendar
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)).day ?? 0
        switch days {
        case ..<1: return "heute"
        case 1: return "gestern"
        case 2..<14: return "vor \(days) Tagen"
        case 14..<60: return "vor \(days / 7) Wochen"
        case 60..<365: return "vor \(days / 30) Monaten"
        default: return "vor über einem Jahr"
        }
    }
}

/// Filter der Rezeptsammlung – Kategorien und Schnellzugriffe.
enum RecipeFilter: Hashable, Identifiable {
    case all
    case diet(Diet)
    case dishType(DishType)
    case quick
    case longNotCooked

    var id: String {
        switch self {
        case .all: "all"
        case .diet(let diet): "diet-\(diet.rawValue)"
        case .dishType(let type): "type-\(type.rawValue)"
        case .quick: "quick"
        case .longNotCooked: "long"
        }
    }

    var title: String {
        switch self {
        case .all: "Alle Rezepte"
        case .diet(let diet): diet.title
        case .dishType(let type): type.plural
        case .quick: "In 30 Minuten"
        case .longNotCooked: "Lange nicht gekocht"
        }
    }

    /// Ab wie vielen Tagen ein Rezept als „lange nicht gekocht“ gilt
    static let longAgoDays = 30

    func matches(_ recipe: Recipe, lastCooked: Date?, now: Date = .now) -> Bool {
        switch self {
        case .all: return true
        case .diet(let diet):
            // Vegan zählt auch als vegetarisch
            return recipe.diet == diet || (diet == .vegetarisch && recipe.diet == .vegan)
        case .dishType(let type): return recipe.dishType == type
        case .quick: return (recipe.totalMinutes ?? .max) <= 30
        case .longNotCooked:
            guard let lastCooked else { return true }
            let days = PlanCalendar.calendar.dateComponents([.day], from: lastCooked, to: now).day ?? 0
            return days >= Self.longAgoDays
        }
    }

    /// Reihenfolge der Kacheln und Chips: erst Ernährung, dann Art des Gerichts
    static let categories: [RecipeFilter] =
        Diet.allCases.map(RecipeFilter.diet) + DishType.allCases.map(RecipeFilter.dishType)
}
