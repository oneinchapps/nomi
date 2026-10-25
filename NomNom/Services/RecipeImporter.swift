import Foundation
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
        let url: String?
        let text: String?
        let save: Bool
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
