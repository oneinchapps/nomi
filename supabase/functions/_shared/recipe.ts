// Gemeinsam für alle Functions: Rezeptformat (passt zu public.recipes und den Swift-Modellen)
// und der Claude-Client.
import Anthropic from "@anthropic-ai/sdk";

// Muss zu public.aisle und Aisle in der App passen
export const AISLES = [
  "obst_gemuese", "backwaren", "kuehlregal", "fleisch_fisch", "trockenwaren",
  "konserven", "gewuerze_oele", "tiefkuehl", "getraenke", "drogerie", "sonstiges",
] as const;

// Muss zu IngredientParser.units (rechte Seite) in der App passen
export const UNITS = [
  "g", "kg", "mg", "ml", "cl", "l", "EL", "TL", "Prise", "Msp", "Bund", "Stück",
  "Dose", "Packung", "Zehe", "Scheibe", "Becher", "Tasse", "Glas", "Handvoll",
] as const;

// Feste Kategorien – müssen zu den Check-Constraints in public.recipes und zu DishType/Diet in der App passen
export const DISH_TYPES = [
  "vorspeise", "suppe", "salat", "hauptgericht", "beilage", "dessert", "backen", "snack", "getraenk",
] as const;
export const DIETS = ["fleisch", "fisch", "vegetarisch", "vegan"] as const;

/** Prompt-Baustein, damit alle Functions gleich kategorisieren. */
export const CATEGORY_RULES = `- dish_type: Art des Gerichts – vorspeise, suppe, salat, hauptgericht, beilage, dessert, backen (Kuchen, Brot, Muffins, Gebäck), snack (Fingerfood, Häppchen) oder getraenk. Eine Suppe als Hauptmahlzeit ist trotzdem suppe.
- diet: fleisch (auch mit Speck, Wurst, Geflügel oder Fleischbrühe), fisch (Fisch oder Meeresfrüchte, ohne Fleisch), vegetarisch (ohne Fleisch und Fisch, mit Ei/Milch/Honig) oder vegan (gar keine tierischen Zutaten). Süßes ohne Fleisch ist vegetarisch oder vegan.`;

export interface ExtractedRecipe {
  found_recipe: boolean;
  title: string;
  summary: string | null;
  total_minutes: number | null;
  servings: number;
  ingredients: {
    name: string;
    quantity: number | null;
    unit: (typeof UNITS)[number] | null;
    note: string | null;
    aisle: (typeof AISLES)[number];
  }[];
  steps: { text: string; timer_seconds: number | null }[];
  tags: string[];
  dish_type: (typeof DISH_TYPES)[number] | null;
  diet: (typeof DIETS)[number] | null;
}

export const nullable = (schema: Record<string, unknown>) => ({ anyOf: [schema, { type: "null" }] });

export const RECIPE_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["found_recipe", "title", "summary", "total_minutes", "servings", "ingredients", "steps", "tags", "dish_type", "diet"],
  properties: {
    found_recipe: { type: "boolean" },
    title: { type: "string" },
    summary: nullable({ type: "string" }),
    total_minutes: nullable({ type: "integer" }),
    servings: { type: "integer" },
    ingredients: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["name", "quantity", "unit", "note", "aisle"],
        properties: {
          name: { type: "string" },
          quantity: nullable({ type: "number" }),
          unit: nullable({ type: "string", enum: [...UNITS] }),
          note: nullable({ type: "string" }),
          aisle: { type: "string", enum: [...AISLES] },
        },
      },
    },
    steps: {
      type: "array",
      items: {
        type: "object",
        additionalProperties: false,
        required: ["text", "timer_seconds"],
        properties: {
          text: { type: "string" },
          timer_seconds: nullable({ type: "integer" }),
        },
      },
    },
    tags: { type: "array", items: { type: "string" } },
    dish_type: nullable({ type: "string", enum: [...DISH_TYPES] }),
    diet: nullable({ type: "string", enum: [...DIETS] }),
  },
};

/** Schema für ein vollständiges Rezept ohne found_recipe (z. B. wenn nomnom eine Idee ausarbeitet). */
export const FULL_RECIPE_SCHEMA = {
  ...RECIPE_SCHEMA,
  required: RECIPE_SCHEMA.required.filter((key) => key !== "found_recipe"),
  properties: Object.fromEntries(Object.entries(RECIPE_SCHEMA.properties).filter(([key]) => key !== "found_recipe")),
};

export class ClaudeError extends Error {}

// Erst beim ersten Aufruf anlegen: ohne ANTHROPIC_API_KEY (Function-Secret) würde sonst schon das Laden scheitern
let client: Anthropic | null = null;

export function claude(): Anthropic {
  if (!client) {
    if (!Deno.env.get("ANTHROPIC_API_KEY")) {
      throw new ClaudeError("ANTHROPIC_API_KEY ist nicht als Function-Secret gesetzt");
    }
    client = new Anthropic();
  }
  return client;
}

/** Strukturierte Antwort von Claude (JSON-Schema), mit Fallback bei fälschlicher Ablehnung. */
export async function structured<T>(
  options: {
    system: string;
    /** Text oder Inhaltsblöcke (z. B. Fotos + Text) */
    user: string | Anthropic.Beta.BetaContentBlockParam[];
    schema: Record<string, unknown>;
    effort?: "low" | "medium" | "high";
  },
): Promise<T> {
  const response = await claude().beta.messages.create({
    model: "claude-opus-5-5",
    max_tokens: 16000,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    output_config: {
      effort: options.effort ?? "low",
      format: { type: "json_schema", schema: options.schema },
    },
    system: options.system,
    messages: [{ role: "user", content: options.user }],
  });
  if (response.stop_reason === "refusal") throw new ClaudeError("refusal");
  if (response.stop_reason === "max_tokens") throw new ClaudeError("truncated");
  const text = response.content.find((block) => block.type === "text");
  if (!text || text.type !== "text") throw new ClaudeError("no output");
  return JSON.parse(text.text) as T;
}
