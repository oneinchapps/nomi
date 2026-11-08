import SwiftUI

/// Kochmodus: Vorbereitung, dann ein Schritt pro Seite, Timer laufen über alle Seiten weiter.
struct CookingModeView: View {
    let recipe: Recipe

    @Environment(\.dismiss) private var dismiss
    @Environment(CookingLogStore.self) private var log
    /// Pro Kochmodus-Sitzung nur einmal eintragen
    @State private var logged = false
    /// Startet mit der Portionenzahl aus der Rezeptansicht, lässt sich in der Vorbereitung ändern.
    @State private var servings: Int
    @State private var page = 0
    @State private var checked: Set<Int> = []
    @State private var timers: CookingTimers
    @State private var width: CGFloat = 0
    /// „Hey nomi“: Sprachsteuerung, merkt sich das Gerät
    @State private var voice = CookingVoice()
    @AppStorage("cooking.voice") private var voiceEnabled = false
    @Environment(\.scenePhase) private var scenePhase
    #if DEBUG
    /// UI-Tests: wie vielter Satz aus NOMI_VOICE_SCRIPT als Nächstes „gesagt“ wird
    @State private var voiceTestIndex = 0
    #endif

    /// iPad: Zutaten links fest, Schritte rechts
    private var isWide: Bool { width >= Metrics.wideWidth }

    init(recipe: Recipe, servings: Int) {
        self.recipe = recipe
        _servings = State(initialValue: servings)
        _timers = State(initialValue: CookingTimers(recipeTitle: recipe.title))
    }

