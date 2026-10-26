// nomi als Assistent: Prompt, Antwortschema und Prüfung der Aktionen. Reine Funktionen ohne Netzwerk – damit testbar.

import { CATEGORY_RULES, nullable } from "../_shared/recipe.ts";
import type { Idea } from "../_shared/expand.ts";

export interface RecipeRow {
  id: string;
  title: string;
  total_minutes: number | null;
  tags: string[];
  dish_type: string | null;
  diet: string | null;
}

export interface PlanRow {
  day: string;
  recipe_id: string;
  servings: number;
  note: string | null;
}

export interface MessageRow {
  user_id: string | null;
  content: string;
  actions: AssistantActions | null;
  result: { undone?: boolean } | null;
}

export interface ShoppingRow {
  name: string;
  quantity: number | null;
  unit: string | null;
}

export interface PlanEntry {
  /** YYYY-MM-DD */
  date: string;
  /** Rezept aus der Sammlung … */
  recipe_id: string | null;
  /** … oder ein neues Gericht, das vor dem Speichern ausgearbeitet wird */
  idea: Idea | null;
  servings: number;
  note: string | null;
}

export interface AssistantActions {
  plan: PlanEntry[] | null;
  shopping: {
    recipes: { recipe_id: string; servings: number }[];
    /** Zutaten aller in dieser Antwort geplanten Gerichte */
    include_new_plan: boolean;
    items: string[];
  } | null;
  /** Heute-Tab öffnen und dort Vorschläge für heute holen (allein festlegen oder gemeinsam swipen) */
  today: { wish: string | null } | null;
  navigate: Tab | null;
}

export type Tab = "today" | "recipes" | "shopping" | "week";
export const TABS: Tab[] = ["today", "recipes", "shopping", "week"];

export interface AssistantResult extends AssistantActions {
  reply: string;
}

const IDEA_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["title", "summary", "total_minutes", "tags", "emoji"],
  properties: {
    title: { type: "string" },
    summary: { type: "string" },
    total_minutes: nullable({ type: "integer" }),
    tags: { type: "array", items: { type: "string" } },
    emoji: { type: "string" },
  },
};

export const ASSISTANT_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["reply", "plan", "shopping", "today", "navigate"],
  properties: {
    reply: { type: "string" },
    plan: nullable({
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["date", "recipe_id", "idea", "servings", "note"],
        properties: {
          date: { type: "string" },
          recipe_id: nullable({ type: "string" }),
          idea: nullable(IDEA_SCHEMA),
          servings: { type: "integer" },
          note: nullable({ type: "string" }),
        },
      },
    }),
    shopping: nullable({
      type: "object",
      additionalProperties: false,
      required: ["recipes", "include_new_plan", "items"],
      properties: {
        recipes: {
          type: "array",
          items: {
            type: "object",
            additionalProperties: false,
            required: ["recipe_id", "servings"],
            properties: { recipe_id: { type: "string" }, servings: { type: "integer" } },
          },
        },
        include_new_plan: { type: "boolean" },
        items: { type: "array", items: { type: "string" } },
      },
    }),
    today: nullable({
      type: "object",
      additionalProperties: false,
      required: ["wish"],
      properties: { wish: nullable({ type: "string" }) },
    }),
    navigate: nullable({ type: "string", enum: TABS }),
  },
};

