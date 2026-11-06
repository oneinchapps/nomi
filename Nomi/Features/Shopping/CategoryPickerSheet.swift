import SwiftUI

/// „In welche Abteilung?“ – alle Kategorien als Chips. Die aktuelle hat einen Haken, nomis Vorschlag
/// (Stichwort-Raten) ist dunkel. Gleiches Blatt in der Liste, im Live-Einkauf und bei den Zuordnungen.
struct CategoryPickerSheet: View {
    let itemName: String
    /// nil, wenn der Artikel noch nirgends liegt (neue Zuordnung)
    let current: CategoryKey?
    let categories: [ShoppingCategory]
    let choose: (CategoryKey) -> Void

    @Environment(\.dismiss) private var dismiss

    private var suggested: CategoryKey? {
        let guess = Aisle.guess(for: itemName)
        guard guess != .sonstiges, current != .aisle(guess) else { return nil }
        return .aisle(guess)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                MetaLabel(itemName)
                Text("In welche Abteilung?")
                    .font(.heading(26, relativeTo: .title2))
                    .foregroundStyle(Color.ink)
                FlowLayout(spacing: 8) {
                    ForEach(categories) { category in
                        chip(category)
                    }
                }
                Label("nomi merkt sich das für den nächsten Einkauf.", systemImage: "sparkles")
                    .font(.captionSans)
                    .foregroundStyle(Color.inkMuted)
                    .padding(.top, 4)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 28)
            .padding(.bottom, 16)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(Color.canvas)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(Color.canvas)
    }

    private func chip(_ category: ShoppingCategory) -> some View {
        let isCurrent = category.key == current
        let isSuggested = category.key == suggested
        return Button {
            if !isCurrent { choose(category.key) }
            dismiss()
        } label: {
            HStack(spacing: 5) {
                if isCurrent {
                    Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                }
                Text(category.name)
            }
            .font(.custom(isCurrent || isSuggested ? "DMSans-SemiBold" : "DMSans-Regular", size: 15, relativeTo: .subheadline))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .foregroundStyle(isSuggested ? Color.canvas : Color.ink)
            .background(isSuggested ? Color.ink : (isCurrent ? Color.surface : Color.hairline.opacity(0.7)), in: .capsule)
            .overlay { Capsule().strokeBorder(isCurrent ? Color.ink.opacity(0.4) : .clear, lineWidth: 1.5) }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(isCurrent ? .isSelected : [])
        .accessibilityHint(isSuggested ? "Vorschlag von nomi" : "")
    }
}
