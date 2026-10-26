import SwiftUI

/// Wartezustand – das Auslesen dauert ein paar Sekunden, deshalb mit etwas Bewegung.
struct ImportProgressView: View {
    static let defaultMessages = ["Seite wird geöffnet …", "Zutaten werden gezählt …", "Schritte werden sortiert …", "Fast fertig …"]

    var messages = defaultMessages
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let motifs: [FoodMotif] = [.gemuese, .suppe, .nudeln, .fisch, .kuchen, .taco]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            let motif = motifs[step % motifs.count]
            FoodIllustration(motif: motif, background: .mist)
                .frame(width: 76, height: 76)
                .frame(width: 120, height: 120)
                .background(Color.mist, in: .circle)
                .id(motif)
                .transition(.scale(scale: 0.8).combined(with: .opacity))
                .rotationEffect(.degrees(reduceMotion ? 0 : Double(step % 2 == 0 ? -6 : 6)))
            VStack(spacing: 8) {
                Text("nomnom liest mit")
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                Text(messages[min(step / 2, messages.count - 1)])
                    .font(.bodySans)
                    .foregroundStyle(Color.inkMuted)
                    .contentTransition(.opacity)
            }
            Spacer()
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                withAnimation(.smooth) { step += 1 }
            }
        }
    }
}
