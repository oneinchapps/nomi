import SwiftUI

/// Heute-Tab: das heutige Essen. Vorschläge holen, dann allein festlegen („Das nehmen wir“)
/// oder gemeinsam swipen bis zum Match. Freie Wünsche gehen über nomi, das hierher zurückspringt.
struct TodayView: View {
    @Environment(DecideStore.self) private var decide
    @Environment(RecipeStore.self) private var recipes
    @Environment(MealPlanStore.self) private var plan
    @Environment(AppModel.self) private var app
    @Environment(AppNavigation.self) private var navigation

    private let quickPrompts = ["Was Schnelles", "Vegetarisch", "Comfort Food", "Was Neues ausprobieren", "Überrasch uns"]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                header
                VStack(alignment: .leading, spacing: 18) {

                    if app.partner == nil, app.household != nil {
                        InviteCard()
                    }

                    plannedToday

                    // Ohne Karten (noch keine Runde, oder sie ist abgebrochen) geht es mit einem Wunsch los
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
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .background(Color.canvas.ignoresSafeArea())
            .onChange(of: decide.messages.count) { scrollDown(proxy) }
            .onChange(of: decide.isThinking) { scrollDown(proxy) }
            .onChange(of: decide.candidates.count) { scrollDown(proxy) }
            .navigationDestination(for: UUID.self) { id in
                RecipeDetailView(recipeId: id)
            }
            .onChange(of: app.members.count, initial: true) { _, count in
                decide.memberCount = max(1, count)
            }
        }
    }

    // MARK: - Bausteine

    private var header: some View {
        BrandHeader {
            DisplayHeadline(lines: ["Was gibt es heute?"])
            if decide.candidates.isEmpty {
                Text("Holt euch Vorschläge und legt allein fest – oder swipet beide, bis ihr ein Match habt.")
                    .font(.bodySans)
                    .foregroundStyle(Color.onBrand.opacity(0.9))
                    .lineSpacing(3)
            }
        }
    }

    @ViewBuilder
    private var plannedToday: some View {
        let today = plan.entries(on: .now).compactMap { recipes.recipe(id: $0.recipeId) }
        if let first = today.first {
            NavigationLink(value: first.id) {
                HStack(spacing: 14) {
                    RecipeImage(recipe: first)
                        .frame(width: 56, height: 56)
                        .clipShape(.rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        MetaLabel("Heute geplant")
                        Text(first.title)
                            .font(.heading(18, relativeTo: .headline))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").foregroundStyle(Color.inkMuted)
                }
                .padding(10)
                .background(Color.surface, in: .rect(cornerRadius: 16))
                .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.hairline) }
            }
            .buttonStyle(.plain)
        }
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

    /// Noch keine Runde: Wunsch antippen oder mit nomi besprechen
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

    // MARK: - Helfer

    private func scrollDown(_ proxy: ScrollViewProxy) {
        withAnimation(.smooth) { proxy.scrollTo("bottom", anchor: .bottom) }
    }
}

// MARK: - Chat

struct MessageBubble: View {
    let message: ChatMessage
    let isMe: Bool
    let author: String

    private var isNomi: Bool { message.userId == nil }

    var body: some View {
        HStack {
            if isMe { Spacer(minLength: 48) }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if !isMe {
                    MetaLabel(author)
                }
                Text(message.content)
                    .font(.bodySans)
                    .foregroundStyle(isMe ? Color.canvas : Color.ink)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMe ? Color.ink : (isNomi ? Color.mist : Color.surface), in: .rect(cornerRadius: 18))
                    .overlay {
                        if !isMe && !isNomi { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.hairline) }
                    }
            }
            if !isMe { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isMe ? "Du" : author): \(message.content)")
    }
}

struct ThinkingBubble: View {
    @State private var phase = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            MetaLabel("nomi")
            HStack(spacing: 5) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.ink)
                        .frame(width: 7, height: 7)
                        .opacity(phase == index ? 1 : 0.3)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.mist, in: .rect(cornerRadius: 18))
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("nomi überlegt")
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(350))
                withAnimation(.easeInOut(duration: 0.2)) { phase = (phase + 1) % 3 }
            }
        }
    }
}