    private var ingredients: [Ingredient] { recipe.scaledIngredients(for: servings) }
    private var steps: [Recipe.Step] { recipe.scaledSteps(for: servings) }
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
                        voiceToggle
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
        // Über allem, auch über der Leiste: Chefi klopft von innen ans Display
        .overlay { timerAlarm }
        .animation(.smooth(duration: 0.3), value: timers.justFinished?.id)
        // Ganz oben: Nach „Hey nomi“ dimmt alles, auch ein Alarm (dann geht „Hey nomi, alles klar“)
        .overlay { voiceListening }
        .animation(.spring(duration: 0.45, bounce: 0.3), value: voice.phase == .listening || voice.phase == .thinking)
        .onAppear {
            voice.perform = { command, text in await perform(command, said: text) }
            if voiceEnabled { Task { await voice.start() } }
        }
        .onDisappear { voice.stop() }
        .onChange(of: scenePhase) { _, phase in
            // Im Hintergrund darf die App nicht zuhören; zurück in der App geht es weiter
            switch phase {
            case .background: voice.stop()
            case .active: if voiceEnabled && !voice.isOn { Task { await voice.start() } }
            default: break
            }
        }
        .onChange(of: voice.phase) { _, phase in
            // Gibt es die Sprachsteuerung nicht (Rechte, Gerät), nicht bei jedem Start erneut versuchen
            if case .unavailable = phase { voiceEnabled = false }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            header
            HStack(spacing: 0) {
                if isWide {
                    ingredientPanel
                }
                VStack(spacing: 0) {
                    TabView(selection: $page) {
                        prepPage.tag(0)
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            stepPage(index: index, step: step).tag(index + 1)
                        }
                        donePage.tag(lastPage)
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    .animation(.smooth, value: page)
                    .overlay(alignment: .bottomTrailing) {
                        VoiceCorner(voice: voice, showsChefi: page != lastPage) { chefiTapped() }
                    }
                    bottomBar
                }
            }
        }
        .trackWidth($width)
        .background(Color.canvas.ignoresSafeArea())
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
                Button(page == 0 ? "Los geht's" : "Weiter") { goForward() }
                .buttonStyle(.primary)
            } else {
                Button("Fertig") { dismiss() }
                    .buttonStyle(.primary)
            }
        }
        .padding(.horizontal, Metrics.gutter)
        .padding(.vertical, 10)
    }

    private func goForward() {
        logCookingOnce()
        withAnimation { page = min(page + 1, lastPage) }
    }

    /// Ab dem ersten Schritt wird wirklich gekocht – nicht schon beim bloßen Reinschauen
    private func logCookingOnce() {
        guard !logged else { return }
        logged = true
        Task { await log.logCooking(recipe, servings: servings) }
    }

    // MARK: - Seiten

    private var prepPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Erst mal alles bereitstellen")
                    .font(.heading(isWide ? 40 : 26, relativeTo: .title2))
                    .foregroundStyle(Color.ink)
                    .padding(.bottom, 8)
                if isWide {
                    // Die Liste steht links und bleibt beim Kochen stehen
                    Text("Hak links ab, was schon bereitsteht. Die Liste bleibt beim Kochen neben den Schritten stehen.")
                        .font(.custom("DMSans-Regular", size: 22, relativeTo: .title3))
                        .foregroundStyle(Color.inkMuted)
                } else {
                    servingsStepper.padding(.bottom, 10)
                    ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                        ingredientRow(index, ingredient)
                    }
                }
            }
            .padding(isWide ? 40 : Metrics.gutter)
        }
    }

    // Mengen in Zutaten und Schritten rechnen sich mit
    private var servingsStepper: some View {
        ServingsStepper(servings: $servings)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("cooking-servings")
    }

    private func ingredientRow(_ index: Int, _ ingredient: Ingredient, highlighted: Bool = false) -> some View {
        Button {
            if checked.contains(index) { checked.remove(index) } else { checked.insert(index) }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: checked.contains(index) ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(checked.contains(index) ? Color.sage : Color.hairline)
                Text(ingredient.name)
                    .font(highlighted ? .bodySansMedium : .bodySans)
                    .strikethrough(checked.contains(index), color: .inkMuted)
                    .foregroundStyle(checked.contains(index) ? Color.inkMuted : Color.ink)
                Spacer(minLength: 8)
                Text(ingredient.amountText)
                    .font(.bodySansMedium)
                    .monospacedDigit()
                    .foregroundStyle(Color.ink)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, highlighted ? 10 : 0)
            .background(highlighted ? Color.mist : .clear, in: .rect(cornerRadius: 12))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityValue(checked.contains(index) ? "bereit" : "")
    }

    /// iPad: Zutaten links, die des aktuellen Schritts hervorgehoben
    private var ingredientPanel: some View {
        let current = page >= 1 && page <= steps.count ? steps[page - 1].mentionedIngredients(from: ingredients) : []
        return ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                Text("Zutaten")
                    .font(.heading(24, relativeTo: .title2))
                    .foregroundStyle(Color.ink)
                    .padding(.bottom, 6)
                servingsStepper.padding(.bottom, 10)
                ForEach(Array(ingredients.enumerated()), id: \.offset) { index, ingredient in
                    ingredientRow(index, ingredient, highlighted: current.contains(ingredient))
                }
            }
            .padding(28)
            .animation(.smooth, value: page)
        }
        .frame(width: min(380, width * 0.34))
        .background(Color.surface.ignoresSafeArea(edges: .bottom))
    }

    private func stepPage(index: Int, step: Recipe.Step) -> some View {
        let mentioned = step.mentionedIngredients(from: ingredients)
        return ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                Text("\(index + 1)")
                    .font(.heading(isWide ? 96 : 72, relativeTo: .largeTitle))
                    .foregroundStyle(Color.brand)
                    .accessibilityHidden(true)
                Text(step.text)
                    .font(.custom("DMSans-Regular", size: isWide ? 34 : 25, relativeTo: .title2))
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
            .frame(maxWidth: isWide ? 760 : .infinity, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(isWide ? 40 : Metrics.gutter)
        }
    }

    private var donePage: some View {
        CookingDoneView(recipeTitle: recipe.title, isActive: page == lastPage)
    }

    @ViewBuilder
    private var timerAlarm: some View {
        if let finished = timers.justFinished {
            TimerAlarmView(
                title: "\(finished.label) ist fertig!",
                detail: steps.indices.contains(finished.id) ? steps[finished.id].text : nil
            ) {
                dismissAlarm()
            }
            .id(finished.id)
            .transition(.opacity)
        }
    }
}

// MARK: - Sprachsteuerung

