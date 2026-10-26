import SwiftUI

/// nomi-Tab: das gemeinsame Gespräch mit dem Assistenten – per Text oder Sprache.
/// nomi plant, füllt die Einkaufsliste und springt danach in den passenden Bereich.
struct NomiView: View {
    @Environment(AssistantStore.self) private var assistant
    @Environment(RecipeStore.self) private var recipes
    @Environment(MealPlanStore.self) private var plan
    @Environment(ShoppingStore.self) private var shopping
    @Environment(DecideStore.self) private var decide
    @Environment(AppNavigation.self) private var navigation
    @Environment(AppModel.self) private var app

    @State private var input = ""
    @State private var voice = VoiceInput()
    @State private var speaker = Speaker()
    @AppStorage("nomi.speaksReplies") private var speaksReplies = true
    @FocusState private var inputFocused: Bool

    private let suggestions = ["Was essen wir heute?", "Plan unsere Woche", "Füll die Einkaufsliste für die Woche", "Was mache ich mit Resten?"]

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                header
                VStack(alignment: .leading, spacing: 16) {
                    if app.partner == nil, app.household != nil {
                        InviteCard()
                    }
                    ForEach(assistant.messages) { message in
                        VStack(alignment: .leading, spacing: 8) {
                            AssistantBubble(message: message, isMe: message.userId == app.userId, author: author(of: message))
                            if message.isFromNomi, let actions = message.actions {
                                ActionCard(message: message, actions: actions)
                                    .padding(.leading, 38)
                            }
                        }
                    }
                    if assistant.isThinking {
                        ThinkingBubble()
                    }
                    InlineError(message: assistant.error)
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(.horizontal, Metrics.gutter)
                .padding(.top, 20)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.canvas.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { inputBar }
            .onChange(of: assistant.messages.count) { scrollDown(proxy) }
            .onChange(of: assistant.isThinking) { scrollDown(proxy) }
            .onAppear { scrollDown(proxy, animated: false) }
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    speaksReplies.toggle()
                    if !speaksReplies { speaker.stop() }
                } label: {
                    Image(systemName: speaksReplies ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.onBrand)
                        .frame(width: 36, height: 36)
                        .background(Color.onBrand.opacity(0.18), in: .circle)
                        .contentTransition(.symbolEffect(.replace))
                }
                .accessibilityLabel(speaksReplies ? "Vorlesen ausschalten" : "Vorlesen einschalten")
            }
            .sharedBackgroundVisibility(.hidden)
        }
        .onAppear {
            voice.onFinished = { text in send(text, spoken: true) }
        }
    }

    // MARK: - Kopf

    private var header: some View {
        BrandHeader(bottomPadding: 22) {
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    DisplayHeadline(lines: ["Hallo \(app.me?.displayName ?? "")!"])
                    if assistant.messages.isEmpty {
                        Text("Ich bin nomi. Frag mich, was ihr heute esst, lass mich die Woche planen oder die Einkaufsliste füllen – gern auch per Sprache.")
                            .font(.bodySans)
                            .foregroundStyle(Color.onBrand.opacity(0.9))
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                ChefiView(waves: assistant.messages.isEmpty)
                    .frame(width: 72)
            }
        }
    }

    // MARK: - Eingabe

    private var inputBar: some View {
        VStack(spacing: 10) {
            if assistant.messages.isEmpty && !voice.isListening {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(suggestion) { send(suggestion, spoken: false) }
                                .font(.captionSans)
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color.mist, in: .capsule)
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Metrics.gutter)
                }
                .scrollIndicators(.hidden)
            }
            if case .unavailable(let reason) = voice.state {
                InlineError(message: reason)
                    .padding(.horizontal, Metrics.gutter)
            }
            HStack(alignment: .bottom, spacing: 10) {
                TextField(
                    voice.isListening ? "Ich höre zu …" : "Frag nomi",
                    text: voice.isListening ? .constant(voice.transcript) : $input,
                    axis: .vertical
                )
                .lineLimit(1...4)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit { send(input, spoken: false) }
                // Mehrzeilige Felder lösen bei „Senden“ kein onSubmit aus, sondern fügen einen Umbruch ein
                .onChange(of: input) { _, text in
                    if text.contains(where: \.isNewline) { send(text.filter { !$0.isNewline }, spoken: false) }
                }
                .disabled(voice.isListening)
                .font(.bodySans)
                .padding(.horizontal, 16)
                .padding(.vertical, 13)
                .background(Color.surface, in: .rect(cornerRadius: 22))
                .overlay {
                    RoundedRectangle(cornerRadius: 22)
                        .strokeBorder(voice.isListening ? Color.brand : (inputFocused ? Color.ink : Color.hairline), lineWidth: voice.isListening ? 2 : 1)
                }

                if input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || voice.isListening {
                    MicButton(isListening: voice.isListening) {
                        inputFocused = false
                        speaker.stop()
                        voice.toggle()
                    }
                    .disabled(assistant.isThinking)
                } else {
                    Button {
                        send(input, spoken: false)
                    } label: {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.canvas)
                            .frame(width: 46, height: 46)
                            .background(Color.ink, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .disabled(assistant.isThinking)
                    .opacity(assistant.isThinking ? 0.4 : 1)
                    .accessibilityLabel("Senden")
                }
            }
            .padding(.horizontal, Metrics.gutter)
        }
        .padding(.vertical, 10)
        .background(Color.canvas.opacity(0.96))
    }

    // MARK: - Ablauf

    private func send(_ text: String, spoken: Bool) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !assistant.isThinking else { return }
        input = ""
        inputFocused = false
        speaker.stop()
        Task {
            guard let reply = await assistant.send(trimmed) else { return }
            // Gesprochene Fragen bekommen eine gesprochene Antwort
            if spoken && speaksReplies { speaker.speak(reply.content) }
            await assistant.execute(reply, recipes: recipes, plan: plan, shopping: shopping)
            guard let actions = reply.actions else { return }
            if let first = actions.plan?.first, let day = PlanCalendar.date(forKey: first.date) {
                plan.weekStart = PlanCalendar.startOfWeek(containing: day)
            }
            if let today = actions.today {
                Task { await decide.startRound(wish: today.wish) }
            }
            if let tab = actions.target {
                // Kurz im Gespräch bleiben, damit man die Antwort sieht
                try? await Task.sleep(for: .seconds(1.2))
                withAnimation { navigation.tab = tab }
            }
        }
    }

    private func author(of message: AssistantMessage) -> String {
        guard let id = message.userId else { return "nomi" }
        return app.members.first { $0.userId == id }?.displayName ?? "Jemand"
    }

    private func scrollDown(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if animated {
            withAnimation(.smooth) { proxy.scrollTo("bottom", anchor: .bottom) }
        } else {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}

extension AssistantActions {
    /// Wohin es nach der Antwort geht
    var target: AppTab? {
        navigate ?? (today != nil ? .today : nil)
    }
}

// MARK: - Bausteine

/// Sprechblase; nomi bekommt einen kleinen Chefi daneben.
struct AssistantBubble: View {
    let message: AssistantMessage
    let isMe: Bool
    let author: String

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isMe { Spacer(minLength: 48) }
            if message.isFromNomi {
                ChefiView()
                    .frame(width: 30)
                    .padding(.bottom, 2)
            }
            VStack(alignment: isMe ? .trailing : .leading, spacing: 4) {
                if !isMe { MetaLabel(author) }
                Text(message.content)
                    .font(.bodySans)
                    .foregroundStyle(isMe ? Color.canvas : Color.ink)
                    .textSelection(.enabled)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(isMe ? Color.ink : (message.isFromNomi ? Color.mist : Color.surface), in: .rect(cornerRadius: 18))
                    .overlay {
                        if !isMe && !message.isFromNomi { RoundedRectangle(cornerRadius: 18).strokeBorder(Color.hairline) }
                    }
            }
            if !isMe { Spacer(minLength: 48) }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(isMe ? "Du" : author): \(message.content)")
    }
}

