import Foundation
import UIKit
import Supabase

/// Ruft die Edge Function `import-recipe` auf. Wird von der App (Vorschau im Editor)
/// und von der Teilen-Erweiterung (sofort speichern) genutzt.
enum RecipeImporter {
    struct Result: Decodable {
        let recipe: Recipe
        let foundRecipe: Bool
        let saved: Bool

        enum CodingKeys: String, CodingKey {
            case recipe, saved
            case foundRecipe = "found_recipe"
        }
    }

    private struct Request: Encodable {
        var url: String?
        var text: String?
        var images: [Photo]?
        let save: Bool
    }

    private struct Photo: Encodable {
        let data: String
        let media_type = "image/jpeg"
    }

    static let maxPhotos = 4

    /// Rezept von Fotos (gedruckt oder handgeschrieben). Fotos werden auf 1600 px verkleinert –
    /// genug zum Lesen von Handschrift, klein genug für einen schnellen Upload.
    static func importRecipe(photos: [UIImage], note: String? = nil, save: Bool) async throws -> Result {
        let encoded = photos.prefix(maxPhotos).map { photo in
            Photo(data: photo.jpegData(maxSide: 1600, quality: 0.75).base64EncodedString())
        }
        return try await callFunction(
            "import-recipe",
            body: Request(text: note, images: Array(encoded), save: save),
            timeout: 120,
            fallbackMessage: "Das Rezept ließ sich nicht vom Foto lesen."
        )
    }

    static func importRecipe(url: URL?, text: String? = nil, save: Bool) async throws -> Result {
        // Seite laden + Claude + Bild kopieren dauert gern 15–30 Sekunden
        try await callFunction(
            "import-recipe",
            body: Request(url: url?.absoluteString, text: text, save: save),
            fallbackMessage: "Das Rezept ließ sich nicht auslesen."
        )
    }

    /// Erste http(s)-URL aus geteiltem Text, z. B. „Schau mal! https://vm.tiktok.com/…“
    static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let range = NSRange(text.startIndex..., in: text)
        return detector?.firstMatch(in: text, range: range)?.url.flatMap { url in
            ["http", "https"].contains(url.scheme?.lowercased()) ? url : nil
        }
    }
}
