import SwiftUI

/// Mono-Großbuchstaben mit Sperrung, für Metadaten und Eyebrows.
struct MetaLabel: View {
    let text: String
    var font: Font = .meta
    var tracking: CGFloat = 1.4
    @Environment(\.onBrandSurface) private var onBrand

    init(_ text: String, font: Font = .meta, tracking: CGFloat = 1.4) {
        self.text = text
        self.font = font
        self.tracking = tracking
    }

    var body: some View {
        Text(text.uppercased(with: Locale(identifier: "de_DE")))
            .font(font)
            .tracking(tracking)
            .foregroundStyle(onBrand ? Color.onBrand.opacity(0.85) : Color.inkMuted)
    }
}

extension EnvironmentValues {
    /// true innerhalb von BrandHeader – Texte schalten dann auf onBrand.
    @Entry var onBrandSurface = false
}

/// Kopfbereich in Markenfarbe. Reicht nach oben unter die Navigationsleiste (die ebenfalls in Markenfarbe ist)
/// und endet unten mit runden Ecken.
struct BrandHeader<Content: View>: View {
    var bottomPadding: CGFloat = 30
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            content
        }
        .environment(\.onBrandSurface, true)
        .foregroundStyle(Color.onBrand)
        .tint(Color.onBrand)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 10)
        .padding(.bottom, bottomPadding)
        .background(alignment: .bottom) {
            // Nach oben großzügig verlängert, damit beim Überscrollen keine Lücke entsteht
            UnevenRoundedRectangle(bottomLeadingRadius: 32, bottomTrailingRadius: 32)
                .fill(Color.brand)
                .padding(.top, -1000)
        }
    }
}

extension View {
    /// Kopfleiste in Markenfarbe mit heller Schrift und heller Statusleiste.
    ///
    /// Die Navigationsleiste selbst bleibt durchsichtig – ihr eigener Hintergrund bekommt unter iOS 26 eine
    /// Material-Schicht und wirkt dann dunkler als der BrandHeader darunter. Stattdessen liegt eine
    /// durchgehende Fläche in Markenfarbe über dem Bereich der Leiste, über die der Inhalt scrollt.
    func brandNavigationBar() -> some View {
        toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .scrollEdgeEffectHidden(true, for: .top)
            .overlay(alignment: .top) {
                GeometryReader { geo in
                    Color.brand
                        .frame(height: geo.safeAreaInsets.top)
                        .offset(y: -geo.safeAreaInsets.top)
                }
                .allowsHitTesting(false)
            }
    }
}

/// Große Headline mit enger Zeilenführung. Negatives `lineSpacing` greift in SwiftUI nicht,
/// deshalb wird jede Zeile einzeln gesetzt.
struct DisplayHeadline: View {
    let lines: [String]
    @Environment(\.onBrandSurface) private var onBrand

    var body: some View {
        VStack(alignment: .leading, spacing: -10) {
            ForEach(lines, id: \.self) { line in
                ZStack(alignment: .leading) {
                    // Hält die volle Zeilenhöhe, auch wenn die Zeile verkleinert wird –
                    // so sind alle Köpfe gleich hoch, egal wie lang der Titel ist
                    Text("Ag").font(.display).hidden()
                    Text(line)
                        .font(.display)
                        .tracking(-1)
                        // Jede Zeile ist bewusst gesetzt: lieber etwas kleiner als unschön umbrechen
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(onBrand ? Color.onBrand : Color.ink)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Wortmarke „nomi“: DynaPuff mit angebissenem Ocker-o, als Vektorgrafik aus
/// design/appicon/render-icon-concepts.swift (`--export`). `onLight` für hellen Grund.
struct Wordmark: View {
    var height: CGFloat = 24
    var onLight = false

    /// Seitenverhältnis des PDFs (307,6 × 100)
    private static let aspectRatio: CGFloat = 3.076

    var body: some View {
        // Feste Breite und Höhe: In der Toolbar würden Bilder sonst auf Symbolgröße gestaucht
        Image(onLight ? "WordmarkOnLight" : "Wordmark", label: Text("nomi"))
            .resizable()
            .frame(width: height * Self.aspectRatio, height: height)
            .fixedSize()
            .accessibilityAddTraits(.isHeader)
    }
}

/// Anzahl im kleinen Kreis neben der Überschrift eines BrandHeader; bei drei Stellen wird er zur Pille.
struct CountBadge: View {
    let count: Int
    /// Was die Zahl bedeutet, z. B. „3 Rezepte“ oder „5 offen“
    let accessibilityLabel: String

    var body: some View {
        Text("\(count)")
            .font(.custom("DMMono-Medium", size: 14, relativeTo: .subheadline))
            .monospacedDigit()
            .foregroundStyle(Color.onBrand)
            .padding(.horizontal, 8)
            .frame(minWidth: 32, minHeight: 32)
            .background(Color.onBrand.opacity(0.2), in: .capsule)
            .contentTransition(.numericText())
            .animation(.smooth, value: count)
            .accessibilityLabel(accessibilityLabel)
    }
}

/// Volle Breite, dunkle Pille mit Pfeil – die Hauptaktion eines Screens.
struct PrimaryButtonStyle: ButtonStyle {
    var showsArrow = true

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.buttonSans)
                // Haupt-Buttons immer einzeilig – lieber minimal kleiner als umbrechen
                .lineLimit(1)
                .minimumScaleFactor(0.85)
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

/// Rezeptfoto, oder eine nomi-Illustration, solange es keins gibt.
/// Nimmt genau den angebotenen Platz ein – das Foto füllt ihn und wird beschnitten,
/// statt mit seinem Seitenverhältnis das Layout aufzudrücken.
struct RecipeImage: View {
    let recipe: Recipe

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
        IllustrationTile(motif: recipe.motif)
    }
}
