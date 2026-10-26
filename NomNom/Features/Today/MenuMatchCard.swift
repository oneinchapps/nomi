import SwiftUI

/// Alle Gänge entschieden: „Euer Menü“ mit Ausarbeiten, Einplanen und Einkaufen für alle Gänge zusammen.
struct MenuMatchCard: View {
    let dishes: [(course: String, candidate: SessionCandidate)]

    @Environment(DecideStore.self) private var decide
    @Environment(RecipeStore.self) private var recipes
    @Environment(MealPlanStore.self) private var plan

    @State private var isExpanding = false
    @State private var planned = false
    @State private var showsAddToList = false
    @State private var error: String?
    @State private var appeared = false

    private func recipe(for candidate: SessionCandidate) -> Recipe? {
        candidate.recipeId.flatMap { recipes.recipe(id: $0) }
    }

    /// Ideen, die noch kein Rezept sind
    private var ideas: [SessionCandidate] {
        dishes.map(\.candidate).filter { recipe(for: $0) == nil }
    }

    /// Alle Gänge als Rezepte – erst dann lässt sich einplanen und einkaufen
    private var menuRecipes: [(course: String, recipe: Recipe)] {
        dishes.compactMap { dish in recipe(for: dish.candidate).map { (dish.course, $0) } }
    }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                ReactionIllustration(reaction: .jubel)
                    .frame(width: 76, height: 76)
                    .scaleEffect(appeared ? 1 : 0.3)
                MetaLabel("Ihr habt ein Menü", font: .eyebrow, tracking: 2.4)
                Text("Euer Menü")
                    .font(.display)
                    .tracking(-1)
                    .foregroundStyle(Color.ink)
            }

            VStack(spacing: 10) {
                ForEach(dishes, id: \.candidate.id) { dish in
                    row(course: dish.course, candidate: dish.candidate)
                }
            }

            VStack(spacing: 10) {
                if !ideas.isEmpty {
                    LoadingButton(
                        title: ideas.count == 1 ? "Idee ausarbeiten" : "\(ideas.count) Ideen ausarbeiten",
                        isLoading: isExpanding,
                        action: expandAll
                    )
                    Text(isExpanding
                         ? "nomnom schreibt Zutaten und Schritte …"
                         : "Neue Ideen werden zu Rezepten in eurer Sammlung – dann könnt ihr einplanen und einkaufen.")
                        .font(.captionSans)
                        .foregroundStyle(Color.inkMuted)
                        .multilineTextAlignment(.center)
                } else {
                    if planned {
                        // Erledigt sieht erledigt aus: hell, mit Häkchen, ohne Pfeil
                        Label("Für heute eingeplant", systemImage: "checkmark")
                            .font(.bodySansMedium)
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(Color.surface, in: .rect(cornerRadius: Metrics.buttonRadius))
                            .overlay { RoundedRectangle(cornerRadius: Metrics.buttonRadius).strokeBorder(Color.sage, lineWidth: 1.5) }
                            .transition(.opacity)
                    } else {
                        // Kurz und ohne Symbol: der Haupt-Button hat schon seinen Pfeil
                        Button("Für heute einplanen") {
                            Task {
                                // Gänge in Reihenfolge, der Gang steht als Hinweis am Eintrag
                                for item in menuRecipes {
                                    await plan.add(item.recipe, on: .now, servings: 2, note: item.course)
                                }
                                withAnimation { planned = true }
                            }
                        }
                        .buttonStyle(.primary)
                    }
                    Button("Alles einkaufen", systemImage: "basket") { showsAddToList = true }
                        .buttonStyle(.secondary)
                }

                InlineError(message: error)

                Button("Neue Runde") {
                    Task { await decide.newRound() }
                }
                .font(.bodySansMedium)
                .foregroundStyle(Color.inkMuted)
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(duration: 0.6, bounce: 0.5)) { appeared = true }
        }
        .sensoryFeedback(.success, trigger: appeared)
        .sheet(isPresented: $showsAddToList) {
            AddToListSheet(sources: menuRecipes.map { AddToListSheet.Source(recipe: $0.recipe, servings: 2) })
        }
    }

    @ViewBuilder
    private func row(course: String, candidate: SessionCandidate) -> some View {
        let recipe = recipe(for: candidate)
        let content = HStack(spacing: 14) {
            Group {
                if let recipe {
                    RecipeImage(recipe: recipe)
                } else {
                    IllustrationTile(motif: FoodMotif.matching(title: candidate.aiRecipe?.title ?? "") ?? .teller)
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 4) {
                MetaLabel(recipe == nil ? "\(course) · Idee" : course)
                Text(recipe?.title ?? candidate.aiRecipe?.title ?? "Gericht")
                    .font(.heading(18, relativeTo: .headline))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if recipe != nil {
                Image(systemName: "chevron.right").foregroundStyle(Color.inkMuted)
            }
        }
        .padding(10)
        .background(Color.surface, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.hairline) }

        if let recipe {
            NavigationLink(value: recipe.id) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }

    /// Alle Ideen gleichzeitig ausarbeiten – drei Gänge dauern so nicht dreimal so lang.
    private func expandAll() {
        isExpanding = true
        error = nil
        let pending = ideas
        Task {
            var failed = 0
            await withTaskGroup(of: Bool.self) { group in
                for candidate in pending {
                    group.addTask { (try? await decide.expand(candidate)) != nil }
                }
                for await ok in group where !ok { failed += 1 }
            }
            await recipes.load()
            if failed > 0 {
                error = failed == 1 ? "Eine Idee ließ sich nicht ausarbeiten. Probier es noch mal." : "\(failed) Ideen ließen sich nicht ausarbeiten. Probier es noch mal."
            }
            isExpanding = false
        }
    }
}
