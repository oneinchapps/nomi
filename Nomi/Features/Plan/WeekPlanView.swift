import SwiftUI

struct WeekPlanView: View {
    @Environment(MealPlanStore.self) private var plan
    @Environment(RecipeStore.self) private var recipes

    @State private var pickingDay: PickDay?
    @State private var shoppingSources: [AddToListSheet.Source]?

    struct PickDay: Identifiable {
        let date: Date
        var id: String { PlanCalendar.key(for: date) }
    }

    private var isCurrentWeek: Bool {
        plan.weekStart == PlanCalendar.startOfWeek(containing: .now)
    }

    var body: some View {
        ScrollView {
            header
            VStack(alignment: .leading, spacing: 22) {
                ForEach(plan.days, id: \.self) { day in
                    daySection(day)
                }
                if !plan.weekEntries.isEmpty {
                    Button("Zutaten der Woche einkaufen") {
                        shoppingSources = plan.weekEntries.compactMap { entry in
                            recipes.recipe(id: entry.recipeId).map { AddToListSheet.Source(recipe: $0, servings: entry.servings) }
                        }
                    }
                    .buttonStyle(.primary)
                    .padding(.top, 6)
                }
                InlineError(message: plan.error)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .background(Color.canvas.ignoresSafeArea())
        .refreshable { await plan.load() }
        .navigationDestination(for: UUID.self) { id in
            RecipeDetailView(recipeId: id)
        }
        .sheet(item: $pickingDay) { pick in
            RecipePickerSheet(day: pick.date)
        }
        .sheet(item: Binding(
            get: { shoppingSources.map { SourcesBox(sources: $0) } },
            set: { shoppingSources = $0?.sources }
        )) { box in
            AddToListSheet(sources: box.sources)
        }
    }

    private struct SourcesBox: Identifiable {
        let id = UUID()
        let sources: [AddToListSheet.Source]
    }

    // MARK: - Kopf

    private var header: some View {
        BrandHeader {
            // Pfeile neben der Kalenderwoche, damit die Headline die volle Breite hat
            HStack {
                MetaLabel("KW \(PlanCalendar.weekNumber(of: plan.weekStart)) · \(DayFormat.range(plan.days))", font: .eyebrow, tracking: 2.4)
                Spacer()
                HStack(spacing: 6) {
                    weekButton("chevron.left", label: "Vorige Woche", offset: -1)
                    weekButton("chevron.right", label: "Nächste Woche", offset: 1)
                }
            }
            DisplayHeadline(lines: [weekTitle])
            if !isCurrentWeek {
                Button("Zur aktuellen Woche") {
                    withAnimation { plan.weekStart = PlanCalendar.startOfWeek(containing: .now) }
                }
                .font(.captionSans)
                .underline()
            }
        }
    }

    private var weekTitle: String {
        let current = PlanCalendar.startOfWeek(containing: .now)
        let weeks = PlanCalendar.calendar.dateComponents([.weekOfYear], from: current, to: plan.weekStart).weekOfYear ?? 0
        switch weeks {
        case 0: return "Diese Woche"
        case 1: return "Nächste Woche"
        case -1: return "Letzte Woche"
        default: return "KW \(PlanCalendar.weekNumber(of: plan.weekStart))"
        }
    }

    private func weekButton(_ icon: String, label: String, offset: Int) -> some View {
        Button {
            withAnimation(.smooth) {
                plan.weekStart = PlanCalendar.calendar.date(byAdding: .weekOfYear, value: offset, to: plan.weekStart)!
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.onBrand)
                .frame(width: 34, height: 34)
                .background(Color.onBrand.opacity(0.18), in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    // MARK: - Tage

    private func daySection(_ day: Date) -> some View {
        let entries = plan.entries(on: day)
        let isToday = PlanCalendar.calendar.isDateInToday(day)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                MetaLabel("\(DayFormat.weekday(day)) · \(DayFormat.short(day))")
                if isToday {
                    Text("HEUTE")
                        .font(.meta)
                        .tracking(1.4)
                        .foregroundStyle(Color.canvas)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Color.ink, in: .capsule)
                }
                Spacer()
                Button {
                    pickingDay = PickDay(date: day)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 32, height: 32)
                        .background(Color.mist, in: .circle)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Gericht für \(DayFormat.weekday(day)) planen")
            }

            if entries.isEmpty {
                Text("Noch nichts geplant")
                    .font(.captionSans)
                    .foregroundStyle(Color.inkMuted.opacity(0.7))
            }
            ForEach(entries) { entry in
                if let recipe = recipes.recipe(id: entry.recipeId) {
                    entryRow(entry, recipe: recipe)
                }
            }
        }
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.hairline).frame(height: 1).offset(y: 12)
        }
    }

