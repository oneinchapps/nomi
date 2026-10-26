import SwiftUI

/// Welcher Tab offen ist – nomi springt damit in den passenden Bereich.
@Observable
final class AppNavigation {
    var tab: AppTab = .nomi
    /// Öffnet im Heute-Tab das Auswahlblatt (Vorschläge, swipen) für diese Mahlzeit
    var decideMeal: Meal?
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

    /// Eigene Linien-Icons (design/tabbar); aktiv mit gefüllten Akzenten
    private func tabIcon(_ name: String, _ tab: AppTab) -> String {
        navigation.tab == tab ? "Tab\(name)Active" : "Tab\(name)"
    }

    var body: some View {
        @Bindable var navigation = navigation
        TabView(selection: $navigation.tab) {
            Tab("nomi", image: tabIcon("Nomi", .nomi), value: AppTab.nomi) {
                TabRoot {
                    NomiView()
                }
            }
            Tab("Heute", image: tabIcon("Today", .today), value: AppTab.today) {
                TabRoot {
                    TodayView()
                }
            }
            Tab("Woche", image: tabIcon("Week", .week), value: AppTab.week) {
                TabRoot {
                    WeekPlanView()
                }
            }
            Tab("Rezepte", image: tabIcon("Recipes", .recipes), value: AppTab.recipes) {
                TabRoot {
                    RecipesView()
                }
            }
            Tab("Einkauf", image: tabIcon("Shopping", .shopping), value: AppTab.shopping) {
                TabRoot {
                    ShoppingListView()
                }
            }
            .badge(shopping.openItems.count)
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

/// Navigationsrahmen jedes Tabs. Die Toolbar setzt jeder Hauptscreen selbst per `mainToolbar`:
/// Toolbar-Elemente eines äußeren Rahmens landen vor denen des Screens – das Profil-Icon soll aber
/// immer ganz rechts stehen.
struct TabRoot<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        NavigationStack {
            content
                .brandNavigationBar()
                .tint(Color.ink)
        }
    }
}

extension View {
    /// Toolbar der Hauptscreens: Logo links, die Knöpfe des Screens, Profil immer ganz rechts.
    func mainToolbar<Trailing: ToolbarContent>(@ToolbarContentBuilder trailing: () -> Trailing) -> some View {
        toolbar {
            logoItem
            trailing()
            profileItem
        }
    }

    /// Hauptscreen ohne eigene Knöpfe
    func mainToolbar() -> some View {
        toolbar {
            logoItem
            profileItem
        }
    }
}

@ToolbarContentBuilder
private var logoItem: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
        Wordmark(height: 31)
    }
    // Ohne Glas-Kapsel: direkt weiß auf Himbeere
    .sharedBackgroundVisibility(.hidden)
}

@ToolbarContentBuilder
private var profileItem: some ToolbarContent {
    ToolbarItem(placement: .topBarTrailing) {
        ProfileButton()
    }
    .sharedBackgroundVisibility(.hidden)
}
