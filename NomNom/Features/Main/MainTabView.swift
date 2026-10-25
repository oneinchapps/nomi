import SwiftUI

struct MainTabView: View {
    @State private var recipes: RecipeStore

    init(householdId: UUID) {
        _recipes = State(initialValue: RecipeStore(householdId: householdId))
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
                    ComingSoonView(
                        eyebrow: "Gemeinsame Liste",
                        title: "Einkauf",
                        text: "Nach Abteilung sortiert, live abgehakt – ihr seht, was schon im Wagen liegt."
                    )
                }
            }
            Tab("Woche", systemImage: "calendar") {
                TabRoot {
                    ComingSoonView(
                        eyebrow: "Wochenplan",
                        title: "Diese Woche",
                        text: "Rezepte auf Tage legen, die Einkaufsliste füllt sich von selbst."
                    )
                }
            }
        }
        .environment(recipes)
        .task { await recipes.load() }
        .task { await recipes.observeChanges() }
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
