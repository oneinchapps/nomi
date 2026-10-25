import SwiftUI

/// Kochmodus: Vorbereitung, dann ein Schritt pro Seite, Timer laufen über alle Seiten weiter.
struct CookingModeView: View {
    let recipe: Recipe
    let servings: Int

    @Environment(\.dismiss) private var dismiss
    @State private var page = 0
    @State private var checked: Set<Int> = []
    @State private var timers: CookingTimers

    init(recipe: Recipe, servings: Int) {
        self.recipe = recipe
        self.servings = servings
        _timers = State(initialValue: CookingTimers(recipeTitle: recipe.title))
    }

    private var ingredients: [Ingredient] { recipe.scaledIngredients(for: servings) }
    private var steps: [Recipe.Step] { recipe.steps }
    /// Vorbereitung + Schritte + „Guten Appetit“
    private var lastPage: Int { steps.count + 1 }

    var body: some View {
        // NavigationStack nur für die Leiste: helle Statusleiste auf Himbeere, Schließen + Fortschritt
        NavigationStack {
            content
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(Color.onBrand)
                                .frame(width: 36, height: 36)
                                .background(Color.onBrand.opacity(0.18), in: .circle)
                        }
                        .accessibilityLabel("Kochmodus beenden")
                    }
                    .sharedBackgroundVisibility(.hidden)
                    ToolbarItem(placement: .topBarTrailing) {
                        MetaLabel(progressLabel, font: .eyebrow, tracking: 2)
                            .environment(\.onBrandSurface, true)
                            .fixedSize()
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
                .brandNavigationBar()
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            TabView(selection: $page) {
                prepPage.tag(0)
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    stepPage(index: index, step: step).tag(index + 1)
                }
                donePage.tag(lastPage)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.smooth, value: page)
            bottomBar
        }
        .background(Color.canvas.ignoresSafeArea())
        .overlay(alignment: .top) { finishedBanner }
        // Restzeiten jede Sekunde neu prüfen; abgelaufene Timer klingeln
        .background {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Color.clear.onChange(of: context.date) { _, now in timers.tick(now: now) }
            }
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            timers.cancelAll()
        }
    }

    // MARK: - Kopf & Fuß

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(recipe.title)
                .font(.heading(22, relativeTo: .title3))
                .lineLimit(1)
            ProgressView(value: Double(page), total: Double(lastPage))
                .tint(Color.onBrand)
                .background(Color.onBrand.opacity(0.25), in: .capsule)
            if !timers.active.isEmpty {
                timerStrip
            }
        }
        .environment(\.onBrandSurface, true)
        .foregroundStyle(Color.onBrand)
        .padding(.horizontal, Metrics.gutter)
        .padding(.top, 4)
        .padding(.bottom, 18)
        .background {
            UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28)
                .fill(Color.brand)
                .padding(.top, -200)
        }
    }

    private var progressLabel: String {
        switch page {
        case 0: "Vorbereitung"
        case lastPage: "Fertig"
        default: "Schritt \(page) von \(steps.count)"
        }
    }

    /// Laufende Timer als Chips; Tipp springt zum Schritt.
    private var timerStrip: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(timers.active) { timer in
                        Button {
                            withAnimation { page = timer.id + 1 }
                        } label: {
                            Label(
                                "\(timer.id + 1) · \(timer.isFinished ? "Fertig" : CookingFormat.countdown(timer.remaining(at: context.date)))",
                                systemImage: timer.isFinished ? "bell.fill" : (timer.isRunning ? "timer" : "pause.fill")
                            )
                            .font(.custom("DMMono-Medium", size: 13, relativeTo: .caption))
                            .monospacedDigit()
                            .foregroundStyle(Color.brand)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.onBrand, in: .capsule)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Timer Schritt \(timer.id + 1)")
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 10) {
            if page > 0 {
                Button("Zurück", systemImage: "chevron.left") { withAnimation { page -= 1 } }
                    .buttonStyle(.secondary)
                    .frame(maxWidth: 140)
            }
            if page < lastPage {
                Button(page == 0 ? "Los geht's" : "Weiter") { withAnimation { page += 1 } }
                    .buttonStyle(.primary)
            } else {
                Button("Fertig") { dismiss() }
                    .buttonStyle(.primary)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
    }

    // MARK: - Seiten

    private var prepPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Erst mal alles bereitstellen")
                    .font(.heading(26, relativeTo: .title2))
                    .foregroundStyle(Color.ink)
                    .padding(.bottom, 4)
                MetaLabel(Recipe.servingsLabel(servings))
                    .padding(.bottom, 10)
                ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                    Button {
                        if checked.contains(index) { checked.remove(index) } else { checked.insert(index) }
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: checked.contains(index) ? "checkmark.circle.fill" : "circle")
                                .font(.system(size: 24))
                                .foregroundStyle(checked.contains(index) ? Color.sage : Color.hairline)
                            Text(ingredient.name)
                                .font(.bodySans)
                                .strikethrough(checked.contains(index), color: .inkMuted)
                                .foregroundStyle(checked.contains(index) ? Color.inkMuted : Color.ink)
                            Spacer(minLength: 8)
                            Text(ingredient.amountText)
                                .font(.bodySansMedium)
                                .monospacedDigit()
                                .foregroundStyle(Color.ink)
                        }
                        .padding(.vertical, 10)
                        .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .accessibilityValue(checked.contains(index) ? "bereit" : "")
                }
            }
            .padding(Metrics.gutter)
        }
    }

    private func stepPage(index: Int, step: Recipe.Step) -> some View {
        let mentioned = step.mentionedIngredients(from: ingredients)
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("\(index + 1)")
                    .font(.heading(72, relativeTo: .largeTitle))
                    .foregroundStyle(Color.brand)
                    .accessibilityHidden(true)
                Text(step.text)
                    .font(.custom("DMSans-Regular", size: 25, relativeTo: .title2))
                    .foregroundStyle(Color.ink)
                    .lineSpacing(6)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Schritt \(index + 1): \(step.text)")
                if !mentioned.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(mentioned.enumerated()), id: \.offset) { _, ingredient in
                            Text([ingredient.amountText, ingredient.name].filter { !$0.isEmpty }.joined(separator: " "))
                                .font(.bodySansMedium)
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 7)
                                .background(Color.mist, in: .capsule)
                        }
                    }
                }
                if let seconds = step.timerSeconds, seconds > 0 {
                    StepTimerCard(timers: timers, step: index, label: "Schritt \(index + 1)", duration: TimeInterval(seconds))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Metrics.gutter)
        }
    }

    private var donePage: some View {
        VStack(spacing: 14) {
            Spacer()
            Text("😋").font(.system(size: 72))
            Text("Guten Appetit!")
                .font(.display)
                .tracking(-1)
                .foregroundStyle(Color.ink)
            Text("\(recipe.title) ist fertig. Lasst es euch schmecken.")
                .font(.bodySans)
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(Metrics.gutter)
    }

    @ViewBuilder
    private var finishedBanner: some View {
        if let finished = timers.justFinished {
            Button {
                withAnimation { page = finished.id + 1 }
                timers.dismissFinished()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .symbolEffect(.wiggle, options: .repeating)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Timer abgelaufen").font(.buttonSans)
                        Text(finished.label).font(.captionSans)
                    }
                    Spacer()
                    Text("OK").font(.buttonSans)
                }
                .foregroundStyle(Color.canvas)
                .padding(16)
                .background(Color.ink, in: .rect(cornerRadius: 20))
                .shadow(color: .black.opacity(0.25), radius: 16, y: 8)
                .padding(.horizontal, Metrics.gutter)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel("Timer abgelaufen, \(finished.label)")
        }
    }
}

