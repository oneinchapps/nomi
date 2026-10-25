import Testing
@testable import nomnom

struct TimerDetectionTests {
    @Test(arguments: [
        ("Nudeln 10 Minuten köcheln lassen.", 600),
        ("Im Ofen 1,5 Std. schmoren.", 5400),
        ("8–10 Min goldbraun backen.", 600),
        ("8 bis 10 Minuten ziehen lassen", 600),
        ("30 Sekunden anrösten", 30),
        ("Bei 180 °C 25 min backen", 1500),
    ] as [(String, Int)])
    func detects(text: String, seconds: Int) {
        #expect(StepText.detectTimer(text) == seconds)
    }

    @Test func ignoresStepsWithoutDuration() {
        #expect(StepText.detectTimer("Zwiebeln fein würfeln und 200 g Mehl unterheben.") == nil)
    }
}

struct CookingFormatTests {
    @Test func formatsCountdown() {
        #expect(CookingFormat.countdown(581) == "09:41")
        #expect(CookingFormat.countdown(0.2) == "00:01")
        #expect(CookingFormat.countdown(3900) == "1:05:00")
        #expect(CookingFormat.countdown(-3) == "00:00")
    }
}

struct MentionTests {
    let ingredients = [
        Ingredient(name: "Halloumi", quantity: 250, unit: "g"),
        Ingredient(name: "kleine Tortillas", quantity: 8),
        Ingredient(name: "Frühlingszwiebeln", quantity: 3),
        Ingredient(name: "frische Petersilie"),
        Ingredient(name: "Salz"),
    ]

    @Test func findsWholeNamesAndDistinctWords() {
        let step = Recipe.Step(text: "Halloumi braten und mit den Tortillas und der Frühlingszwiebel servieren.")
        #expect(step.mentionedIngredients(from: ingredients).map(\.name) == ["Halloumi", "kleine Tortillas", "Frühlingszwiebeln"])
    }

    @Test func ignoresFillerWords() {
        let step = Recipe.Step(text: "Mit frische Kräutern bestreuen.")
        #expect(step.mentionedIngredients(from: ingredients).isEmpty)
    }
}

struct StepScalingTests {
    @Test(arguments: [
        ("200 g Mehl unterheben", 2.0, "400 g Mehl unterheben"),
        ("1 Dose Tomaten und 2 EL Öl dazu", 2.0, "2 Dosen Tomaten und 4 EL Öl dazu"),
        ("½ TL Salz", 2.0, "1 TL Salz"),
        ("1,5 l Wasser aufkochen", 0.5, "750 ml Wasser aufkochen"),
        ("3 Zehen Knoblauch", 0.5, "1 ½ Zehen Knoblauch"),
        ("750g Kartoffeln", 2.0, "1,5 kg Kartoffeln"),
    ] as [(String, Double, String)])
    func scalesAmountsWithUnits(text: String, factor: Double, expected: String) {
        #expect(StepText.scaled(text, by: factor) == expected)
    }

    @Test func leavesTemperaturesTimesAndBareNumbersAlone() {
        let text = "Bei 180 °C 25 Minuten backen, dann in 3 Stücke schneiden und 2 lange Streifen legen."
        #expect(StepText.scaled(text, by: 2) == text)
    }

    @Test func recipeScalesStepTexts() {
        let recipe = Recipe(title: "Test", servings: 2, steps: [Recipe.Step(text: "100 g Zucker einrühren", timerSeconds: 60)])
        #expect(recipe.scaledSteps(for: 4).first == Recipe.Step(text: "200 g Zucker einrühren", timerSeconds: 60))
        #expect(recipe.scaledSteps(for: 2).first?.text == "100 g Zucker einrühren")
    }
}
