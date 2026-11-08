import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { cookingUserPrompt, parseCookingRequest } from "./cooking.ts";

Deno.test("Kochfrage: ohne Frage oder Rezepttitel unbrauchbar", () => {
  assertEquals(parseCookingRequest({ text: " ", recipe: { title: "Pasta" } }), null);
  assertEquals(parseCookingRequest({ text: "Geht Milch?", recipe: {} }), null);
  assertEquals(parseCookingRequest({ text: "Geht Milch?" }), null);
});

Deno.test("Kochfrage: Werte werden geprüft und gekürzt", () => {
  const request = parseCookingRequest({
    text: "Kann ich statt Sahne Milch nehmen?",
    recipe: { title: "Pasta", servings: -3, ingredients: ["200 g Spaghetti", 4, ""], steps: ["Kochen."] },
    step: "x",
  });
  assertEquals(request?.servings, 2);
  assertEquals(request?.ingredients, ["200 g Spaghetti"]);
  assertEquals(request?.step, 0);
  assertEquals(parseCookingRequest({ text: "a".repeat(900), recipe: { title: "P" } })?.question.length, 500);
});

Deno.test("Kochfrage: Prompt nennt Rezept, Portionen und aktuellen Schritt", () => {
  const prompt = cookingUserPrompt({
    question: "Wie erkenne ich, dass der Knoblauch fertig ist?",
    title: "Pasta Aglio e Olio",
    servings: 4,
    ingredients: ["400 g Spaghetti", "4 Zehen Knoblauch"],
    steps: ["Spaghetti kochen.", "Knoblauch in Öl anschwitzen."],
    step: 2,
  });
  assertStringIncludes(prompt, "Pasta Aglio e Olio (für 4 Portionen)");
  assertStringIncludes(prompt, "- 4 Zehen Knoblauch");
  assertStringIncludes(prompt, "2. Knoblauch in Öl anschwitzen.");
  assertStringIncludes(prompt, "Gerade: Schritt 2 von 2.");
  assertStringIncludes(prompt, "Frage: Wie erkenne ich");
  assertStringIncludes(cookingUserPrompt({ question: "?", title: "P", servings: 1, ingredients: [], steps: ["a"], step: 0 }), "Vorbereitung");
  assertStringIncludes(cookingUserPrompt({ question: "?", title: "P", servings: 1, ingredients: [], steps: ["a"], step: 2 }), "erledigt");
});
