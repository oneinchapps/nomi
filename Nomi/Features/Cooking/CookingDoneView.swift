import SwiftUI

/// Letzte Seite im Kochmodus: Chefi tanzt vor Glück mit dem Löffel, Herzen steigen auf, dann bleibt er
/// mit Herzaugen stehen. Entwurf: design/cooking/rezept-fertig.png (Variante B).
struct CookingDoneView: View {
    let recipeTitle: String
    /// Erst auf der Seite angekommen startet der Tanz (die Seitenansicht legt Seiten schon vorher an)
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dancing = false
    @State private var beat = false
    @State private var settled = false
    @State private var breathe = false
    @State private var heartsFrom: Date?
    @State private var heartsUntil: Date?

    var body: some View {
        VStack(spacing: 14) {
            Spacer()
            ZStack(alignment: .bottom) {
                RisingHearts(from: heartsFrom, until: heartsUntil)
                ChefiView(
                    spoonTilt: dancing ? (beat ? 0.1 : -0.6) : -0.3,
                    mouth: .laugh,
                    eyes: settled ? .hearts : .happy
                )
                .frame(width: 210)
                .scaleEffect(breathe ? 1.03 : 1, anchor: .bottom)
                .rotationEffect(.degrees(dancing ? (beat ? -7 : 7) : 0), anchor: .bottom)
                .offset(y: dancing && beat ? -6 : 0)
            }
            .frame(height: 310)
            Text("Guten Appetit!")
                .font(.display)
                .tracking(-1)
                .foregroundStyle(Color.ink)
            Text("\(recipeTitle) ist fertig. Lasst es euch schmecken.")
                .font(.bodySans)
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Metrics.gutter)
        .sensoryFeedback(.success, trigger: isActive) { _, active in active }
        .task(id: isActive) {
            guard isActive else {
                reset()
                return
            }
            await play()
        }
    }

    private func play() async {
        guard !reduceMotion else {
            settled = true
            return
        }
        heartsFrom = .now
        heartsUntil = nil
        dancing = true
        // Sechs Wipper, links-rechts
        for _ in 0..<6 {
            withAnimation(.easeInOut(duration: 0.4)) { beat.toggle() }
            try? await Task.sleep(for: .seconds(0.42))
            if Task.isCancelled { return }
        }
        heartsUntil = .now
        withAnimation(.spring(duration: 0.5, bounce: 0.4)) {
            dancing = false
            settled = true
        }
        // Verliebt stehen bleiben und leise atmen
        try? await Task.sleep(for: .seconds(0.5))
        withAnimation(.easeInOut(duration: 1.3).repeatForever(autoreverses: true)) { breathe = true }
        // Letzte Herzen verblassen lassen, dann die Zeitleiste anhalten (spart Akku)
        try? await Task.sleep(for: .seconds(1.4))
        heartsFrom = nil
    }

    private func reset() {
        dancing = false
        beat = false
        settled = false
        breathe = false
        heartsFrom = nil
        heartsUntil = nil
    }
}

/// Herzen, die neben Chefi aufsteigen und verblassen. Rein aus der Zeit berechnet, ohne eigenen Zustand.
private struct RisingHearts: View {
    let from: Date?
    let until: Date?

    private static let interval = 0.28
    private static let lifetime = 1.8

    var body: some View {
        TimelineView(.animation(paused: from == nil)) { context in
            GeometryReader { geo in
                ForEach(hearts(at: context.date), id: \.index) { heart in
                    Image(systemName: "heart.fill")
                        .font(.system(size: heart.size))
                        .foregroundStyle(Color.brand)
                        .opacity(heart.opacity)
                        .position(x: geo.size.width / 2 + heart.x * geo.size.width, y: geo.size.height * (0.75 - 0.7 * heart.progress))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private struct Heart {
        let index: Int
        let x: CGFloat
        let size: CGFloat
        let progress: Double
        let opacity: Double
    }

    private func hearts(at now: Date) -> [Heart] {
        guard let from else { return [] }
        let elapsed = now.timeIntervalSince(from)
        let last = until.map { $0.timeIntervalSince(from) } ?? elapsed
        let spawned = Int(min(elapsed, last) / Self.interval)
        guard spawned >= 0 else { return [] }
        return (0...spawned).compactMap { index in
            let age = elapsed - Double(index) * Self.interval
            guard age >= 0, age < Self.lifetime else { return nil }
            let progress = age / Self.lifetime
            // Fest pro Herz, damit es nicht springt: links und rechts von Chefi, nie mitten durchs Gesicht
            let side: CGFloat = index.isMultiple(of: 2) ? -1 : 1
            let spread = CGFloat((index * 37) % 17) / 17
            return Heart(
                index: index,
                x: side * (0.24 + 0.16 * spread) + CGFloat(sin(age * 4 + Double(index))) * 0.02,
                size: 12 + CGFloat((index * 11) % 7) * 2,
                progress: progress,
                opacity: progress < 0.15 ? progress / 0.15 : 1 - (progress - 0.15) / 0.85
            )
        }
    }
}