/// Was nomi erledigt hat – mit „Ansehen“ und „Rückgängig“.
struct ActionCard: View {
    let message: AssistantMessage
    let actions: AssistantActions

    @Environment(AssistantStore.self) private var assistant
    @Environment(RecipeStore.self) private var recipes
    @Environment(MealPlanStore.self) private var plan
    @Environment(ShoppingStore.self) private var shopping
    @Environment(AppNavigation.self) private var navigation

    @State private var isUndoing = false

    private var undone: Bool { message.result?.undone == true }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                Label {
                    Text(line.text)
                        .strikethrough(undone)
                } icon: {
                    Image(systemName: line.icon).foregroundStyle(Color.brand)
                }
                .font(.captionSans)
                .foregroundStyle(undone ? Color.inkMuted : Color.ink)
            }

            HStack(spacing: 14) {
                if let tab = actions.target, !undone {
                    Button("Ansehen") { navigation.tab = tab }
                        .font(.bodySansMedium)
                }
                Spacer(minLength: 0)
                if actions.changesData {
                    if undone {
                        MetaLabel("Rückgängig gemacht")
                    } else if message.result == nil {
                        MetaLabel("Wird eingetragen …")
                    } else {
                        Button("Rückgängig", systemImage: "arrow.uturn.backward") {
                            isUndoing = true
                            Task {
                                await assistant.undo(message, plan: plan, shopping: shopping)
                                isUndoing = false
                            }
                        }
                        .font(.captionSans)
                        .disabled(isUndoing)
                    }
                }
            }
            .foregroundStyle(Color.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.surface, in: .rect(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).strokeBorder(Color.hairline) }
    }

    private var lines: [(icon: String, text: String)] {
        var lines: [(String, String)] = []
        for entry in actions.plan ?? [] {
            let title = entry.recipeId.flatMap { recipes.recipe(id: $0)?.title } ?? "Neues Gericht"
            let day = PlanCalendar.date(forKey: entry.date).map(DayFormat.weekdayAndDate) ?? entry.date
            lines.append(("calendar", "\(day) · \(title)\(entry.note.map { " · \($0)" } ?? "")"))
        }
        if let action = actions.shopping {
            let dishes = action.recipes.count + (action.includeNewPlan ? (actions.plan?.count ?? 0) : 0)
            var parts: [String] = []
            if dishes > 0 { parts.append(dishes == 1 ? "Zutaten für 1 Gericht" : "Zutaten für \(dishes) Gerichte") }
            if !action.items.isEmpty { parts.append(action.items.joined(separator: ", ")) }
            lines.append(("basket", parts.joined(separator: " und ") + " auf der Einkaufsliste"))
        }
        if let today = actions.today {
            lines.append(("fork.knife", "Vorschläge für heute\(today.wish.map { " · \($0)" } ?? "")"))
        }
        return lines
    }
}

/// Mikrofon: antippen zum Sprechen, nochmal antippen (oder Pause) zum Abschicken.
struct MicButton: View {
    let isListening: Bool
    let action: () -> Void

    @State private var pulse = false

    var body: some View {
        Button(action: action) {
            Image(systemName: isListening ? "stop.fill" : "mic.fill")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(isListening ? Color.onBrand : Color.ink)
                .frame(width: 46, height: 46)
                .background(isListening ? Color.brand : Color.surface, in: .circle)
                .overlay { Circle().strokeBorder(isListening ? .clear : Color.hairline) }
                .background {
                    if isListening {
                        Circle()
                            .fill(Color.brand.opacity(0.25))
                            .scaleEffect(pulse ? 1.45 : 1)
                            .opacity(pulse ? 0 : 1)
                            .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: pulse)
                            .onAppear { pulse = true }
                            .onDisappear { pulse = false }
                    }
                }
                .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isListening ? "Aufnahme beenden" : "Mit nomi sprechen")
    }
}