extension CookingModeView {
    fileprivate var voiceToggle: some View {
        Button {
            if voice.isOn {
                voiceEnabled = false
                voice.stop()
            } else {
                voiceEnabled = true
                Task { await voice.start() }
            }
        } label: {
            Group {
                if voice.phase == .starting {
                    ProgressView().tint(Color.brand)
                } else {
                    Image(systemName: voice.isOn ? "mic.fill" : "mic")
                        .font(.system(size: 15, weight: .bold))
                }
            }
            .foregroundStyle(voice.isOn ? Color.brand : Color.onBrand)
            .frame(width: 36, height: 36)
            .background(voice.isOn ? Color.onBrand : Color.onBrand.opacity(0.18), in: .circle)
        }
        .accessibilityLabel(voice.isOn ? "Sprachsteuerung ausschalten" : "Sprachsteuerung einschalten")
        .accessibilityIdentifier("voice-toggle")
    }

    /// Bleibt immer in der Ansicht und wird nur ein- und ausgeblendet: Eine per `if` entfernte Ebene
    /// fing während ihres Ausblendens noch Tipps ab (der Tipp auf Chefi direkt nach einer Antwort ging verloren)
    fileprivate var voiceListening: some View {
        let isActive = voice.phase == .listening || voice.phase == .thinking
        return VoiceListeningOverlay(voice: voice, isActive: isActive)
            .opacity(isActive ? 1 : 0)
            .allowsHitTesting(isActive)
            .accessibilityHidden(!isActive)
    }

    /// Tipp auf Chefi: zuhören ohne „Hey nomi“. In UI-Tests „sagt“ der Tipp stattdessen den nächsten Satz
    /// aus NOMI_VOICE_SCRIPT (durch „|“ getrennt) – ein Mikrofon gibt es dort nicht. Ist das Skript durch,
    /// gilt wieder der normale Tipp. (Ein eigener unsichtbarer Testknopf bekam im Test keine Tipps ab.)
    fileprivate func chefiTapped() {
        #if DEBUG
        if let script = ProcessInfo.processInfo.environment["NOMI_VOICE_SCRIPT"] {
            let lines = script.components(separatedBy: "|")
            if voiceTestIndex < lines.count {
                voice.inject(lines[voiceTestIndex])
                voiceTestIndex += 1
                return
            }
        }
        #endif
        voice.listenNow()
    }

    fileprivate func dismissAlarm() {
        guard let finished = timers.justFinished else { return }
        withAnimation { page = finished.id + 1 }
        timers.dismissFinished()
    }

    /// Schritt, der gerade zu sehen ist (nil auf Vorbereitung und „Fertig“)
    private var currentStep: Int? {
        page >= 1 && page <= steps.count ? page - 1 : nil
    }

