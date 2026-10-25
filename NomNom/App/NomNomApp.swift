import SwiftUI

@main
struct NomNomApp: App {
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .task { await app.observeAuth() }
        }
    }
}

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .loading:
                Color.canvas.ignoresSafeArea()
            case .signedOut:
                SignInFlow()
            case .needsHousehold:
                HouseholdSetupView()
            case .ready:
                if let household = app.household {
                    MainTabView(householdId: household.id)
                        .id(household.id)
                }
            }
        }
        .animation(.smooth, value: app.phase)
        .tint(Color.ink)
    }
}
