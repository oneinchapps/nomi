import { assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import type { Idea } from "../_shared/expand.ts";
import { actionSummary, addDays, type AssistantResult, userPrompt, validActions } from "./prompt.ts";

const idea = (title: string): Idea => ({ title, summary: "", total_minutes: 30, tags: [], emoji: "🍲" });
const empty: AssistantResult = { reply: "", plan: null, shopping: null, today: null, navigate: null };
const today = "2026-10-26";

Deno.test("Plan: nur bekannte Rezepte, gültige Daten, höchstens drei neue Ideen", () => {
  const actions = validActions({
    ...empty,
    plan: [
      { date: "2026-10-27", recipe_id: "r1", idea: null, servings: 2, note: null, meal: "abend" },
      { date: "2026-10-28", recipe_id: "erfunden", idea: null, servings: 2, note: null, meal: "abend" },
      { date: "27.10.2026", recipe_id: "r1", idea: null, servings: 2, note: null, meal: "abend" },
      { date: "2027-06-01", recipe_id: "r1", idea: null, servings: 2, note: null, meal: "abend" },
      { date: "2026-10-29", recipe_id: null, idea: idea("A"), servings: 0, note: " ", meal: "mittag" },
      { date: "2026-10-30", recipe_id: null, idea: idea("B"), meal: "abend", servings: 2, note: "Dessert" },
      { date: "2026-10-31", recipe_id: null, idea: idea("C"), meal: "abend", servings: 2, note: null },
      { date: "2026-11-01", recipe_id: null, idea: idea("D"), meal: "abend", servings: 2, note: null },
    ],
    navigate: "week",
  }, new Set(["r1"]), today);
  assertEquals(actions?.plan?.map((p) => p.recipe_id ?? p.idea?.title), ["r1", "A", "B", "C"]);
  assertEquals(actions?.plan?.[1].servings, 2);
  assertEquals(actions?.plan?.[1].note, null);
  assertEquals(actions?.plan?.[1].meal, "mittag");
  assertEquals(actions?.navigate, "week");
});

Deno.test("Einkauf: unbekannte Rezepte raus, Plan-Zutaten nur mit neuem Plan", () => {
  const actions = validActions({
    ...empty,
    shopping: { recipes: [{ recipe_id: "r1", servings: 4 }, { recipe_id: "x", servings: 2 }], include_new_plan: true, items: [" Milch ", ""] },
  }, new Set(["r1"]), today);
  assertEquals(actions?.shopping, { recipes: [{ recipe_id: "r1", servings: 4 }], include_new_plan: false, items: ["Milch"] });
});

Deno.test("Reine Antwort ohne Aktionen ergibt null", () => {
  assertEquals(validActions({ ...empty, reply: "Reis braucht etwa 20 Minuten." }, new Set(), today), null);
  assertEquals(validActions({ ...empty, navigate: "nirgendwo" as never }, new Set(), today), null);
});

Deno.test("Heute: Wunsch wird übernommen", () => {
  assertEquals(validActions({ ...empty, today: { wish: " was mit Kürbis ", meal: "mittag" }, navigate: "today" }, new Set(), today)?.today, { wish: "was mit Kürbis", meal: "mittag" });
});

Deno.test("Prompt enthält Sammlung, Plan, Liste und Verlauf mit erledigten Aktionen", () => {
  const prompt = userPrompt({
    now: new Date("2026-10-26T18:00:00Z"),
    speaker: "Alex",
    names: new Map([["u1", "Alex"]]),
    recipes: [{ id: "r1", title: "Linsen-Dal", total_minutes: 25, tags: ["schnell"], dish_type: "hauptgericht", diet: "vegan" }],
    lastCooked: new Map([["r1", "2026-10-20"]]),
    plan: [{ day: "2026-10-27", recipe_id: "r1", servings: 2, note: null, meal: "mittag" }],
    shopping: [{ name: "Milch", quantity: 1, unit: "l" }],
    staples: ["Eier"],
    messages: [
      { user_id: "u1", content: "Plan mir Dienstag", actions: null, result: null },
      { user_id: null, content: "Erledigt!", actions: { plan: [{ date: "2026-10-27", recipe_id: "r1", idea: null, servings: 2, note: null, meal: "abend" }], shopping: null, today: null, navigate: "week" }, result: null },
    ],
  });
  assertStringIncludes(prompt, "Heute ist Montag, der 2026-10-26.");
  assertStringIncludes(prompt, "- r1: Linsen-Dal · 25 Min · hauptgericht/vegan · schnell · zuletzt gekocht 2026-10-20");
  assertStringIncludes(prompt, "- 2026-10-27 (Dienstag), Mittagessen: Linsen-Dal, 2 Portionen");
  assertStringIncludes(prompt, "- 1 l Milch");
  assertStringIncludes(prompt, "nomi: Erledigt! [geplant: 2026-10-27 Abendessen Linsen-Dal]");
});

Deno.test("Zusammenfassung und Datumsrechnung", () => {
  assertEquals(actionSummary({ plan: null, shopping: null, today: { wish: null, meal: "abend" }, navigate: "today" }, new Map()), "Heute-Vorschläge geöffnet");
  assertEquals(addDays("2026-10-31", 1), "2026-11-01");
  assertEquals(addDays("2026-10-26", -7), "2026-10-19");
});
