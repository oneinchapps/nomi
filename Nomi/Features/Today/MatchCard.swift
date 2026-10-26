import SwiftUI

/// „Match!“ – beide mögen dasselbe. Von hier: ausarbeiten (bei Ideen), einplanen, einkaufen, neue Runde.
struct MatchCard: View {
    let candidate: SessionCandidate

    @Environment(DecideStore.self) private var decide
    @Environment(RecipeStore.self) private var recipes
    @Environment(MealPlanStore.self) private var plan

    @State private var isExpanding = false
    @State private var planned = false
    @State private var showsAddToList = false
    @State private var error: String?
    @State private var appeared = false

    private var recipe: Recipe? { candidate.recipeId.flatMap { recipes.recipe(id: $0) } }

    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 6) {
                ReactionIllustration(reaction: .jubel)
                    .frame(width: 76, height: 76)
                    .scaleEffect(appeared ? 1 : 0.3)
                MetaLabel("Ihr habt ein Match", font: .eyebrow, tracking: 2.4)
                Text("Heute gibt's")
                    .font(.display)
                    .tracking(-1)
                    .foregroundStyle(Color.ink)
            }

            CandidateCard(candidate: candidate, recipe: recipe, showsReason: false)
                .frame(maxWidth: .infinity)
                .rotationEffect(.degrees(appeared ? 0 : -4))

            VStack(spacing: 10) {
                if let recipe {
                    NavigationLink(value: recipe.id) {
                        Text("Rezept ansehen")
                    }
                    .buttonStyle(.primary)

                    HStack(spacing: 10) {
                        Button(planned ? "Eingeplant" : "Für heute", systemImage: planned ? "checkmark" : "calendar.badge.plus") {
                            Task {
                                await plan.add(recipe, on: .now, servings: 2)
                                withAnimation { planned = true }
                            }
                        }
                        .disabled(planned)
                        Button("Einkaufen", systemImage: "basket") { showsAddToList = true }
                            .disabled(recipe.ingredients.isEmpty)
                    }
                    .buttonStyle(.secondary)
                } else if candidate.aiRecipe != nil {
                    LoadingButton(title: "Rezept ausarbeiten", isLoading: isExpanding, action: expand)
                    if isExpanding {
                        Text("nomi schreibt Zutaten und Schritte …")
                            .font(.captionSans)
                            .foregroundStyle(Color.inkMuted)
                    }
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
            if let recipe {
                AddToListSheet(sources: [AddToListSheet.Source(recipe: recipe, servings: 2)])
            }
        }
    }

    private func expand() {
        isExpanding = true
        error = nil
        Task {
            do {
                _ = try await decide.expand(candidate)
                await recipes.load()
            } catch {
                self.error = displayMessage(for: error)
            }
            isExpanding = false
        }
    }
}
