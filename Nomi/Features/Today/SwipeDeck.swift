import SwiftUI

/// Kartenstapel: rechts wischen = lecker, links = nö. Buttons darunter für alle, die nicht wischen wollen.
/// „Das nehmen wir“ legt die oberste Karte allein für den Haushalt fest – ohne auf ein Match zu warten.
struct SwipeDeck: View {
    let deck: [SessionCandidate]
    let recipe: (UUID) -> Recipe?
    let onVote: (SessionCandidate, Bool) -> Void
    let onDecide: (SessionCandidate) -> Void

    @State private var drag: CGSize = .zero
    @State private var leaving: (id: UUID, liked: Bool)?

    private let threshold: CGFloat = 110

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach(Array(deck.prefix(3).enumerated().reversed()), id: \.element.id) { index, candidate in
                    card(candidate, depth: index)
                }
            }
            .frame(height: 430)
            .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                voteButton(liked: false)
                decideButton
                voteButton(liked: true)
            }
            MetaLabel(deck.count == 1 ? "Letzte Karte" : "\(deck.count) Karten")
        }
    }

    // MARK: - Karte

    private func card(_ candidate: SessionCandidate, depth: Int) -> some View {
        let isTop = depth == 0
        let offset: CGSize = if !isTop {
            .zero
        } else if let leaving, leaving.id == candidate.id {
            CGSize(width: leaving.liked ? 600 : -600, height: 0)
        } else {
            drag
        }
        return CandidateCard(candidate: candidate, recipe: candidate.recipeId.flatMap(recipe))
            .overlay(alignment: .topLeading) {
                if isTop { stamp("LECKER", color: .sage, visible: offset.width > 20, angle: -12) }
            }
            .overlay(alignment: .topTrailing) {
                if isTop { stamp("NÖ", color: .tomato, visible: offset.width < -20, angle: 12) }
            }
            .scaleEffect(1 - CGFloat(depth) * 0.05)
            .offset(y: CGFloat(depth) * 14)
            .offset(offset)
            .rotationEffect(.degrees(Double(offset.width / 22)), anchor: .bottom)
            .allowsHitTesting(isTop)
            // simultan, damit die Seite vertikal weiter scrollt; die Karte folgt nur horizontalen Bewegungen
            .simultaneousGesture(dragGesture(for: candidate))
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(isTop ? .isSelected : [])
            .accessibilityHidden(!isTop)
            .accessibilityAction(named: "Lecker") { commit(candidate, liked: true) }
            .accessibilityAction(named: "Nein danke") { commit(candidate, liked: false) }
            .accessibilityAction(named: "Das nehmen wir") { onDecide(candidate) }
    }

    private func stamp(_ text: String, color: Color, visible: Bool, angle: Double) -> some View {
        Text(text)
            .font(.heading(30, relativeTo: .title))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .overlay { RoundedRectangle(cornerRadius: 10).strokeBorder(color, lineWidth: 3) }
            .rotationEffect(.degrees(angle))
            .padding(28)
            .opacity(visible ? 1 : 0)
            .animation(.easeOut(duration: 0.15), value: visible)
    }

    private func dragGesture(for candidate: SessionCandidate) -> some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) || drag != .zero else { return }
                drag = CGSize(width: value.translation.width, height: 0)
            }
            .onEnded { value in
                guard drag != .zero else { return }
                if abs(value.translation.width) > threshold || abs(value.predictedEndTranslation.width) > threshold * 2 {
                    commit(candidate, liked: value.translation.width > 0)
                } else {
                    withAnimation(.spring(duration: 0.35, bounce: 0.35)) { drag = .zero }
                }
            }
    }

    private func voteButton(liked: Bool) -> some View {
        Button {
            if let top = deck.first { commit(top, liked: liked) }
        } label: {
            Image(systemName: liked ? "heart.fill" : "xmark")
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(liked ? Color.sage : Color.tomato)
                .frame(width: 66, height: 66)
                .background(Color.surface, in: .circle)
                .overlay { Circle().strokeBorder(Color.hairline) }
                .shadow(color: .black.opacity(0.06), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .disabled(deck.isEmpty || leaving != nil)
        .accessibilityLabel(liked ? "Lecker" : "Nein danke")
    }

    private var decideButton: some View {
        Button {
            if let top = deck.first { onDecide(top) }
        } label: {
            Label("Das nehmen wir", systemImage: "checkmark")
                .font(.buttonSans)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
                .foregroundStyle(Color.canvas)
                .padding(.horizontal, 18)
                .frame(height: 54)
                .background(Color.ink, in: .capsule)
        }
        .buttonStyle(.plain)
        .disabled(deck.isEmpty || leaving != nil)
        .accessibilityHint("Legt das Gericht für euch fest, ohne auf ein Match zu warten")
    }

    private func commit(_ candidate: SessionCandidate, liked: Bool) {
        guard leaving == nil else { return }
        withAnimation(.easeIn(duration: 0.25)) { leaving = (candidate.id, liked) }
        Task {
            try? await Task.sleep(for: .milliseconds(250))
            onVote(candidate, liked)
            leaving = nil
            drag = .zero
        }
    }
}

/// Eine Vorschlagskarte – Rezept aus der Sammlung (mit Foto) oder Idee von nomi.
struct CandidateCard: View {
    let candidate: SessionCandidate
    let recipe: Recipe?
    var showsReason = true

    private var title: String { recipe?.title ?? candidate.aiRecipe?.title ?? "Vorschlag" }

    private var meta: String {
        let minutes = recipe?.totalMinutes ?? candidate.aiRecipe?.totalMinutes
        let tags = recipe?.tags ?? candidate.aiRecipe?.tags ?? []
        return ([minutes.map(Recipe.durationLabel)] + tags.prefix(2).map { Optional($0) })
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            image
                .frame(height: 230)
                .frame(maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: 18))
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 6) {
                        if let course = candidate.course {
                            Text(course.uppercased(with: Locale(identifier: "de_DE")))
                                .font(.custom("DMMono-Medium", size: 12, relativeTo: .caption))
                                .tracking(1.4)
                                .foregroundStyle(Color.onBrand)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.brand, in: .capsule)
                        }
                        Text(recipe != nil ? "AUS EURER SAMMLUNG" : "IDEE VON NOMI")
                            .font(.meta)
                            .tracking(1.2)
                            .foregroundStyle(Color.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(.ultraThinMaterial, in: .capsule)
                    }
                    .padding(12)
                }
            VStack(alignment: .leading, spacing: 8) {
                if !meta.isEmpty { MetaLabel(meta) }
                Text(title)
                    .font(.heading(26, relativeTo: .title2))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                if showsReason, let reason = candidate.reason, !reason.isEmpty {
                    Text(reason)
                        .font(.bodySans)
                        .foregroundStyle(Color.inkMuted)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 6)
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: 360)
        .background(Color.surface, in: .rect(cornerRadius: 26))
        .shadow(color: .black.opacity(0.10), radius: 20, y: 10)
        .padding(.horizontal, 4)
    }

    @ViewBuilder
    private var image: some View {
        if let recipe {
            RecipeImage(recipe: recipe)
        } else {
            IllustrationTile(motif: FoodMotif.matching(title: title) ?? .teller, scale: 0.55)
        }
    }
}
