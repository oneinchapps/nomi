import Foundation
import Observation
import Supabase

/// Das gemeinsame Gespräch mit nomi. Antworten kommen von der Edge Function `assistant`;
/// die Aktionen darin (Wochenplan, Einkaufsliste) führt die App der fragenden Person aus –
/// mit derselben Logik wie beim Antippen, und mit allem, was zum Rückgängigmachen nötig ist.
@Observable
final class AssistantStore {
    let householdId: UUID
    let userId: UUID

    private(set) var messages: [AssistantMessage] = []
    private(set) var isThinking = false
    private(set) var hasLoaded = false
    var error: String?

    private static let history = 80

    init(householdId: UUID, userId: UUID) {
        self.householdId = householdId
        self.userId = userId
    }

    func load() async {
        do {
            let newestFirst: [AssistantMessage] = try await supabase
                .from("assistant_messages")
                .select()
                .eq("household_id", value: householdId)
                .order("created_at", ascending: false)
                .limit(Self.history)
                .execute()
                .value
            messages = newestFirst.reversed()
            error = nil
        } catch {
            self.error = userMessage(for: error)
        }
        hasLoaded = true
    }

    func observeChanges() async {
        await observeTable("assistant_messages", householdId: householdId) { [weak self] in
            await self?.load()
        }
    }

    /// Schickt die Nachricht und gibt nomis Antwort zurück (nil bei Fehler).
    func send(_ text: String) async -> AssistantMessage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return nil }
        // Sofort zeigen, die echte Nachricht kommt mit der Antwort
        let pending = AssistantMessage(id: UUID(), householdId: householdId, userId: userId, content: trimmed, createdAt: .now)
        messages.append(pending)
        isThinking = true
        defer { isThinking = false }

        struct Body: Encodable { let text: String }
        struct Response: Decodable {
            let userMessage: AssistantMessage
            let message: AssistantMessage

            enum CodingKeys: String, CodingKey {
                case message
                case userMessage = "user_message"
            }
        }
        do {
            let response: Response = try await callFunction(
                "assistant",
                body: Body(text: trimmed),
                timeout: 120,
                fallbackMessage: "nomi hat dich gerade nicht verstanden. Probier es gleich noch mal."
            )
            messages.removeAll { $0.id == pending.id || $0.id == response.userMessage.id || $0.id == response.message.id }
            messages.append(response.userMessage)
            messages.append(response.message)
            error = nil
            return response.message
        } catch {
            messages.removeAll { $0.id == pending.id }
            self.error = displayMessage(for: error)
            return nil
        }
    }

    // MARK: - Aktionen

    /// Führt Wochenplan- und Einkaufs-Aktionen aus und vermerkt, was dabei angelegt wurde.
    func execute(_ message: AssistantMessage, recipes: RecipeStore, plan: MealPlanStore, shopping: ShoppingStore) async {
        guard let actions = message.actions, actions.changesData, message.result == nil else { return }

        // Neu ausgearbeitete Rezepte kennt die Sammlung erst nach dem Neuladen
        let needed = (actions.plan ?? []).compactMap(\.recipeId) + (actions.shopping?.recipes.map(\.recipeId) ?? [])
        if needed.contains(where: { recipes.recipe(id: $0) == nil }) {
            await recipes.load()
        }

        var outcome = AssistantOutcome()
        var planned: [(recipe: Recipe, servings: Int)] = []
        for action in actions.plan ?? [] {
            guard let id = action.recipeId, let recipe = recipes.recipe(id: id), let day = PlanCalendar.date(forKey: action.date) else { continue }
            let entry = await plan.add(recipe, on: day, servings: action.servings, note: action.note)
            outcome.planEntryIds.append(entry.id)
            planned.append((recipe, action.servings))
        }

        if let action = actions.shopping {
            var change = ShoppingChange()
            var sources = action.recipes.compactMap { item in recipes.recipe(id: item.recipeId).map { ($0, item.servings) } }
            if action.includeNewPlan { sources += planned }
            for (recipe, servings) in sources {
                change.append(await shopping.add(recipe.scaledIngredients(for: servings), recipeId: recipe.id))
            }
            for line in action.items {
                if let ingredient = IngredientParser.parse(line) {
                    change.append(await shopping.add([ingredient], recipeId: nil))
                }
            }
            outcome.shopping = change.isEmpty ? nil : change
        }

        await save(outcome, for: message.id)
    }

    func undo(_ message: AssistantMessage, plan: MealPlanStore, shopping: ShoppingStore) async {
        guard var outcome = message.result, !outcome.undone else { return }
        await plan.remove(ids: outcome.planEntryIds)
        if let change = outcome.shopping { await shopping.revert(change) }
        outcome.undone = true
        await save(outcome, for: message.id)
    }

    private func save(_ outcome: AssistantOutcome, for id: UUID) async {
        if let index = messages.firstIndex(where: { $0.id == id }) {
            messages[index].result = outcome
        }
        do {
            try await supabase.from("assistant_messages").update(["result": outcome]).eq("id", value: id).execute()
        } catch {
            self.error = userMessage(for: error)
        }
    }
}
