import Foundation
import Observation
import Supabase

/// Wochenplan des Haushalts. Lädt ein Fenster um die angezeigte Woche.
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

    func entries(on day: Date) -> [MealPlanEntry] {
        let key = PlanCalendar.key(for: day)
        return entries.filter { $0.day == key }
    }

    var weekEntries: [MealPlanEntry] {
        let keys = Set(days.map(PlanCalendar.key))
        return entries.filter { keys.contains($0.day) }
    }

    func load() async {
        let from = PlanCalendar.key(for: weekStart)
        let to = PlanCalendar.key(for: days.last!)
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
    func add(_ recipe: Recipe, on day: Date, servings: Int, note: String? = nil) async -> MealPlanEntry {
        let entry = MealPlanEntry(householdId: householdId, day: PlanCalendar.key(for: day), recipeId: recipe.id, servings: servings, note: note)
        if PlanCalendar.key(for: day) >= PlanCalendar.key(for: weekStart) && PlanCalendar.key(for: day) <= PlanCalendar.key(for: days.last!) {
            entries.append(entry)
        }
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
