import SwiftUI

@main
struct NomiApp: App {
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
    @State private var showsSplash = RootView.splashEnabled

    private static var splashEnabled: Bool {
        #if DEBUG
        // UI-Tests überspringen den Splash, damit sie nicht auf die Animation warten
        ProcessInfo.processInfo.environment["NOMI_SKIP_SPLASH"] != "1"
        #else
        true
        #endif
    }

    var body: some View {
        #if DEBUG
        if let gallery = ProcessInfo.processInfo.environment["NOMI_GALLERY"] {
            IllustrationGallery()
                .preferredColorScheme(gallery == "dark" ? .dark : nil)
        } else {
            withSplash
        }
        #else
        withSplash
        #endif
    }

    private var withSplash: some View {
        ZStack {
            content
            if showsSplash {
                SplashView(isReady: app.phase != .loading) {
                    withAnimation(.easeOut(duration: 0.35)) { showsSplash = false }
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
    }

    private var content: some View {
        Group {
            switch app.phase {
            case .loading:
                // Steht nur hinter dem Splash; Himbeere, damit beim Ausblenden nichts aufblitzt
                Color.brand.ignoresSafeArea()
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
