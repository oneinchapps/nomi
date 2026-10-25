import SwiftUI

/// Mono-Großbuchstaben mit Sperrung, für Metadaten und Eyebrows.
struct MetaLabel: View {
    let text: String
    var font: Font = .meta
    var tracking: CGFloat = 1.4

    init(_ text: String, font: Font = .meta, tracking: CGFloat = 1.4) {
        self.text = text
        self.font = font
        self.tracking = tracking
    }

    var body: some View {
        Text(text.uppercased(with: Locale(identifier: "de_DE")))
            .font(font)
            .tracking(tracking)
            .foregroundStyle(Color.inkMuted)
    }
}

/// Serifen-Headline mit enger Zeilenführung. Negatives `lineSpacing` greift in SwiftUI nicht,
/// deshalb wird jede Zeile einzeln gesetzt.
struct DisplayHeadline: View {
    let lines: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: -10) {
            ForEach(lines, id: \.self) { line in
                Text(line)
                    .font(.display)
                    .tracking(-1)
                    .foregroundStyle(Color.ink)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Volle Breite, dunkle Pille mit Pfeil – die Hauptaktion eines Screens.
struct PrimaryButtonStyle: ButtonStyle {
    var showsArrow = true

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.buttonSans)
            Spacer(minLength: 12)
            if showsArrow {
                Image(systemName: "arrow.right")
                    .font(.system(size: 17, weight: .medium))
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, minHeight: 58)
        .foregroundStyle(Color.canvas)
        .background(Color.ink, in: .rect(cornerRadius: Metrics.buttonRadius))
        .opacity(configuration.isPressed ? 0.85 : 1)
        .scaleEffect(configuration.isPressed ? 0.98 : 1)
        .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}

/// Heller Pillen-Button mit Rand für Nebenaktionen („Einkaufen“, „Einplanen“).
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.bodySansMedium)
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Color.surface, in: .capsule)
            .overlay { Capsule().strokeBorder(Color.hairline) }
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var secondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var primary: PrimaryButtonStyle { PrimaryButtonStyle() }
}

/// Polaroid-artige Rezeptkarte: Bild oben, Meta und Titel darunter.
struct RecipeCard: View {
    let recipe: Recipe
    var width: CGFloat = 220

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            RecipeImage(recipe: recipe)
                .frame(height: width * 0.78)
                .clipShape(.rect(cornerRadius: 14))

            VStack(alignment: .leading, spacing: 6) {
                MetaLabel(recipe.metaLine)
                Text(recipe.title)
                    .font(.cardTitle)
                    .foregroundStyle(Color.ink)
                    .lineSpacing(-4)
                    .lineLimit(2, reservesSpace: true)
            }
            .padding(.horizontal, 4)
        }
        .padding(12)
        .padding(.bottom, 6)
        .frame(width: width)
        .background(Color.surface, in: .rect(cornerRadius: Metrics.cardRadius))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
    }
}

/// Rezeptfoto, oder ein getönter Platzhalter mit Emoji, solange es keins gibt.
/// Nimmt genau den angebotenen Platz ein – das Foto füllt ihn und wird beschnitten,
/// statt mit seinem Seitenverhältnis das Layout aufzudrücken.
struct RecipeImage: View {
    let recipe: Recipe
    var emojiSize: CGFloat = 72

    var body: some View {
        Color.clear
            .overlay { content }
            .clipped()
    }

    @ViewBuilder
    private var content: some View {
        if let url = recipe.imageURL {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Rectangle().fill(recipe.tint.gradient)
            Text(recipe.emoji)
                .font(.system(size: emojiSize))
                .shadow(color: .black.opacity(0.15), radius: 8, y: 6)
        }
    }
}
