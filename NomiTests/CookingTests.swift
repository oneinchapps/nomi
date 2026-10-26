import Foundation
import Testing
@testable import nomi

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

struct FunctionDecodingTests {
    @Test func decodesPostgresTimestamps() throws {
        #expect(FunctionDecoding.date(from: "2026-10-25T21:14:33.123456+00:00") != nil)
        #expect(FunctionDecoding.date(from: "2026-10-25T21:14:33+00:00") != nil)
        #expect(FunctionDecoding.date(from: "2026-10-25T21:14:33.5Z") != nil)
        #expect(FunctionDecoding.date(from: "gestern") == nil)
    }

    @Test func decodesSavedRecipeFromFunction() throws {
        let json = """
        {"recipe": {"id": "6F9619FF-8B86-D011-B42D-00C04FC964FF", "title": "Kürbis-Gnocchi", "source": "ai",
          "servings": 2, "ingredients": [], "steps": [], "tags": [],
          "created_at": "2026-10-26T09:14:33.123456+00:00", "updated_at": "2026-10-26T09:14:33.123456+00:00"}}
        """
        struct Response: Decodable { let recipe: Recipe }
        let response = try FunctionDecoding.decoder.decode(Response.self, from: Data(json.utf8))
        #expect(response.recipe.title == "Kürbis-Gnocchi")
        #expect(response.recipe.createdAt != nil)
    }
}

struct RecipeFilterTests {
    let dal = Recipe(title: "Linsen-Dal", totalMinutes: 25, dishType: .hauptgericht, diet: .vegan)
    let roulade = Recipe(title: "Rouladen", totalMinutes: 180, dishType: .hauptgericht, diet: .fleisch)
    let schmarrn = Recipe(title: "Kaiserschmarrn", totalMinutes: 30, dishType: .dessert, diet: .vegetarisch)

    @Test func veganCountsAsVegetarian() {
        #expect(RecipeFilter.diet(.vegetarisch).matches(dal, lastCooked: nil))
        #expect(RecipeFilter.diet(.vegetarisch).matches(schmarrn, lastCooked: nil))
        #expect(!RecipeFilter.diet(.vegetarisch).matches(roulade, lastCooked: nil))
        #expect(!RecipeFilter.diet(.vegan).matches(schmarrn, lastCooked: nil))
    }

    @Test func quickAndDishType() {
        #expect(RecipeFilter.quick.matches(schmarrn, lastCooked: nil))
        #expect(!RecipeFilter.quick.matches(roulade, lastCooked: nil))
        #expect(!RecipeFilter.quick.matches(Recipe(title: "ohne Zeit"), lastCooked: nil))
        #expect(RecipeFilter.dishType(.dessert).matches(schmarrn, lastCooked: nil))
    }

    @Test func longNotCooked() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let calendar = PlanCalendar.calendar
        #expect(RecipeFilter.longNotCooked.matches(dal, lastCooked: nil, now: now), "Noch nie gekocht zählt")
        #expect(RecipeFilter.longNotCooked.matches(dal, lastCooked: calendar.date(byAdding: .day, value: -45, to: now), now: now))
        #expect(!RecipeFilter.longNotCooked.matches(dal, lastCooked: calendar.date(byAdding: .day, value: -5, to: now), now: now))
    }

    @Test func recipeDecodesCategories() throws {
        let json = #"{"id":"6F9619FF-8B86-D011-B42D-00C04FC964FF","title":"Dal","source":"web","servings":2,"ingredients":[],"steps":[],"tags":[],"dish_type":"hauptgericht","diet":"vegan"}"#
        let recipe = try JSONDecoder().decode(Recipe.self, from: Data(json.utf8))
        #expect(recipe.dishType == .hauptgericht)
        #expect(recipe.diet == .vegan)
    }
}

struct CookingHistoryTests {
    @Test func relativeLabels() {
        let calendar = PlanCalendar.calendar
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let ago = { (days: Int) in calendar.date(byAdding: .day, value: -days, to: now)! }
        #expect(CookingHistory.relative(ago(0), now: now) == "heute")
        #expect(CookingHistory.relative(ago(1), now: now) == "gestern")
        #expect(CookingHistory.relative(ago(5), now: now) == "vor 5 Tagen")
        #expect(CookingHistory.relative(ago(21), now: now) == "vor 3 Wochen")
        #expect(CookingHistory.relative(ago(100), now: now) == "vor 3 Monaten")
        #expect(CookingHistory.relative(ago(400), now: now) == "vor über einem Jahr")
    }

    @Test func parsesPostgresDate() {
        let date = CookingHistory.date(from: "2026-10-26")
        #expect(date.map(PlanCalendar.key(for:)) == "2026-10-26")
    }
}
