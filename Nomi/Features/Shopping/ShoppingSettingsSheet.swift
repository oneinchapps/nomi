import SwiftUI

/// Einstellungen fürs Einkaufen (Zahnrad im Einkauf): Supermärkte mit eigener Reihenfolge,
/// Kategorien und Standardartikel.
struct ShoppingSettingsSheet: View {
    @Environment(ShoppingStore.self) private var shopping
    @Environment(\.dismiss) private var dismiss

    private enum Route: Hashable {
        case store(UUID)
        case categories
        case staples
    }

    @State private var path: [Route] = []
    @State private var naming: NameEntry?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    ForEach(shopping.stores) { store in
                        NavigationLink(value: Route.store(store.id)) {
                            HStack(spacing: 12) {
                                Image(systemName: "storefront")
                                    .foregroundStyle(Color.ink)
                                    .frame(width: 24)
                                Text(store.name)
                                    .font(.bodySans)
                                Spacer()
                                if store.id == shopping.activeStore?.id {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(Color.brand)
                                    Text("aktiv")
                                        .font(.captionSans)
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                        }
                        .listRowBackground(Color.surface)
                    }
                    .onDelete { offsets in
                        let toDelete = offsets.map { shopping.stores[$0] }
                        Task { for store in toDelete { await shopping.deleteStore(store) } }
                    }

                    Button {
                        naming = NameEntry(title: "Neuer Supermarkt", placeholder: "z. B. Rewe") { name in
                            Task { await shopping.addStore(named: name) }
                        }
                    } label: {
                        Label("Supermarkt hinzufügen", systemImage: "plus")
                            .font(.bodySans)
                            .foregroundStyle(Color.brand)
                    }
                    .listRowBackground(Color.surface)
                } header: {
                    MetaLabel("Supermärkte")
                } footer: {
                    Text(shopping.stores.isEmpty
                         ? "Legt eure Supermärkte an und sortiert die Kategorien so, wie ihr durch den Laden lauft."
                         : "Jeder Supermarkt hat seine eigene Reihenfolge. Wo du gerade bist, wählst du über der Liste – das gilt nur auf deinem iPhone.")
                        .font(.captionSans)
                }

                Section {
                    NavigationLink(value: Route.categories) {
                        row(icon: "square.grid.2x2", title: "Kategorien bearbeiten", detail: "\(shopping.categories.categories.count)")
                    }
                    .listRowBackground(Color.surface)
                    NavigationLink(value: Route.staples) {
                        row(icon: "pin", title: "Standardartikel", detail: "\(shopping.staples.count)")
                    }
                    .listRowBackground(Color.surface)
                } header: {
                    MetaLabel("Kategorien")
                } footer: {
                    Text("Namen und eigene Kategorien gelten für alle Supermärkte.")
                        .font(.captionSans)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Einkaufen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") { dismiss() }
                }
            }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .store(let id): StoreOrderView(storeId: id)
                case .categories: CategoriesView()
                case .staples: StaplesList()
                }
            }
            .nameAlert($naming)
        }
    }

    private func row(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(Color.ink)
                .frame(width: 24)
            Text(title)
                .font(.bodySans)
            Spacer()
            Text(detail)
                .font(.captionSans)
                .foregroundStyle(Color.inkMuted)
        }
    }
}

// MARK: - Reihenfolge eines Supermarkts

/// Kategorien eines Supermarkts in Laufreihenfolge, per Halten und Ziehen sortierbar.
struct StoreOrderView: View {
    let storeId: UUID
    @Environment(ShoppingStore.self) private var shopping
    @Environment(\.dismiss) private var dismiss
    @State private var order: [ShoppingCategory] = []
    @State private var naming: NameEntry?
    @State private var confirmsDelete = false

    private var store: ShoppingStoreRecord? { shopping.stores.first { $0.id == storeId } }

