import SwiftUI

/// Eingabefeld auf heller Fläche mit dünnem Rand.
struct FieldBackground: ViewModifier {
    var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .font(.bodySans)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 18)
            .frame(minHeight: 56)
            .background(Color.surface, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isFocused ? Color.ink : Color.hairline, lineWidth: isFocused ? 1.5 : 1)
            }
            .animation(.easeOut(duration: 0.15), value: isFocused)
    }
}

extension View {
    func fieldBackground(isFocused: Bool = false) -> some View {
        modifier(FieldBackground(isFocused: isFocused))
    }
}

/// Fehlermeldung unter einem Formular.
struct InlineError: View {
    let message: String?

    var body: some View {
        if let message {
            Label(message, systemImage: "exclamationmark.circle")
                .font(.captionSans)
                .foregroundStyle(Color.tomato)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }
}

/// Grundlayout für Formularschritte: Eyebrow, Headline, Text, Inhalt, Button unten.
struct FormScreen<Content: View, Footer: View>: View {
    let eyebrow: String
    let headline: [String]
    var text: String?
    @ViewBuilder var content: Content
    @ViewBuilder var footer: Footer

    var body: some View {
        ScrollView {
            BrandHeader {
                MetaLabel(eyebrow, font: .eyebrow, tracking: 2.4)
                DisplayHeadline(lines: headline)
                if let text {
                    Text(text)
                        .font(.bodySans)
                        .foregroundStyle(Color.onBrand.opacity(0.9))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        // Kommt die Tastatur, bleibt das Formular unten verankert: Der Kopf rutscht nach oben weg,
        // die Felder bleiben über Tastatur und Button sichtbar.
        .defaultScrollAnchor(.bottom, for: .sizeChanges)
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 8)
                .background(Color.canvas)
        }
        .background(Color.canvas.ignoresSafeArea())
        .brandNavigationBar()
    }
}

/// Primärbutton mit Ladezustand.
struct LoadingButton: View {
    let title: String
    var isLoading: Bool
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isLoading {
                ProgressView().tint(Color.canvas)
            } else {
                Text(title)
            }
        }
        .buttonStyle(PrimaryButtonStyle(showsArrow: !isLoading))
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.4)
    }
}
