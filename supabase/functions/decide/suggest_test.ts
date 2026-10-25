import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { type Idea, type SuggestResult, userPrompt, validSuggestions } from "./suggest.ts";

const idea = (title: string): Idea => ({ title, summary: "", total_minutes: 20, tags: [], emoji: "🍝" });

Deno.test("nur bekannte Rezepte, keine Doppelten, nichts schon Vorgeschlagenes", () => {
  const result: SuggestResult = {
    reply: "Hier sind ein paar Ideen.",
    suggestions: [
      { recipe_id: "r1", idea: null, reason: "passt" },
      { recipe_id: "erfunden", idea: null, reason: "gibt es nicht" },
      { recipe_id: "r1", idea: null, reason: "doppelt" },
      { recipe_id: "r2", idea: null, reason: "schon gezeigt" },
      { recipe_id: null, idea: idea("Zitronen-Pasta"), reason: "neu" },
      { recipe_id: null, idea: idea("zitronen-pasta "), reason: "doppelt anders geschrieben" },
      { recipe_id: null, idea: idea("Shakshuka"), reason: "schon gezeigt" },
      { recipe_id: null, idea: null, reason: "leer" },
    ],
  };
  const valid = validSuggestions(result, new Set(["r1", "r2"]), new Set(["r2", "shakshuka"]));
  assertEquals(valid.map((s) => s.recipe_id ?? s.idea?.title), ["r1", "Zitronen-Pasta"]);
});

Deno.test("Rezept mit recipe_id verliert eine mitgelieferte idea", () => {
  const valid = validSuggestions(
    { reply: "", suggestions: [{ recipe_id: "r1", idea: idea("x"), reason: "" }] },
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
    candidates: [{ id: "c1", recipe_id: null, ai_recipe: idea("Linsen-Dal") }],
    votes: [{ candidate_id: "c1", user_id: "u2", liked: false }],
  });
  assertStringIncludes(prompt, "Sonntag, 25. Oktober 2026");
  assertStringIncludes(prompt, "r1 | Halloumi-Tacos | 25 Min | vegetarisch | Zutaten: Halloumi, Tortillas");
  assertStringIncludes(prompt, "- Linsen-Dal (Sam: nein)");
  assertStringIncludes(prompt, "Alex: Was Schnelles bitte\nnomnom: Klar!");
});