    var body: some View {
        List {
            Section {
                ForEach(Array(order.enumerated()), id: \.element.id) { index, category in
                    HStack(spacing: 12) {
                        Text("\(index + 1)")
                            .font(.meta)
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 22, alignment: .trailing)
                        Text(category.name)
                            .font(.bodySans)
                        if category.isCustom {
                            MetaLabel("eigene")
                        }
                    }
                    .listRowBackground(Color.surface)
                    .accessibilityIdentifier("order-\(category.name)")
                }
                .onMove { from, to in
                    order.move(fromOffsets: from, toOffset: to)
                    guard let store else { return }
                    Task { await shopping.reorder(store, to: order.map(\.key)) }
                }
            } header: {
                Text("So, wie ihr durch den Laden lauft. Zum Verschieben am Griff halten und ziehen.")
                    .font(.captionSans)
                    .foregroundStyle(Color.inkMuted)
                    .textCase(nil)
            }
        }
        // Griffe immer zeigen: Diese Liste ist nur zum Sortieren da
        .environment(\.editMode, .constant(.active))
        .scrollContentBackground(.hidden)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle(store?.name ?? "Supermarkt")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if shopping.activeStore?.id != storeId {
                        Button("Hier kaufe ich gerade ein", systemImage: "checkmark") { shopping.activeStoreId = storeId }
                    }
                    Button("Umbenennen", systemImage: "pencil") {
                        guard let store else { return }
                        naming = NameEntry(title: "Supermarkt umbenennen", placeholder: "Name", text: store.name) { name in
                            Task { await shopping.renameStore(store, to: name) }
                        }
                    }
                    Button("Supermarkt löschen", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .accessibilityLabel("Mehr")
            }
        }
        .confirmationDialog("\(store?.name ?? "Supermarkt") löschen?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Löschen", role: .destructive) {
                guard let store else { return }
                dismiss()
                Task { await shopping.deleteStore(store) }
            }
        } message: {
            Text("Die Reihenfolge geht verloren. Eure Liste und Kategorien bleiben.")
        }
        .nameAlert($naming)
        // Änderungen der anderen Person übernehmen, solange hier nicht gezogen wird
        .task(id: shopping.categories.ordered(for: store).map(\.key.raw) + shopping.categories.categories.map(\.name)) {
            order = shopping.categories.ordered(for: store)
        }
    }
}

// MARK: - Kategorien

/// Kategorien umbenennen, eigene anlegen und löschen.
struct CategoriesView: View {
    @Environment(ShoppingStore.self) private var shopping
    @State private var naming: NameEntry?

    var body: some View {
        List {
            Section {
                ForEach(shopping.categories.categories) { category in
                    Button {
                        rename(category)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.name)
                                    .font(.bodySans)
                                    .foregroundStyle(Color.ink)
                                if case .aisle(let aisle) = category.key, category.name != aisle.title {
                                    Text("statt „\(aisle.title)“")
                                        .font(.captionSans)
                                        .foregroundStyle(Color.inkMuted)
                                }
                            }
                            if category.isCustom {
                                MetaLabel("eigene")
                                    .foregroundStyle(Color.brand)
                            }
                            Spacer()
                            Image(systemName: "pencil")
                                .font(.system(size: 13))
                                .foregroundStyle(Color.inkMuted)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.surface)
                    .swipeActions {
                        if case .custom(let id) = category.key {
                            Button("Löschen", role: .destructive) {
                                Task { await shopping.deleteCategory(id) }
                            }
                        }
                    }
                }

                Button {
                    naming = NameEntry(title: "Neue Kategorie", placeholder: "z. B. Bio-Ecke") { name in
                        Task { await shopping.addCategory(named: name) }
                    }
                } label: {
                    Label("Kategorie hinzufügen", systemImage: "plus")
                        .font(.bodySans)
                        .foregroundStyle(Color.brand)
                }
                .listRowBackground(Color.surface)
            } footer: {
                Text("Neue Artikel ordnet nomi in die festen Kategorien ein. In eigene kommen sie, wenn ihr sie dorthin zieht – das merkt sich nomi. Eigene Kategorien löschst du per Wischen nach links.")
                    .font(.captionSans)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("Kategorien")
        .navigationBarTitleDisplayMode(.inline)
        .nameAlert($naming)
    }

    private func rename(_ category: ShoppingCategory) {
        var entry = NameEntry(title: "Umbenennen", placeholder: "Name", text: category.name) { name in
            Task { await shopping.renameCategory(category.key, to: name) }
        }
        if case .aisle(let aisle) = category.key, category.name != aisle.title {
            entry.reset = ("Zurück zu „\(aisle.title)“", { Task { await shopping.renameCategory(category.key, to: "") } })
        }
        naming = entry
    }
}

// MARK: - Namen eingeben

/// Ein Name per Alert: neu anlegen oder umbenennen.
struct NameEntry: Identifiable {
    let id = UUID()
    var title: String
    var placeholder: String
    var text = ""
    var save: (String) -> Void
    /// Optional: zweiter Knopf, z. B. Standardnamen wiederherstellen
    var reset: (String, () -> Void)?
}

private struct NameAlert: ViewModifier {
    @Binding var entry: NameEntry?
    @State private var text = ""

    func body(content: Content) -> some View {
        content
            .alert(entry?.title ?? "", isPresented: Binding(get: { entry != nil }, set: { if !$0 { entry = nil } }), presenting: entry) { entry in
                TextField(entry.placeholder, text: $text)
                Button("Sichern") { entry.save(text) }
                    .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)
                if let reset = entry.reset {
                    Button(reset.0) { reset.1() }
                }
                Button("Abbrechen", role: .cancel) {}
            }
            .onChange(of: entry?.id) { text = entry?.text ?? "" }
    }
}

extension View {
    func nameAlert(_ entry: Binding<NameEntry?>) -> some View {
        modifier(NameAlert(entry: entry))
    }
}
