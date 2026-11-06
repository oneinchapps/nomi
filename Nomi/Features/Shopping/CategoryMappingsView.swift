import SwiftUI

/// Alle gemerkten Zuordnungen „Artikel → Kategorie“: ändern, vergessen oder vorab anlegen.
struct CategoryMappingsView: View {
    @Environment(ShoppingStore.self) private var shopping
    @Environment(RecipeStore.self) private var recipes

    @State private var query = ""
    @State private var editing: Choice?
    @State private var naming: NameEntry?

    /// Wofür gerade das Kategorien-Blatt offen ist
    private struct Choice: Identifiable {
        let id = UUID()
        let name: String
        let current: CategoryKey?
    }

    private var groups: [(category: ShoppingCategory, mappings: [CategoryMappings.Mapping])] {
        CategoryMappings.grouped(
            Array(shopping.aislePreferences.values),
            order: shopping.categoryOrder,
            knownNames: shopping.knownNames(recipes: recipes.recipes),
            query: query
        )
    }

    var body: some View {
        List {
            if shopping.aislePreferences.isEmpty {
                Section {
                    Text("Noch nichts gemerkt. Liegt ein Artikel in der falschen Kategorie, zieh ihn in der Liste in die richtige oder halte ihn beim Einkaufen gedrückt – nomi merkt es sich dann hier.")
                        .font(.bodySans)
                        .foregroundStyle(Color.inkMuted)
                        .listRowBackground(Color.surface)
                }
            }
            ForEach(groups, id: \.category.key) { group in
                Section {
                    ForEach(group.mappings) { mapping in
                        Button {
                            editing = Choice(name: mapping.name, current: mapping.key)
                        } label: {
                            HStack {
                                Text(mapping.name)
                                    .font(.bodySans)
                                    .foregroundStyle(Color.ink)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.hairline)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.surface)
                        .accessibilityIdentifier("mapping-\(mapping.name)")
                        .swipeActions {
                            Button("Vergessen", role: .destructive) {
                                Task { await shopping.forget(nameKey: mapping.nameKey) }
                            }
                        }
                    }
                } header: {
                    MetaLabel(group.category.name)
                }
            }
            Section {
                Button {
                    naming = NameEntry(title: "Welcher Artikel?", placeholder: "z. B. Vesper Käse") { name in
                        editing = Choice(name: name, current: nil)
                    }
                } label: {
                    Label("Zuordnung hinzufügen", systemImage: "plus")
                        .font(.bodySans)
                        .foregroundStyle(Color.brand)
                }
                .listRowBackground(Color.surface)
                .accessibilityIdentifier("mapping-add")
            } footer: {
                Text("Tippen ändert die Kategorie, nach links wischen vergisst die Zuordnung. Einträge auf der Liste wandern gleich mit.")
                    .font(.captionSans)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas.ignoresSafeArea())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Artikel suchen")
        .navigationTitle("Zuordnungen")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { choice in
            CategoryPickerSheet(itemName: choice.name, current: choice.current, categories: shopping.categoryOrder) { key in
                Task { await shopping.assign(name: choice.name, to: key) }
            }
        }
        .nameAlert($naming)
    }
}
