import SwiftUI

/// Wartezustand – das Auslesen dauert ein paar Sekunden, deshalb mit etwas Bewegung.
struct ImportProgressView: View {
    static let defaultMessages = ["Seite wird geöffnet …", "Zutaten werden gezählt …", "Schritte werden sortiert …", "Fast fertig …"]

    var messages = defaultMessages
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let emojis = ["🥕", "🧄", "🍋", "🌶️", "🧀", "🍅"]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text(emojis[step % emojis.count])
                .font(.system(size: 64))
                .frame(width: 120, height: 120)
                .background(Color.mist, in: .circle)
                .contentTransition(.opacity)
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