/// Timer eines Schritts: starten, pausieren, fortsetzen, zurücksetzen.
struct StepTimerCard: View {
    let timers: CookingTimers
    let step: Int
    let label: String
    let duration: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let timer = timers.timer(for: step)
            let remaining = timer?.remaining(at: context.date) ?? duration
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    MetaLabel(timer?.isFinished == true ? "Fertig" : (timer?.isRunning == true ? "Läuft" : "Timer"))
                    Text(CookingFormat.countdown(remaining))
                        .font(.custom("DMMono-Medium", size: 40, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .foregroundStyle(timer?.isFinished == true ? Color.brand : Color.ink)
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("Restzeit \(CookingFormat.countdown(remaining))")
                }
                Spacer()
                if timer != nil {
                    roundButton("arrow.counterclockwise", label: "Timer zurücksetzen") { timers.reset(step: step) }
                }
                if timer?.isRunning == true {
                    roundButton("pause.fill", label: "Timer pausieren", filled: true) { timers.pause(step: step) }
                } else if timer?.isFinished != true {
                    roundButton("play.fill", label: timer == nil ? "Timer starten" : "Timer fortsetzen", filled: true) {
                        timers.start(step: step, label: label, duration: duration)
                    }
                }
            }
            .padding(18)
            .background(Color.surface, in: .rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(timer?.isRunning == true ? Color.brand : Color.hairline, lineWidth: timer?.isRunning == true ? 2 : 1)
            }
        }
    }

    private func roundButton(_ icon: String, label: String, filled: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(filled ? Color.onBrand : Color.ink)
                .frame(width: 54, height: 54)
                .background(filled ? Color.brand : Color.mist, in: .circle)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
