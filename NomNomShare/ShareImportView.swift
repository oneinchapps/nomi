import Supabase
import SwiftUI

struct ShareImportView: View {
    let loadInput: () async -> ShareInput
    let close: () -> Void

    enum Phase {
        case starting
        case needsLogin
        case noLink
        case importing
        case done(Recipe, foundRecipe: Bool)
        case failed(String)
    }

    @State private var phase: Phase = .starting

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("nomnom")
                    .font(.logo)
                    .tracking(-0.8)
                    .foregroundStyle(Color.ink)
                Spacer()
                Button("Schließen", systemImage: "xmark", action: close)
                    .labelStyle(.iconOnly)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 36, height: 36)
                    .background(Color.surface, in: .circle)
            }
            .padding(.horizontal, Metrics.gutter)
            .padding(.top, 20)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Metrics.gutter)
        }
        .background(Color.canvas.ignoresSafeArea())
        .task { await run() }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .starting, .importing:
            ImportProgressView()
        case .needsLogin:
            message(
                emoji: "🔑",
                title: "Erst anmelden",
                text: "Öffne nomnom einmal und melde dich an. Danach kannst du Rezepte direkt hierher teilen."
            )
        case .noLink:
            message(emoji: "🔗", title: "Nichts zum Auslesen", text: "Teile einen Beitrag, eine Rezeptseite oder ein Foto von einem Rezept.")
        case .failed(let text):
            message(emoji: "🫠", title: "Hat nicht geklappt", text: text)
        case .done(let recipe, let found):
            done(recipe, found: found)
        }
    }

    private func done(_ recipe: Recipe, found: Bool) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            Spacer()
            MetaLabel("Gespeichert", font: .eyebrow, tracking: 2.4)
            RecipeCard(recipe: recipe, width: 260)
                .frame(maxWidth: .infinity)
            Text(found ? countLine(recipe) : "Im Beitrag stand kein vollständiges Rezept. Ergänze Zutaten und Schritte in der App.")
                .font(.bodySans)
                .foregroundStyle(Color.inkMuted)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Fertig", action: close)
                .buttonStyle(.primary)
                .padding(.bottom, 12)
        }
    }

    private func countLine(_ recipe: Recipe) -> String {
        "\(recipe.ingredients.count) Zutaten · \(recipe.steps.count) Schritte – liegt jetzt in euren Rezepten."
    }

    private func message(emoji: String, title: String, text: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Text(emoji)
                .font(.system(size: 56))
                .frame(width: 110, height: 110)
                .background(Color.mist, in: .circle)
            Text(title)
                .font(.cardTitle)
                .foregroundStyle(Color.ink)
            Text(text)
                .font(.bodySans)
                .foregroundStyle(Color.inkMuted)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Schließen", action: close)
                .buttonStyle(PrimaryButtonStyle(showsArrow: false))
                .padding(.bottom, 12)
        }
    }

    private func run() async {
        guard supabase.auth.currentSession != nil else {
            phase = .needsLogin
            return
        }
        let input = await loadInput()
        let photos = input.images.compactMap(UIImage.init(data:))
        guard input.url != nil || !photos.isEmpty else {
            phase = .noLink
            return
        }
        phase = .importing
        do {
            let result = if let url = input.url {
                try await RecipeImporter.importRecipe(url: url, text: input.text, save: true)
            } else {
                try await RecipeImporter.importRecipe(photos: photos, save: true)
            }
            withAnimation(.smooth) { phase = .done(result.recipe, foundRecipe: result.foundRecipe) }
        } catch {
            phase = .failed(displayMessage(for: error))
        }
    }
}
