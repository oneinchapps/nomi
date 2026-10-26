import SwiftUI

/// Zutaten aus einem oder mehreren Rezepten auswählen und auf die Einkaufsliste legen.
/// Gewürze & Öle sind vorab abgewählt – die hat man meist schon.
struct AddToListSheet: View {
    struct Source {
        let recipe: Recipe
        let servings: Int

        var ingredients: [Ingredient] { recipe.scaledIngredients(for: servings) }
    }

    let sources: [Source]

    @Environment(ShoppingStore.self) private var shopping
    @Environment(\.dismiss) private var dismiss
    @State private var selected: Set<String>
    @State private var isAdding = false

    init(sources: [Source]) {
        self.sources = sources
        var initial = Set<String>()
        for (sourceIndex, source) in sources.enumerated() {
            for (index, ingredient) in source.ingredients.enumerated()
            where (ingredient.aisle ?? Aisle.guess(for: ingredient.name)) != .gewuerzeOele {
                initial.insert(Self.key(sourceIndex, index))
            }
        }
        _selected = State(initialValue: initial)
    }

    /// Position statt Source.id: die Sheet-View wird bei jedem Neuzeichnen mit neuen Source-Werten
    /// (und damit neuen IDs) erzeugt, die Auswahl im @State bleibt aber bestehen.
    private static func key(_ sourceIndex: Int, _ index: Int) -> String { "\(sourceIndex)-\(index)" }

    private var hasDeselectedSpices: Bool {
        sources.enumerated().contains { sourceIndex, source in
            source.ingredients.enumerated().contains { index, ingredient in
                (ingredient.aisle ?? Aisle.guess(for: ingredient.name)) == .gewuerzeOele && !selected.contains(Self.key(sourceIndex, index))
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if hasDeselectedSpices {
                    Label("Gewürze & Öle sind abgewählt – die habt ihr meist schon.", systemImage: "info.circle")
                        .font(.captionSans)
                        .foregroundStyle(Color.ink)
                        .listRowBackground(Color.mist)
                }
                ForEach(Array(sources.enumerated()), id: \.offset) { sourceIndex, source in
                    Section {
                        ForEach(Array(source.ingredients.enumerated()), id: \.offset) { index, ingredient in
                            let key = Self.key(sourceIndex, index)
                            Button {
                                if selected.contains(key) { selected.remove(key) } else { selected.insert(key) }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: selected.contains(key) ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(selected.contains(key) ? Color.ink : Color.hairline)
                                    Text(ingredient.name).font(.bodySans)
                                    Spacer()
                                    Text(ingredient.amountText)
                                        .font(.bodySansMedium)
                                        .monospacedDigit()
                                }
                                .foregroundStyle(Color.ink)
                                .contentShape(.rect)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.surface)
                            .accessibilityValue(selected.contains(key) ? "ausgewählt" : "nicht ausgewählt")
                        }
                    } header: {
                        MetaLabel("\(source.recipe.title) · \(Recipe.servingsLabel(source.servings))")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Auf die Liste")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                LoadingButton(
                    title: selected.count == 1 ? "1 Zutat hinzufügen" : "\(selected.count) Zutaten hinzufügen",
                    isLoading: isAdding,
                    isEnabled: !selected.isEmpty,
                    action: add
                )
                .padding(.horizontal, Metrics.gutter)
                .padding(.bottom, 8)
                .background(Color.canvas)
            }
        }
    }

    private func add() {
        isAdding = true
        Task {
            for (sourceIndex, source) in sources.enumerated() {
                let chosen = source.ingredients.enumerated()
                    .filter { selected.contains(Self.key(sourceIndex, $0.offset)) }
                    .map(\.element)
                if !chosen.isEmpty {
                    await shopping.add(chosen, recipeId: source.recipe.id)
                }
            }
            isAdding = false
            dismiss()
        }
    }
}
