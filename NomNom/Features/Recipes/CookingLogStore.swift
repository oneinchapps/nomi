import Foundation
import Observation
import Supabase

/// Kochhistorie des Haushalts: wann wurde was gekocht.
@Observable
final class CookingLogStore {
    let householdId: UUID
    let userId: UUID

    /// Neueste zuerst
    private(set) var entries: [CookLogEntry] = []
    var error: String?

    init(householdId: UUID, userId: UUID) {
        self.householdId = householdId
        self.userId = userId
    }

    func load() async {
        do {
            entries = try await supabase
                .from("cooking_log")
                .select()
                .eq("household_id", value: householdId)
                .order("cooked_on", ascending: false)
                .order("created_at", ascending: false)
                .execute()
                .value
            error = nil
        } catch {
            self.error = userMessage(for: error)
        }
    }

    func observeChanges() async {
        await observeTable("cooking_log", householdId: householdId) { [weak self] in
            await self?.load()
        }
    }

    /// „Los geht's“ im Kochmodus. Pro Rezept und Tag nur ein Eintrag (Unique-Constraint, Duplikate werden ignoriert).
    func logCooking(_ recipe: Recipe, servings: Int, on day: Date = .now) async {
        let entry = CookLogEntry(
            householdId: householdId,
            recipeId: recipe.id,
            cookedBy: userId,
            cookedOn: PlanCalendar.key(for: day),
            servings: servings
        )
        if !entries.contains(where: { $0.recipeId == entry.recipeId && $0.cookedOn == entry.cookedOn }) {
            entries.insert(entry, at: 0)
        }
        do {
            try await supabase
                .from("cooking_log")
                .upsert(entry, onConflict: "household_id,recipe_id,cooked_on", returning: .minimal, ignoreDuplicates: true)
                .execute()
        } catch {
            self.error = userMessage(for: error)
            await load()
        }
    }

    func delete(_ entry: CookLogEntry) async {
        entries.removeAll { $0.id == entry.id }
        do {
            try await supabase.from("cooking_log").delete().eq("id", value: entry.id).execute()
        } catch {
            self.error = userMessage(for: error)
            await load()
        }
    }

    // MARK: - Auswertungen

    func lastCooked(_ recipeId: UUID) -> Date? {
        entries.first { $0.recipeId == recipeId }?.date
    }

    func timesCooked(_ recipeId: UUID) -> Int {
        entries.filter { $0.recipeId == recipeId }.count
    }

    /// Zuletzt gekochte Rezepte, jedes nur einmal
    var recentRecipeIds: [UUID] {
        var seen = Set<UUID>()
        return entries.compactMap { seen.insert($0.recipeId).inserted ? $0.recipeId : nil }
    }
}
