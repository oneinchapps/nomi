import PhotosUI
import SwiftUI

/// Anlegen und Bearbeiten. Zutaten und Schritte als Freitext, eine Zeile pro Eintrag.
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
    @State private var ingredientsText: String
    @State private var stepsText: String
    @State private var sourceURL: String
    @State private var imageURL: URL?

    @State private var photoItem: PhotosPickerItem?
    @State private var pickedImage: UIImage?
    @State private var isSaving = false
    @State private var error: String?
    @FocusState private var focus: Field?

    enum Field { case title, summary, minutes, ingredients, steps, source }

    init(recipe: Recipe?, isNew: Bool = false, notice: String? = nil) {
        original = recipe
        self.isNew = isNew || recipe == nil
        self.notice = notice
        _title = State(initialValue: recipe?.title ?? "")
        _summary = State(initialValue: recipe?.summary ?? "")
        _minutes = State(initialValue: recipe?.totalMinutes.map(String.init) ?? "")
        _servings = State(initialValue: recipe?.servings ?? 2)
        _ingredientsText = State(initialValue: recipe?.ingredients.map(\.line).joined(separator: "\n") ?? "")
        _stepsText = State(initialValue: recipe?.steps.map(\.text).joined(separator: "\n") ?? "")
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
                            .font(.custom("Fraunces144pt-SemiBold", size: 20, relativeTo: .title3))
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

                    field("Zubereitung", hint: "Ein Schritt pro Zeile") {
                        textArea($stepsText, placeholder: "Halloumi in Scheiben schneiden und goldbraun braten.\nTortillas kurz in der Pfanne erwärmen.", field: .steps)
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
                recipe.ingredients = parsedIngredients()
                recipe.steps = stepsText
                    .split(whereSeparator: \.isNewline)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { text in
                        // Timer aus dem Original behalten, wenn der Text gleich geblieben ist
                        original?.steps.first { $0.text == text } ?? Recipe.Step(text: text)
                    }
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
                Image(uiImage: image).resizable().scaledToFill()
            } else if let imageURL {
                RecipeImage(recipe: Recipe(title: title, imageURL: imageURL), emojiSize: 56)
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
