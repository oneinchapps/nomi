import Foundation

extension StepText {
    /// Erkennt eine Dauer im Schritt („10 Minuten köcheln“, „1,5 Std. schmoren“, „8–10 Min“) in Sekunden.
    /// Bei Spannen gilt der größere Wert – lieber einmal nachsehen als zu früh abgießen.
    static func detectTimer(_ text: String) -> Int? {
        let pattern = /(\d+(?:[.,]\d+)?)(?:\s*(?:-|–|bis)\s*(\d+(?:[.,]\d+)?))?\s*(Sekunden|Sek\.?|Minuten|Min\.?|Stunden|Std\.?)/
            .ignoresCase()
        guard let match = text.firstMatch(of: pattern) else { return nil }
        let number = { (s: Substring) in Double(s.replacingOccurrences(of: ",", with: ".")) }
        guard let low = number(match.1) else { return nil }
        let value = match.2.flatMap(number) ?? low
        let unit = match.3.lowercased()
        let factor: Double = unit.hasPrefix("sek") ? 1 : unit.hasPrefix("min") ? 60 : 3600
        let seconds = Int((value * factor).rounded())
        return seconds > 0 ? seconds : nil
    }
}

enum CookingFormat {
    /// „09:41“ bzw. „1:05:00“
    static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}

extension Recipe.Step {
    /// Zutaten, die im Schritt vorkommen – damit man beim Kochen nicht zurückblättern muss.
    /// Ein Treffer ist der ganze Name oder ein markantes Wort daraus (ab 4 Buchstaben, z. B. „Tortillas“
    /// aus „kleine Tortillas“). Wörter wie „frische“ zählen nicht.
    func mentionedIngredients(from ingredients: [Ingredient]) -> [Ingredient] {
        let haystack = text.lowercased()
        let fillers: Set = ["frische", "frischer", "frisches", "kleine", "kleiner", "große", "großer", "rote", "roter", "grüne", "weiße", "gehackt", "geriebener"]
        return ingredients.filter { ingredient in
            let name = ingredient.name.lowercased()
            if haystack.contains(name) { return true }
            return name.split(whereSeparator: { !$0.isLetter })
                .map(String.init)
                .filter { $0.count >= 4 && !fillers.contains($0) }
                .contains { haystack.contains($0) || ($0.count > 5 && haystack.contains($0.dropLast())) }
        }
    }
}
