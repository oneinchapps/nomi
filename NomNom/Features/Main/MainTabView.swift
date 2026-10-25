import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var app
    @State private var recipes: RecipeStore
    @State private var shopping: ShoppingStore
    @State private var plan: MealPlanStore

    init(householdId: UUID, userId: UUID) {
        _recipes = State(initialValue: RecipeStore(householdId: householdId))
        _shopping = State(initialValue: ShoppingStore(householdId: householdId, userId: userId))
        _plan = State(initialValue: MealPlanStore(householdId: householdId))
    }

    var body: some View {
        TabView {
            Tab("Heute", systemImage: "fork.knife") {
                TabRoot {
                    ComingSoonView(
                        eyebrow: "Abendessen, entschieden",
                        title: "Worauf habt ihr Lust?",
                        text: "Hier chattet ihr mit nomnom, swipet Vorschläge und findet euer Match.",
                        showsInvite: true
                    )
                }
            }
            Tab("Rezepte", systemImage: "book.closed") {
                TabRoot {
                    RecipesView()
                }
            }
            Tab("Einkauf", systemImage: "basket") {
                TabRoot {
                    ShoppingListView()
                }
            }
            .badge(shopping.openItems.count)
            Tab("Woche", systemImage: "calendar") {
                TabRoot {
                    WeekPlanView()
                }
            }
        }
        .environment(recipes)
        .environment(shopping)
        .environment(plan)
        .task { await recipes.load() }
        .task { await recipes.observeChanges() }
        .task { await shopping.load() }
        .task { await shopping.observeChanges() }
        .task { await plan.load() }
        .task { await plan.observeChanges() }
        .task {
            await observeTable("household_members", householdId: recipes.householdId) { [app] in
                await app.loadHousehold()
            }
        }
    }
}

/// Navigationsrahmen jedes Tabs: Logo links, Profil rechts.
struct TabRoot<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Text("nomnom")
                            .font(.custom("Fraunces144pt-Bold", size: 22, relativeTo: .headline))
                            .tracking(-0.6)
                            .foregroundStyle(Color.ink)
                            .fixedSize()
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        ProfileButton()
                    }
                }
                .toolbarBackground(Color.canvas, for: .navigationBar)
        }
    }
}

/// Platzhalter im nomnom-Stil, bis das jeweilige Feature gebaut ist.
struct ComingSoonView: View {
    @Environment(AppModel.self) private var app

    let eyebrow: String
    let title: String
    let text: String
    var showsInvite = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MetaLabel(eyebrow, font: .eyebrow, tracking: 2.4)
                DisplayHeadline(lines: [title])
                Text(text)
                    .font(.bodySans)
                    .foregroundStyle(Color.inkMuted)
                    .lineSpacing(3)

                if showsInvite, app.partner == nil, let household = app.household {
                    InviteCard(code: household.inviteCode)
                        .padding(.top, 20)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 16)
        }
        .background(Color.canvas.ignoresSafeArea())
    }
}
