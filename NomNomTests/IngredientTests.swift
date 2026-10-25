import Testing
@testable import nomnom

struct IngredientParserTests {
    @Test(arguments: [
        ("200 g Mehl", 200.0, "g", "Mehl"),
        ("200g Mehl", 200, "g", "Mehl"),
        ("1,5 kg Kartoffeln", 1.5, "kg", "Kartoffeln"),
        ("1/2 TL Salz", 0.5, "TL", "Salz"),
        ("½ Bund Petersilie", 0.5, "Bund", "Petersilie"),
        ("1 1/2 EL Olivenöl", 1.5, "EL", "Olivenöl"),
        ("1½ EL Olivenöl", 1.5, "EL", "Olivenöl"),
        ("2-3 Knoblauchzehen", 2, nil, "Knoblauchzehen"),
        ("2 Zehen Knoblauch", 2, "Zehe", "Knoblauch"),
        ("- 3 Eier", 3, nil, "Eier"),
        ("1 Dose Kichererbsen", 1, "Dose", "Kichererbsen"),
    ] as [(String, Double, String?, String)])
    func parsesQuantityUnitAndName(line: String, quantity: Double, unit: String?, name: String) throws {
        let ingredient = try #require(IngredientParser.parse(line))
        #expect(ingredient.quantity == quantity)
        #expect(ingredient.unit == unit)
        #expect(ingredient.name == name)
    }

    @Test func keepsLinesWithoutQuantity() throws {
        let ingredient = try #require(IngredientParser.parse("Salz und Pfeffer"))
        #expect(ingredient.quantity == nil)
        #expect(ingredient.unit == nil)
        #expect(ingredient.name == "Salz und Pfeffer")
    }

    @Test func splitsNoteAfterComma() throws {
        let ingredient = try #require(IngredientParser.parse("1 Zwiebel, fein gehackt"))
        #expect(ingredient.name == "Zwiebel")
        #expect(ingredient.note == "fein gehackt")
        #expect(ingredient.line == "1 Zwiebel, fein gehackt")
    }

    @Test func ignoresEmptyLines() {
        #expect(IngredientParser.parse("   ") == nil)
        #expect(IngredientParser.parse("•") == nil)
    }
}

struct QuantityFormatterTests {
    @Test(arguments: [
        (0.5, "EL", "½"),
        (1.5, "EL", "1 ½"),
        (0.25, nil, "¼"),
        (0.66, "TL", "⅔"),
        (2.0, nil, "2"),
        (1.97, nil, "2"),
        (0.1, "TL", "0,1"),
        (250.0, "g", "250"),
        (333.3, "g", "330"),
        (37.5, "ml", "40"),
        (1.25, "kg", "1,25"),
    ] as [(Double, String?, String)])
    func formats(value: Double, unit: String?, expected: String) {
        #expect(QuantityFormatter.string(for: value, unit: unit) == expected)
    }
}

struct ScalingTests {
    @Test func scalesFromTwoToFour() {
        let recipe = Recipe(
            title: "Test",
            servings: 2,
            ingredients: [
                Ingredient(name: "Mehl", quantity: 200, unit: "g"),
                Ingredient(name: "Ei", quantity: 1),
                Ingredient(name: "Salz"),
            ]
        )
        let scaled = recipe.scaledIngredients(for: 4)
        #expect(scaled.map(\.quantity) == [400, 2, nil])
        #expect(scaled[0].amountText == "400 g")
    }

    @Test func scalesDownToFractions() {
        let recipe = Recipe(title: "Test", servings: 4, ingredients: [Ingredient(name: "Olivenöl", quantity: 3, unit: "EL")])
        #expect(recipe.scaledIngredients(for: 2).first?.amountText == "1 ½ EL")
    }
}

struct AisleTests {
    @Test(arguments: [
        ("Reis", Aisle.trockenwaren),
        ("Eier", .kuehlregal),
        ("Olivenöl", .gewuerzeOele),
        ("Tomatenmark", .konserven),
        ("Kirschtomaten", .obstGemuese),
        ("Kokosmilch", .konserven),
        ("Halloumi", .kuehlregal),
        ("Paprikapulver", .gewuerzeOele),
        ("rote Paprika", .obstGemuese),
        ("Weizentortillas", .backwaren),
        ("Hackfleisch", .fleischFisch),
        ("Irgendwas", .sonstiges),
    ])
    func guessesAisle(name: String, aisle: Aisle) {
        #expect(Aisle.guess(for: name) == aisle)
    }
}

struct StepTextTests {
    @Test func noSplitWithoutNewline() {
        #expect(StepText.split("Zwiebeln schneiden") == nil)
    }

    @Test func returnAtEndStartsEmptyStep() throws {
        let parts = try #require(StepText.split("Zwiebeln schneiden\n"))
        #expect(parts.first == "Zwiebeln schneiden")
        #expect(parts.rest == [""])
    }

    @Test func pastedBlogStepsAreSplitAndUnnumbered() throws {
        let parts = try #require(StepText.split("1. Ofen vorheizen.\n\n2. Gemüse schneiden.\n3) Alles backen."))
        #expect(parts.first == "Ofen vorheizen.")
        #expect(parts.rest == ["Gemüse schneiden.", "Alles backen."])
    }

    @Test func keepsNumbersThatArePartOfTheText() throws {
        let parts = try #require(StepText.split("Teig ruhen lassen\n200 g Mehl unterheben"))
        #expect(parts.rest == ["200 g Mehl unterheben"])
    }
}

struct DurationLabelTests {
    @Test func formatsHoursAndMinutes() {
        #expect(Recipe.durationLabel(25) == "25 Min")
        #expect(Recipe.durationLabel(60) == "1 Std")
        #expect(Recipe.durationLabel(95) == "1 Std 35 Min")
    }
}
