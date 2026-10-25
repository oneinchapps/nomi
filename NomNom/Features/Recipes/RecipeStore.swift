import Foundation
import Observation
import Supabase
import UIKit

/// Rezepte des Haushalts. Lädt einmal, hört dann per Realtime auf Änderungen der anderen Person.
@Observable
final class RecipeStore {
    let householdId: UUID

    private(set) var recipes: [Recipe] = []
    private(set) var hasLoaded = false
    var loadError: String?

    init(householdId: UUID) {
        self.householdId = householdId
    }

    func recipe(id: UUID) -> Recipe? {
        recipes.first { $0.id == id }
    }

    func load() async {
        do {
            recipes = try await supabase
                .from("recipes")
                .select()
                .eq("household_id", value: householdId)
                .order("created_at", ascending: false)
                .execute()
                .value
            loadError = nil
        } catch {
            loadError = userMessage(for: error)
        }
        hasLoaded = true
    }

    /// Läuft, solange die Rezeptansicht existiert. Bei jeder Änderung wird neu geladen –
    /// bei ein paar hundert Rezepten günstiger als einzelne Events zusammenzuführen.
    func observeChanges() async {
        let channel = supabase.channel("recipes-\(householdId)")
        let changes = channel.postgresChange(
            AnyAction.self,
            table: "recipes",
            filter: .eq("household_id", value: householdId)
        )
        do {
            try await channel.subscribeWithError()
        } catch {
            return
        }
        for await _ in changes {
            await load()
        }
        await supabase.removeChannel(channel)
    }

    @discardableResult
    func save(_ recipe: Recipe) async throws -> Recipe {
        var recipe = recipe
        recipe.householdId = householdId
        let saved: Recipe = try await supabase
            .from("recipes")
            .upsert(recipe)
            .select()
            .single()
            .execute()
            .value
        if let index = recipes.firstIndex(where: { $0.id == saved.id }) {
            recipes[index] = saved
        } else {
            recipes.insert(saved, at: 0)
        }
        return saved
    }

    func delete(_ recipe: Recipe) async throws {
        try await supabase.from("recipes").delete().eq("id", value: recipe.id).execute()
        recipes.removeAll { $0.id == recipe.id }
        if let path = storagePath(of: recipe.imageURL) {
            _ = try? await supabase.storage.from(Self.bucket).remove(paths: [path])
        }
    }

    // MARK: - Fotos

    static let bucket = "recipe-images"

    /// Verkleinert auf max. 1600 px, speichert als JPEG unter <household>/<uuid>.jpg und liefert die öffentliche URL.
    func uploadImage(_ image: UIImage) async throws -> URL {
        let data = Self.jpegData(for: image)
        let path = "\(householdId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).jpg"
        try await supabase.storage.from(Self.bucket).upload(
            path,
            data: data,
            options: FileOptions(cacheControl: "31536000", contentType: "image/jpeg")
        )
        return try supabase.storage.from(Self.bucket).getPublicURL(path: path)
    }

    func removeImage(at url: URL?) async {
        guard let path = storagePath(of: url) else { return }
        _ = try? await supabase.storage.from(Self.bucket).remove(paths: [path])
    }

    private func storagePath(of url: URL?) -> String? {
        guard let url, let range = url.path.range(of: "/\(Self.bucket)/") else { return nil }
        return String(url.path[range.upperBound...])
    }

    static func jpegData(for image: UIImage, maxSide: CGFloat = 1600) -> Data {
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: 0.8) ?? Data()
    }
}
