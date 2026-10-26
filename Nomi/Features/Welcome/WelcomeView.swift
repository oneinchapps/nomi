import SwiftUI

struct WelcomeView: View {
    var onStart: () -> Void
    var onInvite: () -> Void = {}

    var body: some View {
        VStack(spacing: 0) {
            header
            copy
            Spacer(minLength: 24)
            VStack(spacing: 14) {
                Button("Gemeinsam Essen finden", action: onStart)
                    .buttonStyle(.primary)
                Button("Ich habe eine Einladung", action: onInvite)
                    .font(.bodySansMedium)
                    .foregroundStyle(Color.ink)
                    .frame(minHeight: 44)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.bottom, 4)
        }
        .background(Color.canvas.ignoresSafeArea())
    }

    private var header: some View {
        RecipeCarousel(recipes: Recipe.samples)
            .padding(.bottom, 56)
            .background(alignment: .top) {
                CurvedBottom(depth: 44)
                    .fill(Color.brand)
                    .padding(.top, -200)
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("nomi")
                        .font(.logo)
                        .tracking(-0.8)
                        .foregroundStyle(Color.onBrand)
                        .accessibilityAddTraits(.isHeader)
                }
                .sharedBackgroundVisibility(.hidden)
            }
            .brandNavigationBar()
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: 16) {
            DisplayHeadline(lines: ["Weniger", "„Was essen wir?“"])
            Text("Findet ein Rezept, das ihr beide liebt – ein Swipe nach dem anderen.")
                .font(.bodySans)
                .foregroundStyle(Color.inkMuted)
                .lineSpacing(3)
                .frame(maxWidth: 320, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 40)
    }
}

/// Horizontal blätterbare Karten; die mittlere steht gerade, die äußeren kippen leicht weg.
struct RecipeCarousel: View {
    let recipes: [Recipe]
    @State private var position: UUID?
    @State private var width: CGFloat = 0
    @State private var lastInteraction = Date.distantPast
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let cardWidth: CGFloat = 210

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 14) {
                ForEach(recipes) { recipe in
                    RecipeCard(recipe: recipe, width: cardWidth)
                        .scrollTransition(axis: .horizontal) { content, phase in
                            content
                                .rotationEffect(.degrees(phase.value * 5))
                                .scaleEffect(phase.isIdentity ? 1 : 0.86)
                                .offset(y: phase.isIdentity ? 0 : 16)
                                .opacity(phase.isIdentity ? 1 : 0.85)
                        }
                }
            }
            .scrollTargetLayout()
            .padding(.vertical, 24)
        }
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $position, anchor: .center)
        .safeAreaPadding(.horizontal, max(0, (width - cardWidth) / 2))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .onScrollPhaseChange { _, phase in
            // .animating kommt auch vom automatischen Blättern, zählt also nicht als Berührung.
            if phase.isScrolling, phase != .animating { lastInteraction = .now }
        }
        .onAppear { position = recipes[recipes.count / 2].id }
        .task { await autoAdvance() }
    }

    /// Blättert langsam weiter, damit der Screen lebendig wirkt.
    private func autoAdvance() async {
        guard !reduceMotion, recipes.count > 1 else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(3.5))
            guard Date.now.timeIntervalSince(lastInteraction) > 6,
                  let current = recipes.firstIndex(where: { $0.id == position }) else { continue }
            let next = (current + 1) % recipes.count
            withAnimation(.smooth(duration: 0.7)) { position = recipes[next].id }
        }
    }
}

/// Rechteck mit sanft nach unten gewölbter Unterkante.
struct CurvedBottom: Shape {
    var depth: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: .zero)
        path.addLine(to: CGPoint(x: rect.maxX, y: 0))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - depth))
        path.addQuadCurve(
            to: CGPoint(x: 0, y: rect.maxY - depth),
            control: CGPoint(x: rect.midX, y: rect.maxY + depth)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    WelcomeView {}
}
