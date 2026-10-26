import SwiftUI

/// Rezepte: Startseite mit „Zuletzt gekocht“, „Neu“ und Kategorie-Kacheln; ein Tipp führt in die gefilterte Liste.
struct RecipesView: View {
    @Environment(RecipeStore.self) private var store
    @Environment(CookingLogStore.self) private var log
    @State private var query = ""
    @State private var filter: RecipeFilter?
    @State private var showsEditor = false
    @State private var showsImport = false
    @State private var showsPhotoImport = false

    enum Route: Hashable {
        case history
    }

    private var isSearching: Bool { !query.trimmingCharacters(in: .whitespaces).isEmpty }

    private var searchResults: [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return store.recipes.filter { recipe in
            recipe.title.lowercased().contains(q)
                || recipe.tags.contains { $0.lowercased().contains(q) }
                || recipe.ingredients.contains { $0.name.lowercased().contains(q) }
        }
    }

    private func recipes(for filter: RecipeFilter) -> [Recipe] {
        let matching = store.recipes.filter { filter.matches($0, lastCooked: log.lastCooked($0.id)) }
        guard filter == .longNotCooked else { return matching }
        // Noch nie gekocht zuerst, dann am längsten her
        return matching.sorted { (log.lastCooked($0.id) ?? .distantPast) < (log.lastCooked($1.id) ?? .distantPast) }
    }

    /// Kategorien mit mindestens einem Rezept
    private var availableCategories: [RecipeFilter] {
        RecipeFilter.categories.filter { !recipes(for: $0).isEmpty }
    }

