import SwiftUI

struct ShoppingListView: View {
    @Environment(ShoppingStore.self) private var shopping
    @Environment(RecipeStore.self) private var recipes
    @Environment(AppModel.self) private var app

    @State private var newItem = ""
    @State private var showsStaples = false
    @FocusState private var addFocused: Bool

    var body: some View {
        List {
            header
                .listRowSeparator(.hidden)
                .listRowBackground(Color.canvas)

            if shopping.hasLoaded && shopping.openItems.isEmpty {
                emptyState
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.canvas)
            }

            ForEach(shopping.openByAisle, id: \.aisle) { group in
                Section {
                    ForEach(group.items) { item in
                        row(item)
                    }
                } header: {
                    MetaLabel(group.aisle.title)
                }
            }

            if !shopping.checkedItems.isEmpty {
                Section {
                    ForEach(shopping.checkedItems) { item in
                        row(item)
                    }
                } header: {
                    HStack {
                        MetaLabel("Im Wagen · \(shopping.checkedItems.count)")
                        Spacer()
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
        .scrollContentBackground(.hidden)
        .background(Color.canvas.ignoresSafeArea())
        .animation(.smooth(duration: 0.3), value: shopping.items.map { "\($0.id)\($0.checked)" })
        .refreshable { await shopping.load() }
        .sheet(isPresented: $showsStaples) {
            StaplesSheet()
        }
    }

    // MARK: - Kopf

    private var header: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 10) {
                MetaLabel(shopping.openItems.isEmpty ? "Gemeinsame Liste" : "\(shopping.openItems.count) offen", font: .eyebrow, tracking: 2.4)
                DisplayHeadline(lines: ["Einkauf"])
            }

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

            staplesRow
        }
        .padding(.top, 8)
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
            Text("🧺")
                .font(.system(size: 44))
                .frame(width: 88, height: 88)
                .background(Color.mist, in: .circle)
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
    }

    private func checkedByPartner(_ item: ShoppingItem) -> HouseholdMember? {
        guard let id = item.checkedBy, id != app.userId else { return nil }
        return app.members.first { $0.userId == id }
    }

    private func addNewItem() {
        let line = newItem.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }
        newItem = ""
        addFocused = true
        Task { await shopping.addLine(line) }
    }
}

/// Standardartikel pflegen: Dinge, die regelmäßig gebraucht werden.
struct StaplesSheet: View {
    @Environment(ShoppingStore.self) private var shopping
    @Environment(\.dismiss) private var dismiss
    @State private var newStaple = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
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
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .onAppear { focused = shopping.staples.isEmpty }
        }
        .presentationDetents([.medium, .large])
    }

    private func add() {
        let line = newStaple.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return }
        newStaple = ""
        Task { await shopping.addStaple(line) }
    }
}