export function systemPrompt(names: string[]): string {
  const who = names.length ? names.join(" und ") : "einem Haushalt";
  return `Du bist nomi, der digitale Assistent für alles rund ums Essen von ${who}. Ihr führt ein gemeinsames Gespräch: Beide schreiben oder sprechen mit dir, und du hilfst beim Aussuchen, Planen, Einkaufen und Kochen.

So antwortest du (reply):
- Deutsch, locker, herzlich, per Du. Kurz: meist ein bis drei Sätze.
- Die Antwort wird oft vorgelesen. Darum kein Markdown, keine Aufzählungszeichen, keine Emojis, keine Links. Zahlen und Mengen so, wie man sie spricht.
- Sag nur, was du wirklich tust. Was in den Aktionen steht, ist erledigt, sobald die App sie ausführt – formuliere es so („Ich hab … auf die Liste gesetzt“).

Was du tun kannst (Aktionen; alles, was du nicht brauchst, ist null):
- today: Es geht ums heutige Essen und noch nichts steht fest – „Was essen wir heute?“, „Ich hab Lust auf was mit Kürbis“, „Heute Abend ein Drei-Gänge-Menü“. Dann suchst du NICHT selbst aus und planst nichts, sondern setzt today.wish auf den Wunsch in wenigen Worten (z. B. „Drei-Gänge-Menü“, „was mit Kürbis“, oder null) und navigate auf "today". Die App öffnet den Heute-Bereich und holt dort Vorschläge, aus denen man allein festlegt oder gemeinsam swipt. Sag kurz, dass dort Vorschläge warten.
- plan: Gerichte in den Wochenplan setzen, mit Datum. Für heute nur, wenn ein konkretes Gericht genannt ist („Heute gibt's Lasagne“) – dann navigate "today". Sonst navigate "week", auch wenn du zusätzlich einkaufst.
  - Nimm bevorzugt Rezepte aus der Sammlung (recipe_id genau wie angegeben). Achte auf Abwechslung und darauf, was lange nicht gekocht wurde.
  - Neue Gerichte nur, wenn es gewünscht ist oder die Sammlung nichts Passendes hat – höchstens drei pro Antwort, als idea (wird dann ausgearbeitet und in der Sammlung gespeichert). Dann ist recipe_id null.
  - Tage, an denen schon etwas geplant ist, überspringst du – außer es ist ausdrücklich gewünscht.
  - servings: 2, wenn nichts anderes gesagt ist. note nur für Hinweise wie den Gang („Dessert“).
- shopping: Zutaten auf die gemeinsame Einkaufsliste. recipes für Rezepte aus der Sammlung (mit Portionen), include_new_plan true für alles, was du in derselben Antwort planst, items für einzelne Dinge in Alltagssprache („2 l Milch“, „Brot“). Die App führt Mengen mit vorhandenen Einträgen zusammen. navigate "shopping", wenn es nur ums Einkaufen geht.
- navigate: Bereich, der danach geöffnet wird – "today", "recipes", "shopping", "week" oder null, wenn man im Gespräch bleibt.

Fragen zum Kochen, zu Zutaten, Mengen oder Ersatz beantwortest du direkt, ohne Aktion. Geht es gar nicht ums Essen, lenk freundlich zurück.

Kategorien in der Sammlung:
${CATEGORY_RULES}`;
}

function weekday(date: Date): string {
  return date.toLocaleDateString("de-DE", { weekday: "long", timeZone: "Europe/Berlin" });
}

/** YYYY-MM-DD in Berliner Zeit */
export function dayKey(date: Date): string {
  return date.toLocaleDateString("sv-SE", { timeZone: "Europe/Berlin" });
}

export function userPrompt(input: {
  now: Date;
  speaker: string;
  names: Map<string, string>;
  recipes: RecipeRow[];
  lastCooked: Map<string, string>;
  plan: PlanRow[];
  shopping: ShoppingRow[];
  staples: string[];
  messages: MessageRow[];
}): string {
  const titles = new Map(input.recipes.map((r) => [r.id, r.title]));

  const recipes = input.recipes.map((r) => {
    const parts = [
      r.title,
      r.total_minutes ? `${r.total_minutes} Min` : null,
      [r.dish_type, r.diet].filter(Boolean).join("/") || null,
      r.tags.length ? r.tags.join(", ") : null,
      input.lastCooked.has(r.id) ? `zuletzt gekocht ${input.lastCooked.get(r.id)}` : "noch nie gekocht",
    ].filter(Boolean);
    return `- ${r.id}: ${parts.join(" · ")}`;
  });

  const plan = input.plan.map((p) => {
    const date = new Date(`${p.day}T12:00:00Z`);
    return `- ${p.day} (${weekday(date)}): ${titles.get(p.recipe_id) ?? "Rezept"}, ${p.servings} Portionen${p.note ? `, ${p.note}` : ""}`;
  });

  const shopping = input.shopping.map((s) => `- ${[s.quantity, s.unit, s.name].filter((x) => x !== null && x !== "").join(" ")}`);

  const conversation = input.messages.map((m) => {
    const author = m.user_id ? input.names.get(m.user_id) ?? "Jemand" : "nomi";
    const done = m.actions && !m.result?.undone ? actionSummary(m.actions, titles) : null;
    const undone = m.actions && m.result?.undone ? " [wurde rückgängig gemacht]" : "";
    return `${author}: ${m.content}${done ? ` [${done}]` : ""}${undone}`;
  });

  return `Heute ist ${weekday(input.now)}, der ${dayKey(input.now)}.
Gerade schreibt: ${input.speaker}

Rezeptsammlung (${input.recipes.length}):
${recipes.join("\n") || "- (noch leer)"}

Wochenplan (letzte Woche bis in drei Wochen):
${plan.join("\n") || "- (nichts geplant)"}

Offene Einkaufsliste:
${shopping.join("\n") || "- (leer)"}

Wiederkehrende Einkäufe: ${input.staples.join(", ") || "keine"}

Bisheriges Gespräch:
${conversation.join("\n") || "(Das ist die erste Nachricht.)"}`;
}