    private let columns = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]

    var body: some View {
        ScrollView {
            BrandHeader {
                MetaLabel(countLabel, font: .eyebrow, tracking: 2.4)
                DisplayHeadline(lines: [filter.map(\.title) ?? "Rezepte"])
            }
            VStack(alignment: .leading, spacing: 28) {
                if !store.hasLoaded {
                    ProgressView().frame(maxWidth: .infinity).padding(.top, 60)
                } else if store.recipes.isEmpty {
                    emptyState
                } else if isSearching {
                    grid(searchResults, empty: "Nichts gefunden für „\(query)“.")
                } else if let filter {
                    filterChips(selected: filter)
                    grid(recipes(for: filter), empty: "Hier ist gerade nichts.", showsLastCooked: filter == .longNotCooked)
                } else {
                    landing
                }

                InlineError(message: store.loadError)
            }
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color.canvas.ignoresSafeArea())
        .animation(.smooth(duration: 0.25), value: filter)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Rezept oder Zutat")
        .refreshable {
            await store.load()
            await log.load()
        }
        .navigationDestination(for: UUID.self) { id in
            RecipeDetailView(recipeId: id)
        }
        .navigationDestination(for: Route.self) { _ in
            CookingHistoryView()
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Aus Link importieren", systemImage: "link") { showsImport = true }
                    Button("Aus Foto importieren", systemImage: "camera") { showsPhotoImport = true }
                    Button("Von Hand anlegen", systemImage: "square.and.pencil") { showsEditor = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Color.onBrand)
                        .frame(width: 36, height: 36)
                        .background(Color.onBrand.opacity(0.18), in: .circle)
                }
                .accessibilityLabel("Rezept hinzufügen")
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .sheet(isPresented: $showsEditor) {
            RecipeEditorView(recipe: nil)
        }
        .sheet(isPresented: $showsImport) {
            ImportLinkView()
        }
        .sheet(isPresented: $showsPhotoImport) {
            ImportPhotoView()
        }
    }

    private var countLabel: String {
        let count = filter.map { recipes(for: $0).count } ?? store.recipes.count
        switch count {
        case 0: return "Eure Sammlung"
        case 1: return "1 Rezept"
        default: return "\(count) Rezepte"
        }
    }

    // MARK: - Startseite

    private var landing: some View {
        VStack(alignment: .leading, spacing: 28) {
            let recent = log.recentRecipeIds.prefix(10).compactMap { store.recipe(id: $0) }
            if !recent.isEmpty {
                section("Zuletzt gekocht") {
                    NavigationLink(value: Route.history) {
                        Text("Verlauf")
                            .font(.captionSans)
                            .foregroundStyle(Color.ink)
                            .underline()
                    }
                } content: {
                    carousel(recent) { recipe in
                        log.lastCooked(recipe.id).map { CookingHistory.relative($0) }
                    }
                }
            }

            section("Neu in eurer Sammlung") {
                EmptyView()
            } content: {
                carousel(Array(store.recipes.prefix(10))) { $0.metaLine }
            }

            if !availableCategories.isEmpty {
                section("Kategorien") {
                    EmptyView()
                } content: {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(availableCategories) { category in
                            let matching = recipes(for: category)
                            Button {
                                filter = category
                            } label: {
                                CategoryTile(filter: category, count: matching.count, cover: matching.first { $0.imageURL != nil } ?? matching.first)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                }
            }

            VStack(spacing: 0) {
                quickLink(.quick)
                quickLink(.longNotCooked)
                quickLink(.all)
            }
            .background(Color.surface, in: .rect(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.hairline) }
            .padding(.horizontal, Metrics.gutter)
        }
    }

    private func section<Trailing: View, Content: View>(
        _ title: String,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                MetaLabel(title)
                Spacer()
                trailing()
            }
            .padding(.horizontal, Metrics.gutter)
            content()
        }
    }

    private func carousel(_ recipes: [Recipe], caption: @escaping (Recipe) -> String?) -> some View {
        ScrollView(.horizontal) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(recipes) { recipe in
                    NavigationLink(value: recipe.id) {
                        SmallRecipeCard(recipe: recipe, caption: caption(recipe))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .scrollIndicators(.hidden)
    }

    private func quickLink(_ target: RecipeFilter) -> some View {
        Button {
            filter = target
        } label: {
            HStack(spacing: 12) {
                Text(target.emoji).font(.system(size: 22))
                Text(target.title).font(.bodySansMedium).foregroundStyle(Color.ink)
                Spacer()
                Text("\(recipes(for: target).count)")
                    .font(.bodySans)
                    .monospacedDigit()
                    .foregroundStyle(Color.inkMuted)
                Image(systemName: "chevron.right").foregroundStyle(Color.inkMuted)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if target != .all { Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 50) }
        }
    }

    // MARK: - Gefilterte Ansicht

    private func filterChips(selected: RecipeFilter) -> some View {
        // „Übersicht“ steht fest links – die Chips daneben scrollen zur gewählten Kategorie
        HStack(spacing: 0) {
            Button {
                filter = nil
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 34, height: 34)
                    .overlay { Circle().strokeBorder(Color.hairline) }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Übersicht")
            .padding(.leading, Metrics.gutter)
            .padding(.trailing, 8)
            chipScroller(selected: selected)
        }
    }

    private func chipScroller(selected: RecipeFilter) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach([RecipeFilter.all] + availableCategories + [.quick, .longNotCooked]) { chip in
                        let isSelected = chip == selected
                        Button {
                            filter = chip
                        } label: {
                            Text("\(chip.emoji) \(chip.title)")
                                .font(.captionSans)
                                .foregroundStyle(isSelected ? Color.onBrand : Color.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(isSelected ? Color.brand : Color.mist, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .id(chip)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
                .padding(.trailing, Metrics.gutter)
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(selected, anchor: .center) }
        }
    }

    @ViewBuilder
    private func grid(_ recipes: [Recipe], empty: String, showsLastCooked: Bool = false) -> some View {
        if recipes.isEmpty {
            Text(empty)
                .font(.bodySans)
                .foregroundStyle(Color.inkMuted)
                .padding(.horizontal, Metrics.gutter)
        } else {
            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(recipes) { recipe in
                    NavigationLink(value: recipe.id) {
                        RecipeTile(
                            recipe: recipe,
                            caption: showsLastCooked ? (log.lastCooked(recipe.id).map { "Zuletzt \(CookingHistory.relative($0))" } ?? "Noch nie gekocht") : nil
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metrics.gutter)
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
            Text("Teilt Rezepte aus Instagram, TikTok oder Blogs direkt an nomnom, fotografiert Kochbuch oder Omas Karteikarte – oder legt euer Lieblingsrezept von Hand an.")
                .font(.bodySans)
                .foregroundStyle(Color.inkMuted)
                .lineSpacing(3)
            Button("Rezept aus Link") { showsImport = true }
                .buttonStyle(.primary)
                .padding(.top, 8)
            Button("Rezept vom Foto", systemImage: "camera") { showsPhotoImport = true }
                .buttonStyle(.secondary)
            Button("Erstes Rezept anlegen") { showsEditor = true }
                .font(.bodySansMedium)
                .foregroundStyle(Color.ink)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 12)
    }
}

/// Kompakte Karte fürs Raster.
struct RecipeTile: View {
    let recipe: Recipe
    /// Ersetzt die Metazeile, z. B. „Zuletzt vor 3 Monaten“
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            RecipeImage(recipe: recipe, emojiSize: 48)
                .aspectRatio(1, contentMode: .fit)
                .clipShape(.rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 4) {
                MetaLabel(caption ?? recipe.metaLine)
                    .lineLimit(1)
                Text(recipe.title)
                    .font(.heading(19, relativeTo: .headline))
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

/// Kleine Karte für die Karussells der Startseite.
struct SmallRecipeCard: View {
    let recipe: Recipe
    var caption: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RecipeImage(recipe: recipe, emojiSize: 40)
                .frame(width: 148, height: 148)
                .clipShape(.rect(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 3) {
                if let caption { MetaLabel(caption).lineLimit(1) }
                Text(recipe.title)
                    .font(.heading(16, relativeTo: .subheadline))
                    .foregroundStyle(Color.ink)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, 2)
        }
        .frame(width: 148)
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}

/// Kachel einer Kategorie: Foto eines passenden Rezepts, darüber Emoji, Name und Anzahl.
struct CategoryTile: View {
    let filter: RecipeFilter
    let count: Int
    let cover: Recipe?

    var body: some View {
        Color.clear
            .aspectRatio(4 / 3, contentMode: .fit)
            .overlay {
                // Nur echte Fotos – sonst stünden Platzhalter-Emoji und Kategorie-Emoji übereinander
                if let cover, cover.imageURL != nil {
                    RecipeImage(recipe: cover, emojiSize: 36)
                } else {
                    Rectangle().fill((cover?.tint ?? .mist).gradient)
                }
            }
            .overlay {
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .center, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(filter.emoji).font(.system(size: 22))
                    Text(filter.title)
                        .font(.heading(19, relativeTo: .headline))
                        .foregroundStyle(.white)
                    Text(count == 1 ? "1 Rezept" : "\(count) Rezepte")
                        .font(.meta)
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(12)
            }
            .clipShape(.rect(cornerRadius: 20))
            .contentShape(.rect)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(filter.title), \(count == 1 ? "1 Rezept" : "\(count) Rezepte")")
            .accessibilityAddTraits(.isButton)
    }
}
