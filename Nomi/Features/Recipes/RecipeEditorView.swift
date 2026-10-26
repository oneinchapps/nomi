import PhotosUI
import SwiftUI

/// Anlegen und Bearbeiten. Zutaten als Freitext (eine Zeile pro Zutat), Schritte als einzelne Blöcke.
struct RecipeEditorView: View {
    let original: Recipe?
    /// Vorbefüllter Entwurf (z. B. aus dem Import), der noch nicht gespeichert ist.
    let isNew: Bool
    let notice: String?

    @Environment(RecipeStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var summary: String
    @State private var minutes: String
    @State private var servings: Int
    @State private var dishType: DishType?
    @State private var diet: Diet?
    @State private var ingredientsText: String
    @State private var steps: [StepDraft]
    @State private var sourceURL: String
    @State private var imageURL: URL?

    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var isSaving = false
    @State private var error: String?
    @FocusState private var focus: Field?

    enum Field: Hashable { case title, summary, minutes, ingredients, step(UUID), source }

    struct StepDraft: Identifiable, Equatable {
        let id = UUID()
        var text: String
        var timerSeconds: Int?
        /// Timer bewusst entfernt – dann beim Sichern nicht wieder aus dem Text erkennen
        var timerRemoved = false
    }

    private static let timerChoices = [1, 2, 3, 5, 8, 10, 12, 15, 20, 25, 30, 45, 60, 90, 120]

    init(recipe: Recipe?, isNew: Bool = false, notice: String? = nil) {
        original = recipe
        self.isNew = isNew || recipe == nil
        self.notice = notice
        _title = State(initialValue: recipe?.title ?? "")
        _summary = State(initialValue: recipe?.summary ?? "")
        _minutes = State(initialValue: recipe?.totalMinutes.map(String.init) ?? "")
        _servings = State(initialValue: recipe?.servings ?? 2)
        _dishType = State(initialValue: recipe?.dishType)
        _diet = State(initialValue: recipe?.diet)
        _ingredientsText = State(initialValue: recipe?.ingredients.map(\.line).joined(separator: "\n") ?? "")
        let drafts = (recipe?.steps ?? []).map { StepDraft(text: $0.text, timerSeconds: $0.timerSeconds) }
        _steps = State(initialValue: drafts.isEmpty ? [StepDraft(text: "")] : drafts)
        _sourceURL = State(initialValue: recipe?.sourceURL?.absoluteString ?? "")
        _imageURL = State(initialValue: recipe?.imageURL)
    }

    private var canSave: Bool { !title.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    if let notice {
                        Label(notice, systemImage: "info.circle")
                            .font(.captionSans)
                            .foregroundStyle(Color.ink)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.mist, in: .rect(cornerRadius: 14))
                    }
                    photoPicker

                    field("Titel") {
                        TextField("z. B. Halloumi-Tacos", text: $title)
                            .font(.heading(20, relativeTo: .title3, weight: .semibold))
                            .focused($focus, equals: .title)
                            .fieldBackground(isFocused: focus == .title)
                    }

                    field("Kurzbeschreibung") {
                        TextField("Optional", text: $summary, axis: .vertical)
                            .lineLimit(1...4)
                            .focused($focus, equals: .summary)
                            .padding(.vertical, 16)
                            .fieldBackground(isFocused: focus == .summary)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        field("Art") {
                            categoryMenu(selection: $dishType, options: DishType.allCases, title: \.title)
                        }
                        field("Ernährung") {
                            categoryMenu(selection: $diet, options: Diet.allCases, title: \.title)
                        }
                    }

                    HStack(alignment: .top, spacing: 12) {
                        field("Minuten") {
                            TextField("30", text: $minutes)
                                .keyboardType(.numberPad)
                                .focused($focus, equals: .minutes)
                                .fieldBackground(isFocused: focus == .minutes)
                        }
                        .frame(width: 110)
                        field("Portionen") {
                            ServingsStepper(servings: $servings, showsLabel: false)
                        }
                    }

                    field("Zutaten", hint: "Eine pro Zeile, z. B. „200 g Mehl“ oder „1 Zwiebel, gewürfelt“") {
                        textArea($ingredientsText, placeholder: "250 g Halloumi\n8 kleine Tortillas\n1 Avocado", field: .ingredients)
                    }

                    field("Zubereitung", hint: "Return beginnt einen neuen Schritt. Eingefügter Text wird Zeile für Zeile aufgeteilt.") {
                        stepsEditor
                    }

                    field("Quelle") {
                        TextField("Link (optional)", text: $sourceURL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($focus, equals: .source)
                            .fieldBackground(isFocused: focus == .source)
                    }

                    InlineError(message: error)
                }
                .padding(Metrics.gutter)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.canvas.ignoresSafeArea())
            .navigationTitle(isNew ? "Neues Rezept" : "Bearbeiten")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView()
                    } else {
                        Button("Sichern", action: save).disabled(!canSave)
                    }
                }
            }
            .interactiveDismissDisabled(isSaving)
            .onChange(of: photoItem) { _, item in
                Task { await loadPhoto(item) }
            }
        }
    }

    // MARK: - Bausteine

    private var photoPicker: some View {
        let label = PhotoPickerLabel(image: pickedImage, imageURL: imageURL, title: title)
        return PhotosPicker(selection: $photoItem, matching: .images) { label }
        .buttonStyle(.plain)
        .accessibilityLabel(pickedImage == nil && imageURL == nil ? "Foto hinzufügen" : "Foto ändern")
    }

    private func field<Content: View>(_ label: String, hint: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            MetaLabel(label)
            content()
            if let hint {
                Text(hint).font(.captionSans).foregroundStyle(Color.inkMuted)
            }
        }
    }

    private func textArea(_ text: Binding<String>, placeholder: String, field: Field) -> some View {
        TextEditor(text: text)
            .font(.bodySans)
            .foregroundStyle(Color.ink)
            .scrollContentBackground(.hidden)
            .focused($focus, equals: field)
            .frame(minHeight: 140)
            .accessibilityIdentifier("editor-\(field)")
            .padding(.horizontal, 13)
            .padding(.vertical, 10)
            .overlay(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .font(.bodySans)
                        .foregroundStyle(Color.inkMuted.opacity(0.6))
                        .padding(.horizontal, 18)
                        .padding(.vertical, 18)
                        .allowsHitTesting(false)
                }
            }
            .background(Color.surface, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(focus == field ? Color.ink : Color.hairline, lineWidth: focus == field ? 1.5 : 1)
            }
    }

    /// Auswahlfeld für eine Kategorie im Stil der übrigen Felder
    private func categoryMenu<Option: Hashable>(
        selection: Binding<Option?>,
        options: [Option],
        title: KeyPath<Option, String>
    ) -> some View {
        Menu {
            Button("Keine Angabe") { selection.wrappedValue = nil }
            Divider()
            ForEach(options, id: \.self) { option in
                Button(option[keyPath: title]) { selection.wrappedValue = option }
            }
        } label: {
            HStack {
                Text(selection.wrappedValue.map { $0[keyPath: title] } ?? "Wählen")
                    .foregroundStyle(selection.wrappedValue == nil ? Color.inkMuted : Color.ink)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.inkMuted)
            }
            .fieldBackground()
        }
    }

    // MARK: - Schritte

    private var stepsEditor: some View {
        VStack(spacing: 10) {
            ForEach($steps) { $step in
                let index = steps.firstIndex { $0.id == step.id } ?? 0
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(index + 1)")
                        .font(.heading(22, relativeTo: .title3))
                        .foregroundStyle(Color.ink)
                        .frame(width: 22, alignment: .leading)
                    VStack(alignment: .leading, spacing: 8) {
                        TextField("Was ist zu tun?", text: $step.text, axis: .vertical)
                            .font(.bodySans)
                            .foregroundStyle(Color.ink)
                            .lineLimit(1...12)
                            .focused($focus, equals: .step(step.id))
                            .accessibilityIdentifier("step-\(index + 1)")
                            .onChange(of: step.text) { _, _ in splitStep(step.id) }
                        if let seconds = step.timerSeconds ?? (step.timerRemoved ? nil : StepText.detectTimer(step.text)) {
                            Label(Recipe.durationLabel(max(1, seconds / 60)), systemImage: "timer")
                                .font(.captionSans)
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.mist, in: .capsule)
                                .accessibilityLabel("Timer \(Recipe.durationLabel(max(1, seconds / 60)))")
                        }
                    }
                    Menu {
                        Menu("Timer", systemImage: "timer") {
                            ForEach(Self.timerChoices, id: \.self) { minutes in
                                Button(Recipe.durationLabel(minutes)) {
                                    step.timerSeconds = minutes * 60
                                    step.timerRemoved = false
                                }
                            }
                            if step.timerSeconds != nil {
                                Divider()
                                Button("Kein Timer", systemImage: "xmark", role: .destructive) {
                                    step.timerSeconds = nil
                                    step.timerRemoved = true
                                }
                            }
                        }
                        Button("Nach oben", systemImage: "arrow.up") { moveStep(step.id, by: -1) }
                            .disabled(index == 0)
                        Button("Nach unten", systemImage: "arrow.down") { moveStep(step.id, by: 1) }
                            .disabled(index == steps.count - 1)
                        Button("Löschen", systemImage: "trash", role: .destructive) { deleteStep(step.id) }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color.inkMuted)
                            .frame(width: 32, height: 32)
                            .contentShape(.rect)
                    }
                    .accessibilityLabel("Schritt \(index + 1) bearbeiten")
                }
                .padding(.leading, 16)
                .padding(.trailing, 6)
                .padding(.vertical, 12)
                .background(Color.surface, in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(focus == .step(step.id) ? Color.ink : Color.hairline, lineWidth: focus == .step(step.id) ? 1.5 : 1)
                }
            }

            Button {
                let new = StepDraft(text: "")
                steps.append(new)
                focus = .step(new.id)
            } label: {
                Label("Schritt hinzufügen", systemImage: "plus")
                    .font(.bodySansMedium)
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(Color.hairline, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    }
            }
            .buttonStyle(.plain)
        }
        .animation(.smooth(duration: 0.25), value: steps.map(\.id))
    }

    /// Zeilenumbruch im Schritt (Return oder Einfügen) → in mehrere Schritte aufteilen.
    private func splitStep(_ id: UUID) {
        guard let index = steps.firstIndex(where: { $0.id == id }),
              let parts = StepText.split(steps[index].text) else { return }
        steps[index].text = parts.first
        let newSteps = parts.rest.map { StepDraft(text: $0) }
        steps.insert(contentsOf: newSteps, at: index + 1)
        if let last = newSteps.last { focus = .step(last.id) }
    }

    private func moveStep(_ id: UUID, by offset: Int) {
        guard let index = steps.firstIndex(where: { $0.id == id }), steps.indices.contains(index + offset) else { return }
        steps.swapAt(index, index + offset)
    }

    private func deleteStep(_ id: UUID) {
        steps.removeAll { $0.id == id }
        if steps.isEmpty { steps = [StepDraft(text: "")] }
    }

    // MARK: - Aktionen

    private func loadPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        pickedImage = image
    }

    private func save() {
        guard canSave, !isSaving else { return }
        isSaving = true
        error = nil
        Task {
            defer { isSaving = false }
            do {
                var recipe = original ?? Recipe(title: "")
                recipe.title = title.trimmingCharacters(in: .whitespaces)
                recipe.summary = summary.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
                recipe.totalMinutes = Int(minutes.trimmingCharacters(in: .whitespaces)).flatMap { $0 > 0 ? $0 : nil }
                recipe.servings = servings
                recipe.dishType = dishType
                recipe.diet = diet
                recipe.ingredients = parsedIngredients()
                recipe.steps = steps
                    .map { draft in
                        let text = draft.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        // Dauer aus dem Text übernehmen („10 Minuten köcheln“), außer der Timer wurde entfernt
                        let timer = draft.timerSeconds ?? (draft.timerRemoved ? nil : StepText.detectTimer(text))
                        return Recipe.Step(text: text, timerSeconds: timer)
                    }
                    .filter { !$0.text.isEmpty }
                recipe.sourceURL = normalizedURL(sourceURL)

                if let pickedImage {
                    let previous = recipe.imageURL
                    recipe.imageURL = try await store.uploadImage(pickedImage)
                    await store.removeImage(at: previous)
                }

                try await store.save(recipe)
                dismiss()
            } catch {
                self.error = userMessage(for: error)
            }
        }
    }

    /// Unveränderte Zeilen behalten ihre ursprünglichen Daten (z. B. die Abteilung aus dem KI-Import).
    private func parsedIngredients() -> [Ingredient] {
        let originals = Dictionary((original?.ingredients ?? []).map { ($0.line, $0) }, uniquingKeysWith: { first, _ in first })
        return ingredientsText
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .compactMap { line in
                originals[line.trimmingCharacters(in: .whitespaces)] ?? IngredientParser.parse(line)
            }
    }

    private func normalizedURL(_ text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return URL(string: trimmed.contains("://") ? trimmed : "https://\(trimmed)")
    }
}

/// Eigene View, weil das Label von PhotosPicker nicht auf dem MainActor ausgewertet wird.
private struct PhotoPickerLabel: View {
    let image: UIImage?
    let imageURL: URL?
    let title: String

    var body: some View {
        ZStack {
            if let image {
                Color.clear.overlay {
                    Image(uiImage: image).resizable().scaledToFill()
                }
            } else if let imageURL {
                RecipeImage(recipe: Recipe(title: title, imageURL: imageURL))
            } else {
                Rectangle().fill(Color.mist)
                VStack(spacing: 8) {
                    Image(systemName: "camera")
                        .font(.system(size: 26, weight: .medium))
                    Text("Foto hinzufügen").font(.bodySansMedium)
                }
                .foregroundStyle(Color.ink)
            }
        }
        .frame(height: 200)
        .frame(maxWidth: .infinity)
        .clipShape(.rect(cornerRadius: Metrics.cardRadius))
        .overlay(alignment: .bottomTrailing) {
            if image != nil || imageURL != nil {
                Label("Ändern", systemImage: "camera")
                    .font(.captionSans)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial, in: .capsule)
                    .padding(10)
            }
        }
    }
}

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