/** Kurzfassung für den Verlauf, damit nomi weiß, was schon erledigt ist. */
export function actionSummary(actions: AssistantActions, titles: Map<string, string>): string | null {
  const parts: string[] = [];
  if (actions.plan?.length) {
    parts.push(`geplant: ${actions.plan.map((p) => `${p.date} ${p.recipe_id ? titles.get(p.recipe_id) ?? "Rezept" : p.idea?.title ?? "Gericht"}`).join(", ")}`);
  }
  if (actions.shopping) {
    const count = actions.shopping.recipes.length + actions.shopping.items.length + (actions.shopping.include_new_plan ? 1 : 0);
    if (count) parts.push("auf die Einkaufsliste gesetzt");
  }
  if (actions.today) parts.push(`Heute-Vorschläge geöffnet${actions.today.wish ? ` (${actions.today.wish})` : ""}`);
  return parts.length ? parts.join("; ") : null;
}

/**
 * Aktionen gegen den echten Datenbestand prüfen: unbekannte Rezepte, ungültige Daten und zu viele
 * neue Ideen fliegen raus. Gibt null zurück, wenn keine Aktion übrig bleibt.
 */
export function validActions(result: AssistantResult, recipeIds: Set<string>, today: string): AssistantActions | null {
  const maxDay = addDays(today, 60);
  const minDay = addDays(today, -1);
  let ideas = 0;
  const plan = (result.plan ?? []).filter((entry) => {
    if (!/^\d{4}-\d{2}-\d{2}$/.test(entry.date) || entry.date < minDay || entry.date > maxDay) return false;
    if (entry.recipe_id) return recipeIds.has(entry.recipe_id);
    if (entry.idea?.title.trim() && ideas < 3) {
      ideas += 1;
      return true;
    }
    return false;
  }).map((entry) => ({
    ...entry,
    idea: entry.recipe_id ? null : entry.idea,
    servings: Math.min(Math.max(entry.servings || 2, 1), 20),
    note: entry.note?.trim() || null,
  }));

  const shoppingRecipes = (result.shopping?.recipes ?? [])
    .filter((r) => recipeIds.has(r.recipe_id))
    .map((r) => ({ recipe_id: r.recipe_id, servings: Math.min(Math.max(r.servings || 2, 1), 20) }));
  const items = (result.shopping?.items ?? []).map((i) => i.trim()).filter(Boolean);
  const includePlan = (result.shopping?.include_new_plan ?? false) && plan.length > 0;
  const shopping = shoppingRecipes.length || items.length || includePlan
    ? { recipes: shoppingRecipes, include_new_plan: includePlan, items }
    : null;

  const today_ = result.today ? { wish: result.today.wish?.trim() || null } : null;
  const navigate = result.navigate && TABS.includes(result.navigate) ? result.navigate : null;

  if (!plan.length && !shopping && !today_ && !navigate) return null;
  return { plan: plan.length ? plan : null, shopping, today: today_, navigate };
}

export function addDays(day: string, days: number): string {
  const date = new Date(`${day}T12:00:00Z`);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}
