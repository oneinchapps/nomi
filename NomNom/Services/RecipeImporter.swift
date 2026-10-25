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

    private struct ErrorBody: Decodable {
        let error: String
    }

    struct ImportError: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func importRecipe(url: URL?, text: String? = nil, save: Bool) async throws -> Result {
        do {
            return try await supabase.functions.invoke(
                "import-recipe",
                options: FunctionInvokeOptions(
                    body: Request(url: url?.absoluteString, text: text, save: save),
                    // Seite laden + Claude + Bild kopieren dauert gern 15–30 Sekunden
                    timeoutInterval: 90
                )
            )
        } catch let FunctionsError.httpError(_, data) {
            // Die Funktion liefert verständliche deutsche Fehlermeldungen
            let message = (try? JSONDecoder().decode(ErrorBody.self, from: data))?.error
            throw ImportError(message: message ?? "Das Rezept ließ sich nicht auslesen.")
        }
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
