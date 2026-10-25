import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var app
    @State private var recipes: RecipeStore
    @State private var shopping: ShoppingStore
    @State private var plan: MealPlanStore
    @State private var decide: DecideStore

    init(householdId: UUID, userId: UUID) {
        _decide = State(initialValue: DecideStore(householdId: householdId, userId: userId))
        _recipes = State(initialValue: RecipeStore(householdId: householdId))
        _shopping = State(initialValue: ShoppingStore(householdId: householdId, userId: userId))
        _plan = State(initialValue: MealPlanStore(householdId: householdId))
    }

    var body: some View {
        TabView {
            Tab("Heute", systemImage: "fork.knife") {
                TabRoot {
                    TodayView()
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
        .tint(Color.brand)
        .environment(recipes)
        .environment(shopping)
        .environment(plan)
        .environment(decide)
        .task { await recipes.load() }
        .task { await recipes.observeChanges() }
        .task { await shopping.load() }
        .task { await shopping.observeChanges() }
        .task { await plan.load() }
        .task { await plan.observeChanges() }
        .task { await decide.load() }
        .task { await decide.observeChanges() }
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
                            .font(.logo)
                            .tracking(-0.6)
                            .foregroundStyle(Color.onBrand)
                            .fixedSize()
                    }
                    // Ohne Glas-Kapsel: direkt weiß auf Himbeere
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .topBarTrailing) {
                        ProfileButton()
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                .brandNavigationBar()
                .tint(Color.ink)
        }
    }
}
