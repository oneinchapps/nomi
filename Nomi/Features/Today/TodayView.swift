import SwiftUI

/// Heute-Tab: die Mahlzeiten von heute. Mittag- und Abendessen sind immer da, Frühstück bei Bedarf.
/// Jede Mahlzeit hat zunächst einen Platz für ein Gericht, weitere Gänge kommen per „+ Gang“ dazu.
/// Leere Plätze füllt man über Vorschläge (DecideSheet) oder aus der Sammlung; von jedem Gericht
/// aus geht es mit „Jetzt kochen“ in den Kochmodus.
struct TodayView: View {
    @Environment(DecideStore.self) private var decide
    @Environment(RecipeStore.self) private var recipes
    @Environment(MealPlanStore.self) private var plan
    @Environment(AppModel.self) private var app
    @Environment(AppNavigation.self) private var navigation

    @State private var showsBreakfast = false
    /// Mahlzeiten mit einem zusätzlichen leeren Platz für einen weiteren Gang
    @State private var extraSlot: Set<Meal> = []
    @State private var picking: Meal?
    @State private var cooking: CookingSelection?

    struct CookingSelection: Identifiable {
        let recipe: Recipe
        let servings: Int
        var id: UUID { recipe.id }
    }

    private var meals: [Meal] {
        let breakfast = showsBreakfast || !plan.entries(on: .now, meal: .fruehstueck).isEmpty
        return breakfast ? Meal.allCases : [.mittag, .abend]
    }

