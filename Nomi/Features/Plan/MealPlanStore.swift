import Foundation
import Observation
import Supabase

/// Wochenplan des Haushalts. Lädt die angezeigte Woche – und immer auch heute, für den Heute-Tab.
@Observable
final class MealPlanStore {
    let householdId: UUID

    private(set) var entries: [MealPlanEntry] = []
    private(set) var hasLoaded = false
    var error: String?

    /// Sichtbare Woche; beim Blättern wird neu geladen.
    var weekStart = PlanCalendar.startOfWeek(containing: .now) {
        didSet { Task { await load() } }
    }

    init(householdId: UUID) {
        self.householdId = householdId
    }

    var days: [Date] { PlanCalendar.days(ofWeekStarting: weekStart) }

    /// Einträge eines Tages, nach Mahlzeit und Gang sortiert
    func entries(on day: Date) -> [MealPlanEntry] {
        let key = PlanCalendar.key(for: day)
        let order = Meal.allCases
        return entries.filter { $0.day == key }.sorted {
            (order.firstIndex(of: $0.meal)!, $0.position) < (order.firstIndex(of: $1.meal)!, $1.position)
        }
    }

    func entries(on day: Date, meal: Meal) -> [MealPlanEntry] {
        entries(on: day).filter { $0.meal == meal }
    }

    var weekEntries: [MealPlanEntry] {
        let keys = Set(days.map(PlanCalendar.key))
        return entries.filter { keys.contains($0.day) }
    }

    func load() async {
        let today = PlanCalendar.key(for: .now)
        let from = min(PlanCalendar.key(for: weekStart), today)
        let to = max(PlanCalendar.key(for: days.last!), today)
        do {
            entries = try await supabase
                .from("meal_plan_entries")
                .select()
                .eq("household_id", value: householdId)
                .gte("day", value: from)
                .lte("day", value: to)
                .order("created_at")
                .execute()
                .value
            error = nil
        } catch {
            self.error = userMessage(for: error)
        }
        hasLoaded = true
    }

    func observeChanges() async {
        await observeTable("meal_plan_entries", householdId: householdId) { [weak self] in
            await self?.load()
        }
    }

    @discardableResult
    func add(_ recipe: Recipe, on day: Date, servings: Int, note: String? = nil, meal: Meal = .abend) async -> MealPlanEntry {
        // Neuer Gang ans Ende der Mahlzeit
        let position = (entries(on: day, meal: meal).map(\.position).max() ?? -1) + 1
        let entry = MealPlanEntry(householdId: householdId, day: PlanCalendar.key(for: day), recipeId: recipe.id, servings: servings, note: note, meal: meal, position: position)
        entries.append(entry)
        await write { try await supabase.from("meal_plan_entries").insert(entry).execute() }
        return entry
    }

    func setServings(_ servings: Int, for entry: MealPlanEntry) async {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { return }
        entries[index].servings = servings
        await write {
            try await supabase.from("meal_plan_entries").update(["servings": servings]).eq("id", value: entry.id).execute()
        }
    }

    func remove(_ entry: MealPlanEntry) async {
        await remove(ids: [entry.id])
    }

    func remove(ids: [UUID]) async {
        guard !ids.isEmpty else { return }
        entries.removeAll { ids.contains($0.id) }
        await write { try await supabase.from("meal_plan_entries").delete().in("id", values: ids).execute() }
    }

    private func write(_ operation: () async throws -> Void) async {
        do {
            try await operation()
            error = nil
        } catch {
            self.error = userMessage(for: error)
            await load()
        }
    }
}