    /// Führt einen gesprochenen Befehl aus und sagt, was passiert ist
    fileprivate func perform(_ command: CookingCommand, said text: String) async -> CookingVoice.Reply {
        switch command {
        case .next:
            guard page < lastPage else { return .said("Das war's schon. Guten Appetit!") }
            goForward()
            return pageReply()
        case .back:
            guard page > 0 else { return .said("Wir sind schon am Anfang.") }
            withAnimation { page -= 1 }
            return pageReply()
        case .repeatStep:
            return pageReply()
        case .ingredients:
            let needed = currentStep.map { steps[$0].mentionedIngredients(from: ingredients) } ?? ingredients
            guard !needed.isEmpty else { return .said("Für diesen Schritt brauchst du nichts aus der Zutatenliste.") }
            let parts = needed.map(\.spokenAmount)
            return CookingVoice.Reply(parts.joined(separator: " · "), speech: CookingSpeech.speakable("Du brauchst " + CookingSpeech.list(parts) + "."))
        case .amount(let query):
            guard let ingredient = Ingredient.best(matching: query, in: ingredients) else {
                // Nicht im Rezept – vielleicht weiß nomi trotzdem etwas („Wie viel Wasser?“)
                return await ask(text)
            }
            return CookingVoice.Reply(ingredient.spokenAmount, speech: CookingSpeech.speakable(ingredient.spokenAmount + "."))
        case .startTimer:
            guard let step = currentStep, let seconds = steps[step].timerSeconds, seconds > 0 else {
                return .said("In diesem Schritt gibt's keinen Timer.")
            }
            if let timer = timers.timer(for: step), timer.isRunning {
                return .said("Läuft schon. Noch \(CookingFormat.spoken(timer.remaining(at: .now))).")
            }
            timers.start(step: step, label: "Schritt \(step + 1)", duration: TimeInterval(seconds))
            let remaining = timers.timer(for: step)?.remaining(at: .now) ?? TimeInterval(seconds)
            return .said("Läuft! \(CookingFormat.spoken(remaining)).")
        case .stopTimer:
            if timers.justFinished != nil {
                dismissAlarm()
                return CookingVoice.Reply("Alles klar!")
            }
            if let step = currentStep, timers.timer(for: step)?.isRunning == true {
                timers.pause(step: step)
                return .said("Timer angehalten.")
            }
            if let running = timers.active.first(where: \.isRunning) {
                timers.pause(step: running.id)
                return .said("Timer von Schritt \(running.id + 1) angehalten.")
            }
            return .said("Gerade läuft kein Timer.")
        case .timeLeft:
            let now = Date.now
            let parts = timers.active.map { timer in
                let time = CookingFormat.spoken(timer.remaining(at: now))
                if timer.isFinished { return "Schritt \(timer.id + 1) ist fertig" }
                if timer.isRunning {
                    return timer.id == currentStep ? "Noch \(time)" : "Schritt \(timer.id + 1): noch \(time)"
                }
                return "Schritt \(timer.id + 1) ist angehalten bei \(time)"
            }
            guard !parts.isEmpty else { return .said("Gerade läuft kein Timer.") }
            return .said(parts.joined(separator: ". ") + ".")
        case .okay:
            if timers.justFinished != nil { dismissAlarm() }
            return CookingVoice.Reply("Alles klar!")
        case .finish:
            logCookingOnce()
            withAnimation { page = lastPage }
            return .said("Guten Appetit!")
        case .question(let question):
            return await ask(question)
        case .unknown:
            return CookingVoice.Reply("Das hab ich nicht verstanden.", speech: "Das hab ich nicht verstanden. Sag zum Beispiel: Hey nomi, weiter.")
        }
    }

    /// Was auf der aktuellen Seite steht – zum Vorlesen nach „weiter“, „zurück“, „nochmal“
    private func pageReply() -> CookingVoice.Reply {
        if page == 0 {
            let list = CookingSpeech.list(ingredients.map(\.spokenAmount))
            return CookingVoice.Reply("Vorbereitung", speech: CookingSpeech.speakable("Erst mal alles bereitstellen: \(list)."))
        }
        guard let step = currentStep else { return .said("Guten Appetit!") }
        return CookingVoice.Reply("Schritt \(step + 1)", speech: CookingSpeech.speakable("Schritt \(step + 1). \(steps[step].text)"))
    }

    /// Freie Frage an nomi (Cloud) – mit dem Rezept, wie es gerade gekocht wird
    private func ask(_ question: String) async -> CookingVoice.Reply {
        struct Body: Encodable {
            struct RecipeContext: Encodable {
                let title: String
                let servings: Int
                let ingredients: [String]
                let steps: [String]
            }
            let mode = "cooking"
            let text: String
            let recipe: RecipeContext
            let step: Int
        }
        struct Answer: Decodable { let reply: String }
        let body = Body(
            text: question,
            recipe: .init(title: recipe.title, servings: servings, ingredients: ingredients.map(\.spokenAmount), steps: steps.map(\.text)),
            step: page
        )
        do {
            let answer: Answer = try await callFunction("assistant", body: body, timeout: 60, fallbackMessage: "nomi hat dich gerade nicht verstanden.")
            return .said(answer.reply)
        } catch {
            return .said(displayMessage(for: error))
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
                        // Mit Stunden („1:59:41“) kleiner, damit die Anzeige in einer Zeile bleibt
                        .font(.custom("DMMono-Medium", size: duration >= 3600 ? 32 : 40, relativeTo: .largeTitle))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .foregroundStyle(timer?.isFinished == true ? Color.brand : Color.ink)
                        .contentTransition(.numericText(countsDown: true))
                        .accessibilityLabel("Restzeit \(CookingFormat.countdown(remaining))")
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
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
