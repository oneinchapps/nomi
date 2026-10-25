import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { type Idea, sessionCourses, type SuggestResult, userPrompt, validSuggestions } from "./suggest.ts";

const idea = (title: string): Idea => ({ title, summary: "", total_minutes: 20, tags: [], emoji: "🍝" });

Deno.test("nur bekannte Rezepte, keine Doppelten, nichts schon Vorgeschlagenes", () => {
  const result: SuggestResult = {
    reply: "Hier sind ein paar Ideen.",
    courses: null,
    suggestions: [
      { recipe_id: "r1", idea: null, reason: "passt", course: null },
      { recipe_id: "erfunden", idea: null, reason: "gibt es nicht", course: null },
      { recipe_id: "r1", idea: null, reason: "doppelt", course: null },
      { recipe_id: "r2", idea: null, reason: "schon gezeigt", course: null },
      { recipe_id: null, idea: idea("Zitronen-Pasta"), reason: "neu", course: null },
      { recipe_id: null, idea: idea("zitronen-pasta "), reason: "doppelt anders geschrieben", course: null },
      { recipe_id: null, idea: idea("Shakshuka"), reason: "schon gezeigt", course: null },
      { recipe_id: null, idea: null, reason: "leer", course: null },
    ],
  };
  const valid = validSuggestions(result, new Set(["r1", "r2"]), new Set(["r2", "shakshuka"]));
  assertEquals(valid.map((s) => s.recipe_id ?? s.idea?.title), ["r1", "Zitronen-Pasta"]);
});

Deno.test("Rezept mit recipe_id verliert eine mitgelieferte idea", () => {
  const valid = validSuggestions(
    { reply: "", courses: null, suggestions: [{ recipe_id: "r1", idea: idea("x"), reason: "", course: null }] },
    new Set(["r1"]),
    new Set(),
  );
  assertEquals(valid[0].idea, null);
});

Deno.test("Prompt enthält Sammlung, Stimmen mit Namen und den Chat", () => {
  const names = new Map([["u1", "Alex"], ["u2", "Sam"]]);
  const prompt = userPrompt({
    now: new Date("2026-10-25T18:00:00Z"),
    names,
    recipes: [{
      id: "r1",
      title: "Halloumi-Tacos",
      summary: null,
      total_minutes: 25,
      tags: ["vegetarisch"],
      ingredients: [{ name: "Halloumi" }, { name: "Tortillas" }],
    }],
    messages: [
      { user_id: "u1", content: "Was Schnelles bitte" },
      { user_id: null, content: "Klar!" },
    ],
    candidates: [{ id: "c1", recipe_id: null, ai_recipe: idea("Linsen-Dal"), course: null }],
    votes: [{ candidate_id: "c1", user_id: "u2", liked: false }],
  });
  assertStringIncludes(prompt, "Sonntag, 25. Oktober 2026");
  assertStringIncludes(prompt, "r1 | Halloumi-Tacos | 25 Min | vegetarisch | Zutaten: Halloumi, Tortillas");
  assertStringIncludes(prompt, "- Linsen-Dal (Sam: nein)");
  assertStringIncludes(prompt, "Alex: Was Schnelles bitte\nnomnom: Klar!");
});

Deno.test("Menü: nur Vorschläge für bekannte, offene Gänge", () => {
  const result: SuggestResult = {
    reply: "",
    courses: ["Vorspeise", "Hauptgang", "Dessert"],
    suggestions: [
      { recipe_id: null, idea: idea("Kürbissuppe"), reason: "", course: "Vorspeise" },
      { recipe_id: null, idea: idea("Rouladen"), reason: "", course: "Hauptgang" },
      { recipe_id: null, idea: idea("Käseplatte"), reason: "", course: "Käsegang" },
      { recipe_id: null, idea: idea("Mousse"), reason: "", course: null },
    ],
  };
  const valid = validSuggestions(result, new Set(), new Set(), result.courses, new Set(["Hauptgang"]));
  assertEquals(valid.map((s) => [s.course, s.idea?.title]), [["Vorspeise", "Kürbissuppe"]]);
});

Deno.test("Ohne Menü wird course verworfen", () => {
  const valid = validSuggestions(
    { reply: "", courses: null, suggestions: [{ recipe_id: null, idea: idea("Pasta"), reason: "", course: "Hauptgang" }] },
    new Set(),
    new Set(),
  );
  assertEquals(valid[0].course, null);
});

Deno.test("Gangfolge: bestehende bleibt, ein Gang ist kein Menü", () => {
  assertEquals(sessionCourses(["Vorspeise", "Hauptgang"], ["Suppe", "Braten", "Dessert"]), ["Vorspeise", "Hauptgang"]);
  assertEquals(sessionCourses(null, [" Vorspeise", "Hauptgang", "Hauptgang", "Dessert "]), ["Vorspeise", "Hauptgang", "Dessert"]);
  assertEquals(sessionCourses(null, ["Hauptgang"]), null);
  assertEquals(sessionCourses(null, null), null);
});

Deno.test("Prompt zeigt Gänge und was entschieden ist", () => {
  const prompt = userPrompt({
    now: new Date("2026-10-26T18:00:00Z"),
    names: new Map(),
    recipes: [],
    messages: [],
    candidates: [{ id: "c1", recipe_id: null, ai_recipe: idea("Kürbissuppe"), course: "Vorspeise" }],
    votes: [],
    courses: ["Vorspeise", "Hauptgang"],
    decided: new Map([["Vorspeise", "Kürbissuppe"]]),
  });
  assertStringIncludes(prompt, "- [Vorspeise] Kürbissuppe");
  assertStringIncludes(prompt, "- Vorspeise: entschieden (Kürbissuppe)\n- Hauptgang: offen");
});
