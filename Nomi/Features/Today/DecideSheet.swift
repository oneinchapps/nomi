import SwiftUI

/// Auswahlblatt für eine Mahlzeit von heute: Wunsch antippen, Karten swipen, allein festlegen
/// („Das nehmen wir“) oder gemeinsam bis zum Match. Die Entscheidung trägt die Datenbank selbst
/// in die Mahlzeit ein (plan_decision) – bei Ideen nach dem Ausarbeiten.
struct DecideSheet: View {
    let meal: Meal

    @Environment(DecideStore.self) private var decide
    @Environment(RecipeStore.self) private var recipes
    @Environment(AppModel.self) private var app
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.dismiss) private var dismiss

    private let quickPrompts = ["Was Schnelles", "Vegetarisch", "Comfort Food", "Was Neues ausprobieren", "Überrasch uns"]

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if decide.candidates.isEmpty && !decide.isThinking {
                            start
                        } else {
                            roundIntro
                        }
                        if decide.isThinking {
                            ThinkingBubble()
                        }
                        roundState
                        InlineError(message: decide.error)
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.vertical, 16)
                }
                .background(Color.canvas.ignoresSafeArea())
                .onChange(of: decide.isThinking) { scrollDown(proxy) }
                .onChange(of: decide.candidates.count) { scrollDown(proxy) }
            }
            .navigationTitle("\(meal.title) aussuchen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                RecipeDetailView(recipeId: id)
            }
        }
        .task { await decide.startRound(meal: meal, wish: nil) }
    }

    @ViewBuilder
    private var roundState: some View {
        if let dishes = decide.menuMatch {
            MenuMatchCard(dishes: dishes)
        } else if let match = decide.match {
            MatchCard(candidate: match)
        } else {
            if decide.menu.isMenu { courseProgress }
            deckOrWaiting
        }
    }

    @ViewBuilder
    private var deckOrWaiting: some View {
        if !decide.myDeck.isEmpty {
            SwipeDeck(
                deck: decide.myDeck,
                recipe: { recipes.recipe(id: $0) },
                onVote: { candidate, liked in Task { await decide.vote(candidate, liked: liked) } },
                onDecide: { candidate in Task { await decide.decideAlone(candidate) } }
            )
            .padding(.top, 6)
        } else if !decide.candidates.isEmpty && !decide.isThinking {
            waiting
        }
    }

    /// „Vorspeise ✓ · Hauptgang · Dessert“ – welche Gänge schon entschieden sind.
    private var courseProgress: some View {
        let decided = decide.menu.decided
        return FlowLayout(spacing: 8) {
            ForEach(decide.menu.courses, id: \.self) { course in
                let done = decided[course] != nil
                Label(course, systemImage: done ? "checkmark.circle.fill" : "circle.dashed")
                    .font(.captionSans)
                    .foregroundStyle(done ? Color.onBrand : Color.ink)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(done ? Color.brand : Color.surface, in: .capsule)
                    .overlay { Capsule().strokeBorder(done ? .clear : Color.hairline) }
                    .accessibilityLabel("\(course): \(done ? "entschieden" : "offen")")
            }
        }
    }

    /// Alle eigenen Karten bewertet, aber (noch) kein Match.
    private var waiting: some View {
        let others = app.members.filter { $0.userId != app.userId }
        let pending = others.filter { decide.remaining(for: $0.userId) > 0 }
        return VStack(alignment: .leading, spacing: 12) {
            if let partner = pending.first {
                let left = decide.remaining(for: partner.userId)
                ReactionIllustration(reaction: .warten).frame(width: 56, height: 56)
                Text("Warte auf \(partner.displayName)")
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                Text(left == 1 ? "Noch eine Karte – dann wisst ihr mehr." : "Noch \(left) Karten – dann wisst ihr mehr.")
                    .font(.bodySans)
                    .foregroundStyle(Color.inkMuted)
            } else {
                ReactionIllustration(reaction: .ratlos).frame(width: 56, height: 56)
                Text("Diesmal kein Match")
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                Text("Sagt nomi, was anders sein soll – oder holt euch einfach neue Vorschläge.")
                    .font(.bodySans)
                    .foregroundStyle(Color.inkMuted)
                Button("Neue Vorschläge") {
                    Task { await decide.send(nil) }
                }
                .buttonStyle(.secondary)
                .padding(.top, 4)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        .overlay { RoundedRectangle(cornerRadius: Metrics.cardRadius).strokeBorder(Color.hairline) }
    }

    /// Noch keine Karten: Wunsch antippen oder mit nomi besprechen
    private var start: some View {
        VStack(alignment: .leading, spacing: 12) {
            MetaLabel("Worauf habt ihr Lust?")
            FlowLayout(spacing: 8) {
                ForEach(quickPrompts, id: \.self) { prompt in
                    Button(prompt) { Task { await decide.send(prompt) } }
                        .font(.captionSans)
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.mist, in: .capsule)
                        .buttonStyle(.plain)
                }
            }
            Button("Eigener Wunsch? Frag nomi", systemImage: "bubble.left.and.text.bubble.right") {
                navigation.decideMeal = nil
                navigation.tab = .nomi
            }
            .font(.bodySansMedium)
            .foregroundStyle(Color.ink)
            .padding(.top, 4)
        }
    }

    /// Laufende Runde: worum es geht und was nomi dazu meint
    @ViewBuilder
    private var roundIntro: some View {
        if let wish = decide.messages.last(where: { $0.userId != nil }) {
            MetaLabel("Wunsch: \(wish.content)")
        }
        if let reply = decide.messages.last(where: { $0.userId == nil }) {
            MessageBubble(message: reply, isMe: false, author: "nomi")
        }
    }

    private func scrollDown(_ proxy: ScrollViewProxy) {
        withAnimation(.smooth) { proxy.scrollTo("bottom", anchor: .bottom) }
    }
}
