import SwiftUI

/// Welcher Tab offen ist – nomi springt damit in den passenden Bereich.
@Observable
final class AppNavigation {
    var tab: AppTab = .nomi
}

struct MainTabView: View {
    @Environment(AppModel.self) private var app
    @State private var navigation = AppNavigation()
    @State private var assistant: AssistantStore
    @State private var recipes: RecipeStore
    @State private var shopping: ShoppingStore
    @State private var plan: MealPlanStore
    @State private var decide: DecideStore
    @State private var cookingLog: CookingLogStore

    init(householdId: UUID, userId: UUID) {
        _assistant = State(initialValue: AssistantStore(householdId: householdId, userId: userId))
        _decide = State(initialValue: DecideStore(householdId: householdId, userId: userId))
        _cookingLog = State(initialValue: CookingLogStore(householdId: householdId, userId: userId))
        _recipes = State(initialValue: RecipeStore(householdId: householdId))
        _shopping = State(initialValue: ShoppingStore(householdId: householdId, userId: userId))
        _plan = State(initialValue: MealPlanStore(householdId: householdId))
    }

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.tab) {
            Tab("nomi", image: "TabNomi", value: AppTab.nomi) {
                TabRoot {
                    NomiView()
                }
            }
            Tab("Heute", systemImage: "fork.knife", value: AppTab.today) {
                TabRoot {
                    TodayView()
                }
            }
            Tab("Rezepte", systemImage: "book.closed", value: AppTab.recipes) {
                TabRoot {
                    RecipesView()
                }
            }
            Tab("Einkauf", systemImage: "basket", value: AppTab.shopping) {
                TabRoot {
                    ShoppingListView()
                }
            }
            .badge(shopping.openItems.count)
            Tab("Woche", systemImage: "calendar", value: AppTab.week) {
                TabRoot {
                    WeekPlanView()
                }
            }
        }
        .tint(Color.brand)
        .environment(navigation)
        .environment(assistant)
        .environment(recipes)
        .environment(shopping)
        .environment(plan)
        .environment(decide)
        .environment(cookingLog)
        .task { await assistant.load() }
        .task { await assistant.observeChanges() }
        .task { await recipes.load() }
        .task { await recipes.observeChanges() }
        .task { await shopping.load() }
        .task { await shopping.observeChanges() }
        .task { await plan.load() }
        .task { await plan.observeChanges() }
        .task { await decide.load() }
        .task { await decide.observeChanges() }
        .task { await cookingLog.load() }
        .task { await cookingLog.observeChanges() }
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
                        Text("nomi")
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
