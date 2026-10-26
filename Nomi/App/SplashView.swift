import SwiftUI

/// Start: Chefi hüpft herein, hebt den Löffel und zwinkert, winkt – dann erscheint „nomi“.
/// Läuft knapp zweieinhalb Sekunden. Ist die App danach noch nicht so weit, rührt Chefi weiter, bis `isReady` kommt.
struct SplashView: View {
    var isReady: Bool
    var onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var arrived = false
    @State private var squash = false
    @State private var spoonTilt: CGFloat = -0.5
    @State private var spoonLift: CGFloat = 0
    @State private var winks = false
    @State private var waves = false
    @State private var showsWordmark = false
    @State private var sequenceDone = false
    /// Spiegel von `isReady`: Die laufende Task sieht nur eine Kopie der View, @State dagegen live.
    @State private var ready = false

    var body: some View {
        ZStack {
            Color.brand.ignoresSafeArea()
            VStack(spacing: 18) {
                ChefiView(spoonTilt: spoonTilt, spoonLift: spoonLift, winks: winks, waves: waves)
                    .frame(width: 190)
                    .scaleEffect(x: squash ? 1.1 : 1, y: squash ? 0.9 : 1, anchor: .bottom)
                    .offset(y: arrived ? 0 : 420)
                Text("nomi")
                    .font(.heading(52, relativeTo: .largeTitle))
                    .tracking(-2)
                    .foregroundStyle(Color.onBrand)
                    .opacity(showsWordmark ? 1 : 0)
                    .offset(y: showsWordmark ? 0 : 12)
            }
            .offset(y: -30)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("nomi")
        .accessibilityIdentifier("splash")
        .task { await play() }
        .onChange(of: isReady, initial: true) { _, new in
            ready = new
            finishIfPossible()
        }
    }

    private func play() async {
        guard !reduceMotion else {
            arrived = true; waves = true; showsWordmark = true
            try? await Task.sleep(for: .milliseconds(1000))
            sequenceDone = true
            finishIfPossible()
            return
        }
        // 1 · hereinhüpfen, beim Landen kurz stauchen
        withAnimation(.spring(duration: 0.55, bounce: 0.25)) { arrived = true }
        try? await Task.sleep(for: .milliseconds(450))
        withAnimation(.easeOut(duration: 0.12)) { squash = true }
        try? await Task.sleep(for: .milliseconds(120))
        withAnimation(.spring(duration: 0.35, bounce: 0.5)) { squash = false }
        try? await Task.sleep(for: .milliseconds(250))

        // 2 · Löffel hoch, zwinkern
        withAnimation(.spring(duration: 0.45, bounce: 0.4)) {
            spoonTilt = -0.08
            spoonLift = 20
        }
        winks = true
        try? await Task.sleep(for: .milliseconds(600))
        winks = false
        try? await Task.sleep(for: .milliseconds(150))

        // 3 · winken, Wortmarke – und kurz stehen lassen
        withAnimation(.spring(duration: 0.45, bounce: 0.3)) {
            spoonTilt = -0.32
            spoonLift = 0
            waves = true
            showsWordmark = true
        }
        try? await Task.sleep(for: .milliseconds(900))
        sequenceDone = true
        finishIfPossible()
        if !ready { await stir() }
    }

    /// Warten auf die App: langsames Rühren
    private func stir() async {
        withAnimation(.easeInOut(duration: 0.3)) { waves = false }
        while !ready && !Task.isCancelled {
            withAnimation(.easeInOut(duration: 0.5)) { spoonTilt = -0.12 }
            try? await Task.sleep(for: .milliseconds(500))
            withAnimation(.easeInOut(duration: 0.5)) { spoonTilt = -0.45 }
            try? await Task.sleep(for: .milliseconds(500))
        }
    }

    private func finishIfPossible() {
        if sequenceDone && ready { onFinished() }
    }
}

#Preview {
    SplashView(isReady: false) {}
}
