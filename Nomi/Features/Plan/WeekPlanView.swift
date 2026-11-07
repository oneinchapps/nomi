import SwiftUI

struct WeekPlanView: View {
    @Environment(MealPlanStore.self) private var plan
    @Environment(RecipeStore.self) private var recipes

    @State private var pickingDay: PickDay?
    @State private var shoppingSources: [AddToListSheet.Source]?
    /// Tag, über dem gerade ein Eintrag schwebt
    @State private var dropTarget: String?
    /// Zählt Verschiebungen, nur für das haptische Feedback
    @State private var moves = 0
    @State private var width: CGFloat = 0

    /// iPad quer: Tage als Spalten nebeneinander
    private var isWide: Bool { width >= Metrics.boardWidth }

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
                // Unter dem Kopf statt darin, damit der Kopf in jeder Woche gleich hoch bleibt
                if !isCurrentWeek {
                    Button("Zur aktuellen Woche", systemImage: "arrow.uturn.backward") {
                        withAnimation { plan.weekStart = PlanCalendar.startOfWeek(containing: .now) }
                    }
                    .font(.captionSans)
                    .foregroundStyle(Color.ink)
                }
                if isWide {
                    HStack(alignment: .top, spacing: 10) {
                        ForEach(plan.days, id: \.self) { day in
                            boardColumn(day)
                        }
                    }
                } else {
                    VStack(spacing: 0) {
                        ForEach(plan.days, id: \.self) { day in
                            daySection(day)
                        }
                    }
                }
                if !plan.weekEntries.isEmpty {
                    Button("Zutaten der Woche einkaufen") {
                        shoppingSources = plan.weekEntries.compactMap { entry in
                            recipes.recipe(id: entry.recipeId).map { AddToListSheet.Source(recipe: $0, servings: entry.servings) }
                        }
                    }
                    .buttonStyle(.primary)
                    .frame(maxWidth: isWide ? 440 : .infinity)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                }
                InlineError(message: plan.error)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 20)
            .padding(.bottom, 32)
            // Hochkant auf dem iPad: Liste in der Lesespalte
            .readableColumn(isWide ? .infinity : Metrics.readableWidth)
        }
        .background(Color.canvas.ignoresSafeArea())
        .trackWidth($width)
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
        .sensoryFeedback(.success, trigger: moves)
        .animation(.smooth(duration: 0.3), value: plan.entries.map { "\($0.id)\($0.day)\($0.meal)" })
        .mainToolbar()
    }

    private struct SourcesBox: Identifiable {
        let id = UUID()
        let sources: [AddToListSheet.Source]
    }

    // MARK: - Kopf

    /// Gleich hoch wie Rezepte und Einkauf: Überschrift links, Pfeile rechts daneben
    private var header: some View {
        BrandHeader(bottomPadding: 22, contentWidth: isWide ? nil : Metrics.readableWidth) {
            HStack(spacing: 12) {
                DisplayHeadline(lines: [weekTitle])
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    weekButton("chevron.left", label: "Vorige Woche", offset: -1)
                    weekButton("chevron.right", label: "Nächste Woche", offset: 1)
                }
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

    /// Ein Tag wie im Kalender: links Wochentag und Tageszahl, rechts die Gerichte
    private func daySection(_ day: Date) -> some View {
        let entries = plan.entries(on: day)
        return HStack(alignment: .top, spacing: 14) {
            dateColumn(day)
            VStack(alignment: .leading, spacing: 8) {
                if entries.isEmpty {
                    HStack {
                        Text("Noch nichts geplant")
                            .font(.bodySans)
                            .foregroundStyle(Color.inkMuted.opacity(0.75))
                        Spacer()
                        addButton(day) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.ink)
                                .frame(width: 30, height: 30)
                                .background(Color.mist, in: .circle)
                        }
                    }
                    .frame(minHeight: 44)
                } else {
                    ForEach(entries) { entry in
                        if let recipe = recipes.recipe(id: entry.recipeId) {
                            entryRow(entry, recipe: recipe)
                        }
                    }
                    addButton(day) {
                        Label("Gericht", systemImage: "plus")
                            .font(.captionSans.weight(.medium))
                            .foregroundStyle(Color.inkMuted)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(.top, 14)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.hairline).frame(height: 1).padding(.leading, 60)
        }
        // Gezogene Einträge (IDs als Text) auf diesen Tag legen
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.brand.opacity(0.07))
                .strokeBorder(Color.brand.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .padding(-8)
                .opacity(dropTarget == PlanCalendar.key(for: day) ? 1 : 0)
        }
        .contentShape(.rect)
        .dropDestination(for: String.self) { ids, _ in
            drop(ids, on: day)
        } isTargeted: { targeted in
            let key = PlanCalendar.key(for: day)
            if targeted { dropTarget = key } else if dropTarget == key { dropTarget = nil }
        }
        .animation(.smooth(duration: 0.2), value: dropTarget)
    }

    /// iPad: ein Tag als Spalte mit Gerichten als Karten; Ablegen wie in der Liste
    private func boardColumn(_ day: Date) -> some View {
        let entries = plan.entries(on: day)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                dateColumn(day, horizontal: true)
                Spacer(minLength: 0)
            }
            ForEach(entries) { entry in
                if let recipe = recipes.recipe(id: entry.recipeId) {
                    boardCard(entry, recipe: recipe)
                }
            }
            addButton(day) {
                Image(systemName: "plus")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Color.inkMuted)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(Color.hairline, style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
                    }
                    .contentShape(.rect)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 260, alignment: .top)
        .background {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.brand.opacity(0.07))
                .strokeBorder(Color.brand.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                .opacity(dropTarget == PlanCalendar.key(for: day) ? 1 : 0)
        }
        .contentShape(.rect)
        .dropDestination(for: String.self) { ids, _ in
            drop(ids, on: day)
        } isTargeted: { targeted in
            let key = PlanCalendar.key(for: day)
            if targeted { dropTarget = key } else if dropTarget == key { dropTarget = nil }
        }
        .animation(.smooth(duration: 0.2), value: dropTarget)
    }

    /// Gericht im Board: Bild oben, darunter Mahlzeit und Titel
    private func boardCard(_ entry: MealPlanEntry, recipe: Recipe) -> some View {
        NavigationLink(value: recipe.id) {
            VStack(alignment: .leading, spacing: 6) {
                RecipeImage(recipe: recipe)
                    .frame(height: 80)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 10))
                    // „…“ als Knopf auf dem Bild, damit Titel und Mahlzeit die ganze Breite haben
                    .overlay(alignment: .topTrailing) {
                        entryMenu(entry, recipe: recipe)
                            .frame(width: 34, height: 34)
                            .background(Color.surface.opacity(0.9), in: .circle)
                            .padding(4)
                    }
                Text(recipe.title)
                    .font(.heading(16, relativeTo: .headline))
                    .foregroundStyle(Color.ink)
                    .lineLimit(3)
                    .minimumScaleFactor(0.8)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                MetaLabel([entry.meal.short, entry.note, Recipe.servingsLabel(entry.servings)].compactMap { $0 }.joined(separator: " · "))
            }
            .padding(10)
            .background(Color.surface, in: .rect(cornerRadius: 14))
            .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(Color.hairline) }
        }
        .buttonStyle(.plain)
        .draggable(entry.id.uuidString) { dragPreview(recipe) }
        .accessibilityIdentifier("plan-\(recipe.title)")
    }

    /// Wochentag klein, Tageszahl groß; heute im Himbeer-Kreis
    private func dateColumn(_ day: Date, horizontal: Bool = false) -> some View {
        let isToday = PlanCalendar.calendar.isDateInToday(day)
        // Im Board nebeneinander, in der Liste untereinander
        let layout = horizontal ? AnyLayout(HStackLayout(spacing: 6)) : AnyLayout(VStackLayout(spacing: 0))
        return layout {
            Text(DayFormat.weekdayShort(day).uppercased())
                .font(.meta)
                .tracking(1.2)
                .foregroundStyle(isToday ? Color.brand : Color.inkMuted)
            Text("\(PlanCalendar.calendar.component(.day, from: day))")
                .font(.heading(26, relativeTo: .title2))
                .monospacedDigit()
                .foregroundStyle(isToday ? Color.onBrand : Color.ink)
                .frame(width: 44, height: 44)
                .background(isToday ? Color.brand : .clear, in: .circle)
        }
        .frame(width: horizontal ? nil : 46)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(DayFormat.weekday(day)), \(DayFormat.short(day))\(isToday ? ", heute" : "")")
        .accessibilityAddTraits(.isHeader)
    }

    private func addButton(_ day: Date, @ViewBuilder label: () -> some View) -> some View {
        Button {
            pickingDay = PickDay(date: day)
        } label: {
            label()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Gericht für \(DayFormat.weekday(day)) planen")
    }

    private func drop(_ ids: [String], on day: Date) -> Bool {
        dropTarget = nil
        let dropped = ids.compactMap { id in plan.entries.first { $0.id.uuidString == id } }
        guard !dropped.isEmpty else { return false }
        let moving = dropped.filter { $0.day != PlanCalendar.key(for: day) }
        if !moving.isEmpty { moves += 1 }
        Task { for entry in moving { await plan.move(entry, to: day) } }
        return true
    }

    /// Portionen, Mahlzeit, aus dem Plan nehmen
    private func entryMenu(_ entry: MealPlanEntry, recipe: Recipe) -> some View {
        Menu {
            Picker("Portionen", selection: Binding(
                get: { entry.servings },
                set: { value in Task { await plan.setServings(value, for: entry) } }
            )) {
                ForEach(1...8, id: \.self) { n in
                    Text(Recipe.servingsLabel(n).replacingOccurrences(of: "für ", with: "Für ")).tag(n)
                }
            }
            Picker("Mahlzeit", selection: Binding(
                get: { entry.meal },
                set: { meal in
                    guard let day = PlanCalendar.date(forKey: entry.day) else { return }
                    Task { await plan.move(entry, to: day, meal: meal) }
                }
            )) {
                ForEach(Meal.allCases) { Text($0.title).tag($0) }
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

    private func dragPreview(_ recipe: Recipe) -> some View {
        HStack(spacing: 10) {
            RecipeImage(recipe: recipe)
                .frame(width: 36, height: 36)
                .clipShape(.rect(cornerRadius: 8))
            Text(recipe.title)
                .font(.heading(16, relativeTo: .headline))
                .foregroundStyle(Color.ink)
                .lineLimit(1)
        }
        .padding(8)
        .padding(.trailing, 6)
        .background(Color.surface, in: .rect(cornerRadius: 14))
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
                    // Mahlzeit und bei Menüs der Gang vorne („ABEND · VORSPEISE · 20 MIN · FÜR ZWEI“)
                    MetaLabel([entry.meal.short, entry.note, recipe.totalMinutes.map(Recipe.durationLabel), Recipe.servingsLabel(entry.servings)]
                        .compactMap { $0 }.joined(separator: " · "))
                }
                Spacer(minLength: 0)
                entryMenu(entry, recipe: recipe)
            }
            .padding(10)
            .background(Color.surface, in: .rect(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.hairline) }
        }
        .buttonStyle(.plain)
        // Halten und auf einen anderen Tag ziehen
        .draggable(entry.id.uuidString) { dragPreview(recipe) }
        .accessibilityIdentifier("plan-\(recipe.title)")
    }
}

/// Rezept für einen Tag auswählen – für eine feste Mahlzeit (Heute-Tab) oder mit Auswahl (Wochenplan).
struct RecipePickerSheet: View {
    let day: Date
    /// nil = Mahlzeit oben auswählbar
    var meal: Meal?

    @Environment(RecipeStore.self) private var recipes
    @Environment(MealPlanStore.self) private var plan
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var chosenMeal: Meal = .abend

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
                            await plan.add(recipe, on: day, servings: 2, meal: meal ?? chosenMeal)
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
            .safeAreaInset(edge: .top) {
                if meal == nil {
                    Picker("Mahlzeit", selection: $chosenMeal) {
                        ForEach(Meal.allCases) { Text($0.short).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, Metrics.gutter)
                    .padding(.vertical, 8)
                    .background(Color.canvas)
                }
            }
            .navigationTitle(meal.map { "\($0.title) · \(DayFormat.relative(day))" } ?? "\(DayFormat.weekday(day)), \(DayFormat.short(day))")
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

    /// „Mo“, „Di“ … – ohne Punkt, wie im Kalender
    static func weekdayShort(_ date: Date) -> String {
        String(weekday(date).prefix(2))
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