    private func entryRow(_ entry: MealPlanEntry, recipe: Recipe) -> some View {
        NavigationLink(value: recipe.id) {
            HStack(spacing: 14) {
                RecipeImage(recipe: recipe)
                    .frame(width: 56, height: 56)
                    .clipShape(.rect(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(recipe.title)
                        .font(.heading(18, relativeTo: .headline))
                        .foregroundStyle(Color.ink)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    // Bei Menüs steht der Gang vorne („VORSPEISE · 20 MIN · FÜR ZWEI“)
                    MetaLabel([entry.note, recipe.totalMinutes.map(Recipe.durationLabel), Recipe.servingsLabel(entry.servings)]
                        .compactMap { $0 }.joined(separator: " · "))
                }
                Spacer(minLength: 0)
                Menu {
                    Picker("Portionen", selection: Binding(
                        get: { entry.servings },
                        set: { value in Task { await plan.setServings(value, for: entry) } }
                    )) {
                        ForEach(1...8, id: \.self) { n in
                            Text(Recipe.servingsLabel(n).replacingOccurrences(of: "für ", with: "Für ")).tag(n)
                        }
                    }
                    Divider()
                    Button("Aus dem Plan nehmen", systemImage: "trash", role: .destructive) {
                        Task { await plan.remove(entry) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.inkMuted)
                        .frame(width: 36, height: 44)
                        .contentShape(.rect)
                }
                .accessibilityLabel("\(recipe.title) bearbeiten")
            }
            .padding(10)
            .background(Color.surface, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.hairline) }
        }
        .buttonStyle(.plain)
    }
}

/// Rezept für einen Tag auswählen.
struct RecipePickerSheet: View {
    let day: Date

    @Environment(RecipeStore.self) private var recipes
    @Environment(MealPlanStore.self) private var plan
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [Recipe] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        return q.isEmpty ? recipes.recipes : recipes.recipes.filter { $0.title.lowercased().contains(q) }
    }

    var body: some View {
        NavigationStack {
            List {
                if recipes.recipes.isEmpty {
                    Text("Noch keine Rezepte. Legt im Rezepte-Tab welche an oder importiert sie aus einem Link.")
                        .font(.bodySans)
                        .foregroundStyle(Color.inkMuted)
                        .listRowBackground(Color.canvas)
                }
                ForEach(filtered) { recipe in
                    Button {
                        Task {
                            await plan.add(recipe, on: day, servings: 2)
                            dismiss()
                        }
                    } label: {
                        HStack(spacing: 14) {
                            RecipeImage(recipe: recipe)
                                .frame(width: 52, height: 52)
                                .clipShape(.rect(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(recipe.title)
                                    .font(.heading(17, relativeTo: .headline))
                                    .foregroundStyle(Color.ink)
                                    .lineLimit(2)
                                if let minutes = recipe.totalMinutes {
                                    MetaLabel(Recipe.durationLabel(minutes))
                                }
                            }
                            // Ganze Zeilenbreite tippbar, nicht nur bis zum Ende des Titels
                            Spacer(minLength: 0)
                        }
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color.canvas)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Rezept suchen")
            .navigationTitle("\(DayFormat.weekday(day)), \(DayFormat.short(day))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
    }
}

/// Tag für ein Rezept auswählen (aus der Rezeptansicht heraus).
struct PlanDaySheet: View {
    let recipe: Recipe
    let servings: Int

    @Environment(MealPlanStore.self) private var plan
    @Environment(RecipeStore.self) private var recipes
    @Environment(\.dismiss) private var dismiss

    private var days: [Date] {
        let today = PlanCalendar.calendar.startOfDay(for: .now)
        return (0..<14).map { PlanCalendar.calendar.date(byAdding: .day, value: $0, to: today)! }
    }

    var body: some View {
        NavigationStack {
            List(days, id: \.self) { day in
                Button {
                    Task {
                        await plan.add(recipe, on: day, servings: servings)
                        dismiss()
                    }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(DayFormat.relative(day)).font(.bodySansMedium)
                            Text(DayFormat.short(day)).font(.captionSans).foregroundStyle(Color.inkMuted)
                        }
                        Spacer()
                        Image(systemName: "plus.circle")
                            .foregroundStyle(Color.ink)
                    }
                    .foregroundStyle(Color.ink)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.surface)
            }
            .scrollContentBackground(.hidden)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle("Wann kocht ihr?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

enum DayFormat {
    private static let locale = Locale(identifier: "de_DE")

    static func weekday(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).locale(locale))
    }

    /// „26.10.“
    static func short(_ date: Date) -> String {
        date.formatted(.dateTime.day(.twoDigits).month(.twoDigits).locale(locale))
    }

    static func range(_ days: [Date]) -> String {
        guard let first = days.first, let last = days.last else { return "" }
        return "\(short(first)) – \(short(last))"
    }

    static func relative(_ date: Date) -> String {
        let c = PlanCalendar.calendar
        if c.isDateInToday(date) { return "Heute" }
        if c.isDateInTomorrow(date) { return "Morgen" }
        return weekday(date)
    }
}
