import PhotosUI
import SwiftUI

/// Gemeinsamer Ablauf für alle Importe: Eingabe → „nomnom liest mit“ → Editor zum Prüfen und Sichern.
struct RecipeImportFlow<Form: View>: View {
    let title: String
    var progressMessages = ImportProgressView.defaultMessages
    /// Das Formular bekommt `run` (startet den Import) und die letzte Fehlermeldung.
    @ViewBuilder let form: (_ run: @escaping (@escaping () async throws -> RecipeImporter.Result) -> Void, _ error: String?) -> Form

    @Environment(\.dismiss) private var dismiss
    @State private var isImporting = false
    @State private var error: String?
    @State private var draft: Draft?

    struct Draft {
        let recipe: Recipe
        let notice: String?
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
                        ImportProgressView(messages: progressMessages)
                    } else {
                        form(run, error)
                    }
                }
                .background(Color.canvas.ignoresSafeArea())
                .navigationTitle(title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Abbrechen") { dismiss() }
                    }
                }
            }
        }
    }

    private func run(_ work: @escaping () async throws -> RecipeImporter.Result) {
        guard !isImporting else { return }
        error = nil
        withAnimation { isImporting = true }
        Task {
            do {
                let result = try await work()
                withAnimation(.smooth) {
                    draft = Draft(
                        recipe: result.recipe,
                        notice: result.foundRecipe ? nil : "Hier stand kein vollständiges Rezept. Ergänze Zutaten und Schritte selbst."
                    )
                }
            } catch {
                self.error = displayMessage(for: error)
            }
            withAnimation { isImporting = false }
        }
    }
}

// MARK: - Aus Link

struct ImportLinkView: View {
    var body: some View {
        RecipeImportFlow(title: "Aus Link") { run, error in
            LinkForm(run: run, error: error)
        }
    }
}

private struct LinkForm: View {
    let run: (@escaping () async throws -> RecipeImporter.Result) -> Void
    let error: String?

    @State private var link = ""
    @FocusState private var focused: Bool

    private var url: URL? {
        RecipeImporter.firstURL(in: link.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    var body: some View {
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
        guard let url else { return }
        focused = false
        run { try await RecipeImporter.importRecipe(url: url, save: false) }
    }
}

// MARK: - Aus Foto

struct ImportPhotoView: View {
    var body: some View {
        RecipeImportFlow(
            title: "Aus Foto",
            progressMessages: ["Foto wird angeschaut …", "Handschrift wird entziffert …", "Zutaten werden gezählt …", "Fast fertig …"]
        ) { run, error in
            PhotoForm(run: run, error: error)
        }
    }
}

private struct PhotoForm: View {
    let run: (@escaping () async throws -> RecipeImporter.Result) -> Void
    let error: String?

    @State private var photos: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showsCamera = false
    @State private var note = ""

    private let maxPhotos = RecipeImporter.maxPhotos
    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        FormScreen(
            eyebrow: "Rezept importieren",
            headline: ["Foto rein,", "Rezept raus"],
            text: "Kochbuchseite, Zeitschrift, Screenshot oder Omas Karteikarte – nomnom liest auch Handschrift. Bis zu \(maxPhotos) Fotos pro Rezept."
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if !photos.isEmpty {
                    LazyVGrid(columns: columns, spacing: 10) {
                        ForEach(Array(photos.enumerated()), id: \.offset) { index, photo in
                            Color.clear
                                .aspectRatio(3 / 4, contentMode: .fit)
                                .overlay { Image(uiImage: photo).resizable().scaledToFill() }
                                .clipShape(.rect(cornerRadius: 14))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        photos.remove(at: index)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(Color.canvas)
                                            .frame(width: 26, height: 26)
                                            .background(Color.ink.opacity(0.8), in: .circle)
                                    }
                                    .padding(6)
                                    .accessibilityLabel("Foto \(index + 1) entfernen")
                                }
                        }
                    }
                }

                if photos.count < maxPhotos {
                    // Label vorab: der Label-Closure von PhotosPicker läuft nicht auf dem MainActor
                    let pickerTitle = photos.isEmpty ? "Aus Mediathek" : "Weitere Fotos"
                    HStack(spacing: 10) {
                        PhotosPicker(
                            selection: $pickerItems,
                            maxSelectionCount: maxPhotos - photos.count,
                            matching: .images
                        ) {
                            Label(pickerTitle, systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(.secondary)
                        if UIImagePickerController.isSourceTypeAvailable(.camera) {
                            Button("Kamera", systemImage: "camera") { showsCamera = true }
                                .buttonStyle(.secondary)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    MetaLabel("Hinweis")
                    TextField("Optional, z. B. „nur das rechte Rezept“", text: $note)
                        .fieldBackground()
                }

                InlineError(message: error)
            }
        } footer: {
            LoadingButton(title: "Rezept auslesen", isLoading: false, isEnabled: !photos.isEmpty, action: start)
        }
        .onChange(of: pickerItems) { _, items in
            Task { await load(items) }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraPicker { image in
                if let image, photos.count < maxPhotos { photos.append(image) }
            }
            .ignoresSafeArea()
        }
        .onAppear(perform: loadTestPhotos)
    }

    private func load(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data), photos.count < maxPhotos {
                photos.append(image)
            }
        }
        pickerItems = []
    }

    private func start() {
        let chosen = photos
        let hint = note.trimmingCharacters(in: .whitespaces).nilIfEmpty
        run { try await RecipeImporter.importRecipe(photos: chosen, note: hint, save: false) }
    }

    /// UI-Tests: Die Fotoauswahl des Systems lässt sich nicht fernsteuern, deshalb Fotos per Umgebungsvariable.
    private func loadTestPhotos() {
        #if DEBUG
        guard photos.isEmpty, let paths = ProcessInfo.processInfo.environment["NOMNOM_TEST_PHOTOS"] else { return }
        photos = paths.split(separator: ",").compactMap { UIImage(contentsOfFile: String($0)) }
        #endif
    }
}

/// Kamera über UIKit – SwiftUI hat keinen eigenen Kamera-Picker.
struct CameraPicker: UIViewControllerRepresentable {
    let onFinish: (UIImage?) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            parent.onFinish(info[.originalImage] as? UIImage)
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.onFinish(nil)
            parent.dismiss()
        }
    }
}
