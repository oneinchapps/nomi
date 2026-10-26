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
        #if DEBUG
        if let gallery = ProcessInfo.processInfo.environment["NOMNOM_GALLERY"] {
            IllustrationGallery()
                .preferredColorScheme(gallery == "dark" ? .dark : nil)
        } else {
            content
        }
        #else
        content
        #endif
    }

    private var content: some View {
        Group {
            switch app.phase {
            case .loading:
                Color.canvas.ignoresSafeArea()
            case .signedOut:
                SignInFlow()
            case .needsHousehold:
                // NavigationStack nur für die Markenleiste (helle Statusleiste)
                NavigationStack { HouseholdSetupView() }
            case .ready:
                if let household = app.household, let userId = app.userId {
                    MainTabView(householdId: household.id, userId: userId)
                        .id(household.id)
                }
            }
        }
        .animation(.smooth, value: app.phase)
        .tint(Color.ink)
    }
}
