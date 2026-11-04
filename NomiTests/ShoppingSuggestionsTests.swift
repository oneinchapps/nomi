import Foundation
import Testing
@testable import nomi

struct ShoppingSuggestionsTests {
    func lines(_ input: String, _ candidates: [ShoppingSuggestions.Candidate]) -> [String] {
        ShoppingSuggestions.suggestions(for: input, candidates: candidates).map(\.line)
    }

    @Test func keepsTypedAmount() {
        let candidates = ShoppingSuggestions.candidates(common: ["Milch", "Mehl"])
        #expect(lines("2 l Mi", candidates) == ["2 l Milch"])
        #expect(lines("200g Me", candidates) == ["200g Mehl"])
        #expect(lines("1  Dose  Mi", candidates) == ["1 Dose Milch"])
        #expect(lines("M", candidates) == ["Mehl", "Milch"])
    }

    @Test func nothingBeforeANameOrAfterAComma() {
        let candidates = ShoppingSuggestions.candidates(common: ["Milch"])
        #expect(lines("", candidates).isEmpty)
        #expect(lines("2 l", candidates).isEmpty)
        #expect(lines("Milch, fettarm", candidates).isEmpty)
    }

    @Test func ownHistoryBeatsVocabulary() {
        let candidates = ShoppingSuggestions.candidates(history: ["Hafermilch": 3], common: ["Hackfleisch", "Hafermilch", "Halloumi"])
        #expect(lines("Ha", candidates).first == "Hafermilch")
    }

    @Test func prefixBeatsWordBeatsSubstring() {
        let candidates = ShoppingSuggestions.candidates(
            history: ["Frühlingszwiebeln": 5],
            recipeIngredients: ["rote Zwiebeln"],
            common: ["Zwiebeln"]
        )
        #expect(lines("zwi", candidates) == ["Zwiebeln", "rote Zwiebeln", "Frühlingszwiebeln"])
        // Ab zwei Zeichen zählt nur der Wortanfang
        #expect(!lines("wi", candidates).contains("Frühlingszwiebeln"))
    }

    @Test func ignoresCaseAndUmlautsAndMergesDuplicates() {
        let candidates = ShoppingSuggestions.candidates(staples: ["Möhren"], recipeIngredients: ["möhren"], common: ["Mohren"])
        #expect(candidates.count == 1)
        #expect(candidates[0].name == "Möhren")
        #expect(lines("moh", candidates) == ["Möhren"])
    }

    @Test func skipsExactlyTypedName() {
        let candidates = ShoppingSuggestions.candidates(common: ["Eier", "Eis"])
        #expect(lines("eier", candidates).isEmpty)
        #expect(lines("Ei", candidates) == ["Eis", "Eier"].sorted { $0.count < $1.count })
    }

    @Test func historyCountsAcrossSpellings() throws {
        let defaults = try #require(UserDefaults(suiteName: "ShoppingHistoryTests-\(UUID())"))
        let household = UUID()
        ShoppingHistory.record("hafermilch", householdId: household, defaults: defaults)
        ShoppingHistory.record("Hafermilch ", householdId: household, defaults: defaults)
        ShoppingHistory.record("Brot", householdId: household, defaults: defaults)
        #expect(ShoppingHistory.load(householdId: household, defaults: defaults) == ["Hafermilch": 2, "Brot": 1])
        #expect(ShoppingHistory.load(householdId: UUID(), defaults: defaults).isEmpty)
    }
}