    var body: some View {
        @Bindable var navigation = navigation
        ScrollView {
            header
            VStack(alignment: .leading, spacing: 30) {
                if app.partner == nil, app.household != nil {
                    InviteCard()
                }
                if !meals.contains(.fruehstueck) {
                    Button("Frühstück hinzufügen", systemImage: "plus") {
                        withAnimation(.smooth) { showsBreakfast = true }
                    }
                    .font(.bodySansMedium)
                    .foregroundStyle(Color.ink)
                }
                ForEach(meals) { meal in
                    mealSection(meal)
                }
                InlineError(message: plan.error ?? decide.error)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(Color.canvas.ignoresSafeArea())
        .refreshable {
            await plan.load()
            await decide.load()
        }
        .navigationDestination(for: UUID.self) { id in
            RecipeDetailView(recipeId: id)
        }
        .onChange(of: app.members.count, initial: true) { _, count in
            decide.memberCount = max(1, count)
        }
        // Ist der zusätzliche Gang eingetragen, verschwindet sein Platzhalter
        .onChange(of: plan.entries(on: .now).count) { extraSlot = [] }
        .sheet(item: $navigation.decideMeal) { meal in
            DecideSheet(meal: meal)
        }
        .sheet(item: $picking) { meal in
            RecipePickerSheet(day: .now, meal: meal)
        }
        .fullScreenCover(item: $cooking) { selection in
            CookingModeView(recipe: selection.recipe, servings: selection.servings)
        }
        .mainToolbar()
    }

    private var header: some View {
        BrandHeader(bottomPadding: 22) {
            MetaLabel(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(Locale(identifier: "de_DE"))), font: .eyebrow, tracking: 2.4)
            DisplayHeadline(lines: ["Was gibt es heute?"])
        }
    }

    // MARK: - Mahlzeiten

    private func mealSection(_ meal: Meal) -> some View {
        let entries = plan.entries(on: .now, meal: meal)
        let running = decide.isRunning(for: meal)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(meal.title)
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                if meal == .fruehstueck && entries.isEmpty {
                    Button("Ausblenden") { withAnimation(.smooth) { showsBreakfast = false } }
                        .font(.captionSans)
                        .foregroundStyle(Color.inkMuted)
                }
            }

            ForEach(entries) { entry in
                if let recipe = recipes.recipe(id: entry.recipeId) {
                    DishCard(entry: entry, recipe: recipe) {
                        cooking = CookingSelection(recipe: recipe, servings: entry.servings)
                    }
                }
            }

            if running {
                runningBanner(meal)
            } else if entries.isEmpty || extraSlot.contains(meal) {
                EmptyMealSlot(
                    meal: meal,
                    isAnotherCourse: !entries.isEmpty,
                    onSuggest: { navigation.decideMeal = meal },
                    onPick: { picking = meal },
                    onCancel: { withAnimation(.smooth) { _ = extraSlot.remove(meal) } }
                )
            } else {
                Button("Gang hinzufügen", systemImage: "plus") {
                    withAnimation(.smooth) { _ = extraSlot.insert(meal) }
                }
                .font(.captionSans)
                .foregroundStyle(Color.ink)
                .accessibilityLabel("Gang zum \(meal.title) hinzufügen")
            }
        }
    }

    /// Für diese Mahlzeit laufen Vorschläge – z. B. weil die andere Person gerade swipt.
    private func runningBanner(_ meal: Meal) -> some View {
        let left = decide.myDeck.count
        return Button {
            navigation.decideMeal = meal
        } label: {
            HStack(spacing: 12) {
                ReactionIllustration(reaction: left > 0 ? .jubel : .warten)
                    .frame(width: 40, height: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Vorschläge laufen")
                        .font(.bodySansMedium)
                        .foregroundStyle(Color.ink)
                    Text(left > 0 ? (left == 1 ? "Noch 1 Karte für dich" : "Noch \(left) Karten für dich") : "Du bist durch – warte auf die anderen")
                        .font(.captionSans)
                        .foregroundStyle(Color.inkMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").foregroundStyle(Color.inkMuted)
            }
            .padding(14)
            .background(Color.surface, in: .rect(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.brand, lineWidth: 1.5) }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Ein geplantes Gericht mit „Jetzt kochen“.
struct DishCard: View {
    let entry: MealPlanEntry
    let recipe: Recipe
    let onCook: () -> Void

    @Environment(MealPlanStore.self) private var plan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            NavigationLink(value: recipe.id) {
                HStack(spacing: 14) {
                    RecipeImage(recipe: recipe)
                        .frame(width: 68, height: 68)
                        .clipShape(.rect(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 4) {
                        MetaLabel([entry.note, recipe.totalMinutes.map(Recipe.durationLabel), Recipe.servingsLabel(entry.servings)]
                            .compactMap { $0 }.joined(separator: " · "))
                        Text(recipe.title)
                            .font(.heading(19, relativeTo: .headline))
                            .foregroundStyle(Color.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)

            HStack {
                Button(action: onCook) {
                    Label("Jetzt kochen", systemImage: "flame.fill")
                        .font(.buttonSans)
                        .foregroundStyle(Color.canvas)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(Color.ink, in: .capsule)
                }
                .buttonStyle(.plain)
                .disabled(recipe.steps.isEmpty)
                Spacer()
                Menu {
                    Picker("Portionen", selection: Binding(
                        get: { entry.servings },
                        set: { value in Task { await plan.setServings(value, for: entry) } }
                    )) {
                        ForEach(1...8, id: \.self) { n in
                            Text(Recipe.servingsLabel(n).replacingOccurrences(of: "für ", with: "Für ")).tag(n)
                        }
                    }
                    Divider()
                    Button("Entfernen", systemImage: "trash", role: .destructive) {
                        Task { await plan.remove(entry) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 40, height: 40)
                        .contentShape(.rect)
                }
                .accessibilityLabel("\(recipe.title) bearbeiten")
            }
        }
        .padding(12)
        .background(Color.surface, in: .rect(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).strokeBorder(Color.hairline) }
    }
}

/// Platzhalter einer Mahlzeit (oder eines weiteren Gangs): Vorschläge holen oder ein Rezept aus der Sammlung wählen.
struct EmptyMealSlot: View {
    let meal: Meal
    let isAnotherCourse: Bool
    let onSuggest: () -> Void
    let onPick: () -> Void
    let onCancel: () -> Void

    private var motif: FoodMotif {
        switch meal {
        case .fruehstueck: .spiegelei
        case .mittag: .bowl
        case .abend: .teller
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                FoodIllustration(motif: motif, background: .canvas)
                    .frame(width: 46, height: 46)
                Text(isAnotherCourse ? "Noch ein Gang?" : "Noch nichts geplant")
                    .font(.bodySansMedium)
                    .foregroundStyle(Color.ink)
                Spacer(minLength: 0)
                if isAnotherCourse {
                    Button("Abbrechen", systemImage: "xmark", action: onCancel)
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Color.inkMuted)
                }
            }
            HStack(spacing: 10) {
                Button("Vorschläge", systemImage: "sparkles", action: onSuggest)
                    .accessibilityLabel("Vorschläge fürs \(meal.title)")
                Button("Rezept", systemImage: "book.closed", action: onPick)
                    .accessibilityLabel("Rezept fürs \(meal.title)")
            }
            .buttonStyle(.secondary)
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.inkMuted.opacity(0.45), style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
        }
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
