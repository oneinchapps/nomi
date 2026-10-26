import SwiftUI

/// Verlauf: was wann gekocht wurde, nach Monaten gruppiert. Versehentliche Einträge lassen sich wegwischen.
struct CookingHistoryView: View {
    @Environment(CookingLogStore.self) private var log
    @Environment(RecipeStore.self) private var recipes
    @Environment(AppModel.self) private var app

    private var months: [(title: String, entries: [CookLogEntry])] {
        let calendar = PlanCalendar.calendar
        let groups = Dictionary(grouping: log.entries) { entry -> DateComponents in
            calendar.dateComponents([.year, .month], from: entry.date ?? .distantPast)
        }
        return groups
            .sorted { ($0.key.year ?? 0, $0.key.month ?? 0) > ($1.key.year ?? 0, $1.key.month ?? 0) }
            .map { key, entries in
                let date = calendar.date(from: key) ?? .now
                return (date.formatted(.dateTime.month(.wide).year().locale(Locale(identifier: "de_DE"))), entries)
            }
    }

    var body: some View {
        List {
            if log.entries.isEmpty {
                Text("Noch nichts gekocht. Sobald ihr im Kochmodus auf „Los geht's“ tippt, landet das Gericht hier.")
                    .font(.bodySans)
                    .foregroundStyle(Color.inkMuted)
                    .listRowBackground(Color.canvas)
            }
            ForEach(months, id: \.title) { month in
                Section {
                    ForEach(month.entries) { entry in
                        row(entry)
                    }
                } header: {
                    MetaLabel(month.title)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.canvas.ignoresSafeArea())
        .navigationTitle("Kochhistorie")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await log.load() }
    }

    @ViewBuilder
    private func row(_ entry: CookLogEntry) -> some View {
        if let recipe = recipes.recipe(id: entry.recipeId) {
            NavigationLink(value: recipe.id) {
                HStack(spacing: 14) {
                    RecipeImage(recipe: recipe, emojiSize: 24)
                        .frame(width: 52, height: 52)
                        .clipShape(.rect(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        MetaLabel([entry.date.map(DayFormat.weekdayAndDate), cook(entry)].compactMap { $0 }.joined(separator: " · "))
                        Text(recipe.title)
                            .font(.heading(17, relativeTo: .headline))
                            .foregroundStyle(Color.ink)
                            .lineLimit(2)
                    }
                }
            }
            .listRowBackground(Color.canvas)
            .swipeActions {
                Button("Löschen", role: .destructive) {
                    Task { await log.delete(entry) }
                }
            }
        }
    }

    private func cook(_ entry: CookLogEntry) -> String? {
        guard let id = entry.cookedBy else { return nil }
        return app.members.first { $0.userId == id }?.displayName
    }
}

extension DayFormat {
    /// „So, 26.10.“
    static func weekdayAndDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).locale(Locale(identifier: "de_DE"))) + ", " + short(date)
    }
}
