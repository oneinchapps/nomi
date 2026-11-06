import SwiftUI

struct ShoppingListView: View {
    @Environment(ShoppingStore.self) private var shopping
    @Environment(RecipeStore.self) private var recipes
    @Environment(AppModel.self) private var app

    @State private var newItem = ""
    @State private var showsStaples = false
    @State private var showsSettings = false
    @State private var showsLive = false
    /// „Erledigt“ ist beim Öffnen zugeklappt
    @State private var showsCart = false
    /// Zählt Verschiebungen, nur für das haptische Feedback
    @State private var moves = 0
    /// Eintrag, für den gerade die Abteilung gewählt wird
    @State private var aisleChoice: ShoppingItem?
    @FocusState private var addFocused: Bool

    var body: some View {
        List {
            BrandHeader(bottomPadding: 22) {
                HStack(spacing: 12) {
                    DisplayHeadline(lines: ["Einkauf"])
                    if !shopping.openItems.isEmpty {
                        CountBadge(count: shopping.openItems.count, accessibilityLabel: "\(shopping.openItems.count) offen")
                    }
                }
            }
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)

            header
                .listRowSeparator(.hidden)
                .listRowBackground(Color.canvas)

            if shopping.hasLoaded && shopping.openItems.isEmpty {
                emptyState
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.canvas)
            }

