import SwiftUI

struct RecipesView: View {
    @Environment(RecipeStore.self) private var store
    @State private var query = ""
    @State private var showsEditor = false
    @State private var showsImport = false

    private var filtered: [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return store.recipes }
        return store.recipes.filter { recipe in
            recipe.title.lowercased().contains(q)
                || recipe.tags.contains { $0.lowercased().contains(q) }
                || recipe.ingredients.contains { $0.name.lowercased().contains(q) }
        }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 10) {
                    MetaLabel(countLabel, font: .eyebrow, tracking: 2.4)
                    DisplayHeadline(lines: ["Rezepte"])
                }

                if !store.hasLoaded {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                } else if store.recipes.isEmpty {
                    emptyState
                } else if filtered.isEmpty {
                    Text("Nichts gefunden für „\(query)“.")
                        .font(.bodySans)
                        .foregroundStyle(Color.inkMuted)
                } else {
                    LazyVGrid(columns: columns, spacing: 18) {
                        ForEach(filtered) { recipe in
                            NavigationLink(value: recipe.id) {
                                RecipeTile(recipe: recipe)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let error = store.loadError {
                    InlineError(message: error)
                }
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 16)
            .padding(.bottom, 32)
        }
        .background(Color.canvas.ignoresSafeArea())
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Rezept oder Zutat")
        .refreshable { await store.load() }
        .navigationDestination(for: UUID.self) { id in
            RecipeDetailView(recipeId: id)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Aus Link importieren", systemImage: "link") { showsImport = true }
                    Button("Von Hand anlegen", systemImage: "square.and.pencil") { showsEditor = true }
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Rezept hinzufügen")
            }
        }
        .sheet(isPresented: $showsEditor) {
            RecipeEditorView(recipe: nil)
        }
        .sheet(isPresented: $showsImport) {
            ImportLinkView()
        }
    }

    private var countLabel: String {
        switch store.recipes.count {
        case 0: "Eure Sammlung"
        case 1: "1 Rezept"
        default: "\(store.recipes.count) Rezepte"
        }
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: -18) {
                ForEach(Array(Recipe.samples.prefix(3).enumerated()), id: \.offset) { index, sample in
                    Text(sample.emoji)
                        .font(.system(size: 34))
                        .frame(width: 64, height: 64)
                        .background(sample.tint, in: .circle)
                        .overlay { Circle().strokeBorder(Color.canvas, lineWidth: 3) }
                        .rotationEffect(.degrees(Double(index - 1) * 8))
                }
            }
            Text("Noch keine Rezepte")
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            Text("Teilt Rezepte aus Instagram, TikTok oder Blogs direkt an nomnom – oder legt euer Lieblingsrezept von Hand an.")
                .font(.bodySans)
                .foregroundStyle(Color.inkMuted)
                .lineSpacing(3)
            Button("Rezept aus Link") { showsImport = true }
                .buttonStyle(.primary)
                .padding(.top, 8)
            Button("Erstes Rezept anlegen") { showsEditor = true }
                .font(.bodySansMedium)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity)
        }
        .padding(.top, 12)
    }
}

/// Kompakte Karte fürs Raster.
struct RecipeTile: View {
    let recipe: Recipe

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RecipeImage(recipe: recipe, emojiSize: 48)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                MetaLabel(recipe.metaLine)
                    .lineLimit(1)
                Text(recipe.title)
                    .font(.custom("Fraunces144pt-Bold", size: 19, relativeTo: .headline))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 2)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
