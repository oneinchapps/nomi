import SwiftUI

/// Link einfügen → nomnom liest das Rezept aus → Editor zum Prüfen und Sichern.
struct ImportLinkView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var link = ""
    @State private var isImporting = false
    @State private var error: String?
    @State private var draft: Draft?
    @FocusState private var focused: Bool

    struct Draft: Identifiable {
        let recipe: Recipe
        let notice: String?
        var id: UUID { recipe.id }
    }

    private var url: URL? {
        RecipeImporter.firstURL(in: link.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
        // Der Editor bringt seinen eigenen NavigationStack mit, daher ersetzen statt pushen
        if let draft {
            RecipeEditorView(recipe: draft.recipe, isNew: true, notice: draft.notice)
                .transition(.move(edge: .trailing))
        } else {
            NavigationStack {
                Group {
                    if isImporting {
                        ImportProgressView()
                    } else {
                        form
                    }
                }
                .background(Color.canvas.ignoresSafeArea())
                .navigationTitle("Aus Link")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                }
            }
        }
    }

    private var form: some View {
        FormScreen(
            eyebrow: "Rezept importieren",
            headline: ["Link rein,", "Rezept raus"],
            text: "Funktioniert mit Rezept-Blogs, Instagram und TikTok. nomnom liest Zutaten und Schritte aus und übersetzt sie bei Bedarf."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    TextField("https://…", text: $link)
                        .keyboardType(.URL)
                        .textContentType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .focused($focused)
                        .onSubmit(start)
                        .fieldBackground(isFocused: focused)
                    // PasteButton fragt nicht nach Erlaubnis, anders als UIPasteboard
                    PasteButton(payloadType: String.self) { strings in
                        if let first = strings.first { link = first }
                    }
                    .labelStyle(.iconOnly)
                    .buttonBorderShape(.circle)
                    .tint(Color.ink)
                }
                InlineError(message: error)
            }
        } footer: {
            LoadingButton(title: "Rezept auslesen", isLoading: false, isEnabled: url != nil, action: start)
        }
        .onAppear { focused = true }
    }

    private func start() {
        guard let url, !isImporting else { return }
        focused = false
        error = nil
        withAnimation { isImporting = true }
        Task {
            do {
                let result = try await RecipeImporter.importRecipe(url: url, save: false)
                withAnimation(.smooth) {
                    draft = Draft(
                    recipe: result.recipe,
                        notice: result.foundRecipe ? nil : "Im Beitrag stand kein vollständiges Rezept. Ergänze Zutaten und Schritte selbst."
                    )
                }
            } catch {
                self.error = (error as? LocalizedError)?.errorDescription ?? userMessage(for: error)
            }
            withAnimation { isImporting = false }
        }
    }
}