            // Eine durchgehende Liste aus Überschriften und Einträgen: So lassen sich Einträge
            // halten und in eine andere Abteilung ziehen (onMove geht nur innerhalb eines ForEach).
            ForEach(openRows) { entry in
                switch entry {
                case .header(let category):
                    MetaLabel(category.name)
                        .padding(.top, 14)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 2, trailing: 20))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.canvas)
                        .moveDisabled(true)
                case .item(let item):
                    row(item)
                }
            }
            .onMove(perform: moveRows)

            if !shopping.checkedItems.isEmpty {
                Section {
                    // Standardmäßig zugeklappt: Erledigtes soll die offene Liste nicht verlängern
                    if showsCart {
                        ForEach(shopping.checkedItems) { item in
                            row(item)
                        }
                    }
                } header: {
                    HStack {
                        Button {
                            withAnimation(.smooth(duration: 0.25)) { showsCart.toggle() }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(Color.inkMuted)
                                    .rotationEffect(.degrees(showsCart ? 90 : 0))
                                MetaLabel("Erledigt · \(shopping.checkedItems.count)")
                                Spacer(minLength: 8)
                            }
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("cart-toggle")
                        .accessibilityValue(showsCart ? "aufgeklappt" : "zugeklappt")
                        Button("Leeren") {
                            Task { await shopping.clearChecked() }
                        }
                        .font(.captionSans)
                        .foregroundStyle(Color.ink)
                    }
                }
            }

            if let error = shopping.error {
                InlineError(message: error)
                    .listRowBackground(Color.canvas)
            }
        }
        .listStyle(.plain)
        // Luft unter dem Ende der Liste, sonst klebt „Erledigt“ an der Tab-Leiste
        .contentMargins(.bottom, 48, for: .scrollContent)
        .scrollContentBackground(.hidden)
        .background(Color.canvas.ignoresSafeArea())
        .animation(.smooth(duration: 0.3), value: shopping.items.map { "\($0.id)\($0.checked)\($0.categoryKey.raw)" } + shopping.categoryOrder.map(\.name))
        .sensoryFeedback(.success, trigger: moves)
        .sheet(item: $aisleChoice) { item in
            CategoryPickerSheet(itemName: item.name, current: item.categoryKey, categories: shopping.categoryOrder) { key in
                move(item, to: key)
            }
        }
        .refreshable { await shopping.load() }
        .sheet(isPresented: $showsStaples) {
            StaplesSheet()
        }
        .sheet(isPresented: $showsSettings) {
            ShoppingSettingsSheet()
        }
        .fullScreenCover(isPresented: $showsLive) {
            LiveShoppingView()
        }
        .mainToolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showsSettings = true
                } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.onBrand)
                        .frame(width: 36, height: 36)
                        .background(Color.onBrand.opacity(0.18), in: .circle)
                }
                .accessibilityLabel("Einstellungen fürs Einkaufen")
            }
            .sharedBackgroundVisibility(.hidden)
        }
    }

    // MARK: - Kopf

    /// Eingabe und Kurzwahl unter dem Markenkopf.
    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                TextField("Was fehlt? z. B. 2 l Milch", text: $newItem)
                    .submitLabel(.done)
                    .focused($addFocused)
                    .onSubmit(addNewItem)
                    .fieldBackground(isFocused: addFocused)
                Button(action: addNewItem) {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.canvas)
                        .frame(width: 52, height: 52)
                        .background(Color.ink, in: .circle)
                }
                .buttonStyle(.plain)
                .disabled(newItem.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Auf die Liste")
            }

            // Im Laden: Vollbild nur zum Abhaken. Beim Tippen weg, dann zählen die Vorschläge.
            if !shopping.openItems.isEmpty && !addFocused {
                Button {
                    showsLive = true
                } label: {
                    Label("Einkaufen starten", systemImage: "cart.fill")
                }
                .buttonStyle(.primary)
                .accessibilityIdentifier("live-start")
            }

            // Beim Tippen stehen hier Vorschläge statt der Standardartikel
            let suggestions = addFocused ? shopping.suggestions(for: newItem, recipes: recipes.recipes) : []
            if suggestions.isEmpty {
                staplesRow
            } else {
                suggestionsRow(suggestions)
            }

            if let store = shopping.activeStore {
                storePicker(store)
            }
        }
        .padding(.top, 8)
    }

    /// „Sortiert für Rewe ▾“ – wechselt den Supermarkt und damit die Reihenfolge der Kategorien
    private func storePicker(_ active: ShoppingStoreRecord) -> some View {
        Menu {
            ForEach(shopping.stores) { store in
                Button {
                    shopping.activeStoreId = store.id
                } label: {
                    if store.id == active.id {
                        Label(store.name, systemImage: "checkmark")
                    } else {
                        Text(store.name)
                    }
                }
            }
            Divider()
            Button("Supermärkte bearbeiten", systemImage: "gearshape") { showsSettings = true }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "storefront")
                    .font(.system(size: 12, weight: .semibold))
                Text("Sortiert für")
                    .foregroundStyle(Color.inkMuted)
                Text(active.name)
                    .font(.captionSans.weight(.semibold))
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.captionSans)
            .foregroundStyle(Color.ink)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .overlay { Capsule().strokeBorder(Color.hairline, lineWidth: 1.5) }
        }
        .accessibilityLabel("Sortiert für \(active.name)")
    }

    private func suggestionsRow(_ suggestions: [ShoppingSuggestion]) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(suggestions) { suggestion in
                    Button {
                        add(suggestion.line)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text(suggestion.line)
                        }
                        .font(.captionSans)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(Color.onBrand)
                        .background(Color.brand, in: .capsule)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Vorschlag: \(suggestion.line)")
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.never)
    }

    private var staplesRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(shopping.staples) { staple in
                    let onList = shopping.isOnList(staple)
                    Button {
                        Task { await shopping.addStapleToList(staple) }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: onList ? "checkmark" : "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text(staple.name)
                        }
                        .font(.captionSans)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(onList ? Color.inkMuted : Color.ink)
                        .background(onList ? Color.canvas : Color.mist, in: .capsule)
                        .overlay { Capsule().strokeBorder(onList ? Color.hairline : .clear) }
                    }
                    .buttonStyle(.plain)
                    .disabled(onList)
                    .accessibilityLabel(onList ? "\(staple.name), schon auf der Liste" : "\(staple.name) hinzufügen")
                }
                Button {
                    showsStaples = true
                } label: {
                    Label(shopping.staples.isEmpty ? "Standardartikel" : "Bearbeiten", systemImage: shopping.staples.isEmpty ? "plus" : "pencil")
                        .font(.captionSans)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .foregroundStyle(Color.ink)
                        .overlay { Capsule().strokeBorder(Color.hairline, style: StrokeStyle(lineWidth: 1, dash: [4, 3])) }
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            ReactionIllustration(reaction: .korb)
                .frame(width: 96, height: 96)
            Text("Alles da")
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            Text("Tippt oben ein, was fehlt, oder legt Zutaten aus einem Rezept auf die Liste.")
                .font(.bodySans)
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Zeile

    private func row(_ item: ShoppingItem) -> some View {
        Button {
            Task { await shopping.toggle(item) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: item.checked ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(item.checked ? Color.sage : Color.hairline)
                    .contentTransition(.symbolEffect(.replace))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.bodySans)
                        .strikethrough(item.checked, color: .inkMuted)
                        .foregroundStyle(item.checked ? Color.inkMuted : Color.ink)
                    if !item.checked, let title = item.recipeId.flatMap({ recipes.recipe(id: $0)?.title }) {
                        Text("für \(title)")
                            .font(.captionSans)
                            .foregroundStyle(Color.inkMuted)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                Text(item.amountText)
                    .font(.bodySansMedium)
                    .monospacedDigit()
                    .foregroundStyle(item.checked ? Color.inkMuted : Color.ink)
                if item.checked, let by = checkedByPartner(item) {
                    Text(by.initials)
                        .font(.custom("DMSans-SemiBold", size: 11, relativeTo: .caption2))
                        .foregroundStyle(Color.ink)
                        .frame(width: 22, height: 22)
                        .background(Color.mist, in: .circle)
                        .accessibilityLabel("abgehakt von \(by.displayName)")
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.canvas)
        .listRowSeparatorTint(Color.hairline)
        .accessibilityIdentifier("item-\(item.name)")
        .accessibilityValue(item.checked ? "erledigt" : "offen")
        .swipeActions {
            Button("Löschen", role: .destructive) {
                Task { await shopping.delete(item) }
            }
        }
        .swipeActions(edge: .leading) {
            // Erreicht auch Abteilungen, die gerade leer und deshalb nicht zu sehen sind.
            // Kein Halte-Menü: Halten ist zum Ziehen da.
            if !item.checked {
                Button("Abteilung") { aisleChoice = item }
                    .tint(Color.ink)
            }
        }
    }

    // MARK: - Abteilung wechseln

    private enum OpenRow: Identifiable {
        case header(ShoppingCategory)
        case item(ShoppingItem)

        var id: String {
            switch self {
            case .header(let category): "header-\(category.key.raw)"
            case .item(let item): item.id.uuidString
            }
        }
    }

    private var openRows: [OpenRow] {
        shopping.openByCategory.flatMap { group in [OpenRow.header(group.category)] + group.items.map(OpenRow.item) }
    }

    private func moveRows(from sources: IndexSet, to destination: Int) {
        let rows = openRows
        var headers: [Int: CategoryKey] = [:]
        for (index, row) in rows.enumerated() {
            if case .header(let category) = row { headers[index] = category.key }
        }
        for source in sources {
            guard case .item(let item) = rows[source],
                  let target = CategoryMove.target(movingFrom: source, to: destination, headers: headers) else { continue }
            move(item, to: target)
        }
    }

    private func move(_ item: ShoppingItem, to target: CategoryKey) {
        guard item.categoryKey != target else { return }
        moves += 1
        Task { await shopping.move(item, to: target) }
    }

    private func checkedByPartner(_ item: ShoppingItem) -> HouseholdMember? {
        guard let id = item.checkedBy, id != app.userId else { return nil }
        return app.members.first { $0.userId == id }
    }

    private func addNewItem() {
        add(newItem)
    }

    private func add(_ text: String) {
        let line = text.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }
        newItem = ""
        addFocused = true
        Task { await shopping.addLine(line) }
    }
}

/// Standardartikel pflegen: Dinge, die regelmäßig gebraucht werden.
struct StaplesSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            StaplesList()
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Fertig") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

/// Liste der Standardartikel – im eigenen Blatt und in den Einstellungen.
struct StaplesList: View {
    @Environment(ShoppingStore.self) private var shopping
    @State private var newStaple = ""
    @FocusState private var focused: Bool

    var body: some View {
        List {
            Section {
                HStack(spacing: 10) {
                    TextField("z. B. 1 l Hafermilch", text: $newStaple)
                        .focused($focused)
                        .submitLabel(.done)
                        .onSubmit(add)
                    Button("Hinzufügen", action: add)
                        .font(.bodySansMedium)
                        .disabled(newStaple.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                .listRowBackground(Color.surface)
            } footer: {
                Text("Standardartikel erscheinen als Kurzwahl über der Einkaufsliste – ein Tipp, und sie stehen drauf.")
                    .font(.captionSans)
            }

            if !shopping.staples.isEmpty {
                Section {
                    ForEach(shopping.staples) { staple in
                        HStack {
                            Text(staple.name).font(.bodySans)
                            Spacer()
                            Text(QuantityFormatter.amount(staple.quantity, unit: staple.unit))
                                .font(.bodySansMedium)
                                .foregroundStyle(Color.inkMuted)
                        }
                        .listRowBackground(Color.surface)
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { shopping.staples[$0] }
                        Task { for staple in toDelete { await shopping.deleteStaple(staple) } }
                    }
                } header: {
                    MetaLabel("Eure Standardartikel")
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("Standardartikel")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { focused = shopping.staples.isEmpty }
    }

    private func add() {
        let line = newStaple.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }
        newStaple = ""
        Task { await shopping.addStaple(line) }
    }
}
