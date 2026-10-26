// Eine Gericht-Idee (Titel, Beschreibung, Zeit) zu einem vollständigen Rezept ausarbeiten und speichern.
// Genutzt von decide (nach einem Match) und assistant (neue Gerichte im Wochenplan).

import { CATEGORY_RULES, type ExtractedRecipe, FULL_RECIPE_SCHEMA, structured } from "./recipe.ts";
import type { UsageMeter } from "./budget.ts";

export interface Idea {
  title: string;
  summary: string;
  total_minutes: number | null;
  tags: string[];
  emoji: string;
}

export const EXPAND_SYSTEM = `Du schreibst vollständige, alltagstaugliche Rezepte für eine deutschsprachige Koch-App eines Zwei-Personen-Haushalts.

- Alles auf Deutsch, Du-Form in den Schritten.
- Zutaten aus einem deutschen Supermarkt, Mengen als Zahl für die angegebene Portionenzahl. Ohne Mengenangabe (Salz, Pfeffer) sind quantity und unit null. Zusätze wie "fein gehackt" gehören in note. Ordne jede Zutat der Supermarkt-Abteilung zu.
- steps: klare, einzelne Arbeitsschritte. Nennt ein Schritt eine Dauer, setz timer_seconds.
- tags: 2 bis 4 kurze Schlagworte.
${CATEGORY_RULES}
- Bleib bei der Idee: Titel und Charakter des Gerichts übernehmen, realistische Gesamtzeit.`;

export function expandPrompt(idea: Idea, servings: number): string {
  return `Arbeite diese Idee zu einem vollständigen Rezept für ${servings} Portionen aus:

Titel: ${idea.title}
Beschreibung: ${idea.summary}
Ungefähre Zeit: ${idea.total_minutes ? `${idea.total_minutes} Minuten` : "offen"}
Schlagworte: ${idea.tags.join(", ")}`;
}

// deno-lint-ignore no-explicit-any
type Client = any;

/** Arbeitet die Idee aus und legt sie über den RLS-Client der Person in der Sammlung an. */
export async function expandIdea(
  supabase: Client,
  householdId: string,
  idea: Idea,
  servings = 2,
  meter?: UsageMeter,
): Promise<Record<string, unknown>> {
  const full = await structured<Omit<ExtractedRecipe, "found_recipe">>({
    system: EXPAND_SYSTEM,
    user: expandPrompt(idea, servings),
    schema: FULL_RECIPE_SCHEMA,
    effort: "medium",
    meter,
  });
  const recipe = {
    id: crypto.randomUUID(),
    household_id: householdId,
    title: full.title.trim() || idea.title,
    summary: full.summary ?? idea.summary,
    source: "ai",
    source_url: null,
    image_url: null,
    total_minutes: full.total_minutes && full.total_minutes > 0 ? full.total_minutes : idea.total_minutes,
    servings: full.servings > 0 ? full.servings : servings,
    ingredients: full.ingredients,
    steps: full.steps,
    tags: full.tags,
    dish_type: full.dish_type,
    diet: full.diet,
  };
  const { data: saved, error } = await supabase.from("recipes").insert(recipe).select().single();
  if (error) throw error;
  return saved;
}
