import SwiftUI

struct RecipeDetailView: View {
    let recipeId: UUID

    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var servings: Int?
    @State private var showsEditor = false
    @State private var confirmsDelete = false
    @State private var error: String?

    var body: some View {
        if let recipe = store.recipe(id: recipeId) {
            content(recipe)
        } else {
            // Gelöscht, z. B. von der anderen Person
            Color.canvas.ignoresSafeArea()
                .onAppear { dismiss() }
        }
    }

    private func content(_ recipe: Recipe) -> some View {
        let currentServings = servings ?? recipe.servings
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RecipeImage(recipe: recipe, emojiSize: 96)
                    .frame(height: 340)
                    .frame(maxWidth: .infinity)
                    .clipped()

                VStack(alignment: .leading, spacing: 28) {
                    header(recipe)
                    ServingsStepper(servings: Binding(
                        get: { currentServings },
                        set: { servings = $0 }
                    ))
                    ingredients(recipe.scaledIngredients(for: currentServings))
                    if !recipe.steps.isEmpty {
                        steps(recipe.steps)
                    }
                    InlineError(message: error)
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 28)
                .padding(.bottom, 40)
                .background(Color.canvas, in: UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28))
                .offset(y: -28)
            }
        }
        .ignoresSafeArea(edges: .top)
        .background(Color.canvas.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Bearbeiten", systemImage: "pencil") { showsEditor = true }
                    if let url = recipe.sourceURL {
                        Link(destination: url) {
                            Label("Original öffnen", systemImage: "safari")
                        }
                    }
                    Divider()
                    Button("Löschen", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Mehr")
            }
        }
        .sheet(isPresented: $showsEditor) {
            RecipeEditorView(recipe: recipe)
        }
        .confirmationDialog("„\(recipe.title)“ löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                Task {
                    do {
                        try await store.delete(recipe)
                    } catch {
                        self.error = userMessage(for: error)
                    }
                }
            }
        } message: {
            Text("Das Rezept verschwindet für euch beide.")
        }
    }

    private func header(_ recipe: Recipe) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let total = recipe.totalMinutes {
                MetaLabel(Recipe.durationLabel(total) + sourceSuffix(recipe))
            }
            Text(recipe.title)
                .font(.titleSerif)
                .tracking(-0.6)
                .foregroundStyle(Color.ink)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let summary = recipe.summary, !summary.isEmpty {
                Text(summary)
                    .font(.bodySans)
                    .foregroundStyle(Color.inkMuted)
                    .lineSpacing(3)
            }
            if !recipe.tags.isEmpty {
                FlowTags(tags: recipe.tags)
            }
        }
    }

    private func sourceSuffix(_ recipe: Recipe) -> String {
        switch recipe.source {
        case .instagram: " · Instagram"
        case .tiktok: " · TikTok"
        case .web: recipe.sourceURL?.host().map { " · " + $0.replacingOccurrences(of: "www.", with: "") } ?? ""
        case .ai: " · Idee von nomnom"
        case .manual: ""
        }
    }

    private func ingredients(_ items: [Ingredient]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionTitle("Zutaten")
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    // DM Sans statt Mono: Mono setzt „½“ winzig
                    Text(item.amountText)
                        .font(.bodySansMedium)
                        .monospacedDigit()
                        .foregroundStyle(Color.ink)
                        .frame(width: 84, alignment: .trailing)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.name).font(.bodySans)
                        if let note = item.note {
                            Text(note).font(.captionSans).foregroundStyle(Color.inkMuted)
                        }
                    }
                    .foregroundStyle(Color.ink)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 11)
                .overlay(alignment: .bottom) {
                    if index < items.count - 1 {
                        Rectangle().fill(Color.hairline).frame(height: 1)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func steps(_ steps: [Recipe.Step]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Zubereitung")
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                StepCard(number: index + 1, step: step)
            }
        }
    }
}

/// Ein Zubereitungsschritt als eigener Block – Grundlage für den Kochmodus.
struct StepCard: View {
    let number: Int
    let step: Recipe.Step

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text("\(number)")
                .font(.custom("Fraunces144pt-Bold", size: 18, relativeTo: .headline))
                .foregroundStyle(Color.ink)
                .frame(width: 34, height: 34)
                .background(Color.mist, in: .circle)
            VStack(alignment: .leading, spacing: 10) {
                Text(step.text)
                    .font(.bodySans)
                    .foregroundStyle(Color.ink)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
                if let seconds = step.timerSeconds, seconds > 0 {
                    Label(Self.timerLabel(seconds), systemImage: "timer")
                        .font(.custom("DMMono-Medium", size: 12, relativeTo: .caption))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.mist, in: .capsule)
                }
            }
            .padding(.top, 5)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Color.surface, in: .rect(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.hairline) }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Schritt \(number): \(step.text)")
    }

    static func timerLabel(_ seconds: Int) -> String {
        let minutes = Int((Double(seconds) / 60).rounded())
        return minutes >= 60 ? Recipe.durationLabel(minutes).uppercased() : "\(max(minutes, 1)) MIN"
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.cardTitle)
            .foregroundStyle(Color.ink)
            .padding(.bottom, 8)
            .accessibilityAddTraits(.isHeader)
    }
}

/// „PORTIONEN  −  2  +“
struct ServingsStepper: View {
    @Binding var servings: Int
    var showsLabel = true

    var body: some View {
        HStack {
            if showsLabel {
                MetaLabel("Portionen")
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                stepButton("minus", label: "Weniger Portionen", enabled: servings > 1) { servings -= 1 }
                Text("\(servings)")
                    .font(.custom("DMMono-Medium", size: 20, relativeTo: .title3))
                    .foregroundStyle(Color.ink)
                    .frame(minWidth: 36)
                    .contentTransition(.numericText())
                    .accessibilityLabel(servings == 1 ? "1 Portion" : "\(servings) Portionen")
                stepButton("plus", label: "Mehr Portionen", enabled: servings < 24) { servings += 1 }
            }
        }
        .padding(.leading, 18)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(Color.surface, in: .capsule)
        .overlay { Capsule().strokeBorder(Color.hairline) }
    }

    private func stepButton(_ icon: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .frame(width: 40, height: 40)
                .background(Color.mist, in: .circle)
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.ink)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .accessibilityLabel(label)
    }
}

/// Tags als kleine Pillen, die umbrechen.
struct FlowTags: View {
    let tags: [String]

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                Text(tag)
                    .font(.captionSans)
                    .foregroundStyle(Color.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.mist, in: .capsule)
            }
        }
    }
}

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews, width: proposal.width ?? .infinity)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(subviews, width: bounds.width) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> [Row] {
        var rows = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > width, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
