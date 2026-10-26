// nomi als Assistent für alles rund ums Essen – ein gemeinsamer Verlauf pro Haushalt.
//
// POST { text } → { user_message, message }
//   Speichert die Nachricht der Person, liest Sammlung, Wochenplan, Einkaufsliste und Verlauf,
//   und lässt Claude antworten. Neue Gerichte für den Wochenplan werden gleich ausgearbeitet
//   und in der Sammlung gespeichert. Die Aktionen (Wochenplan, Einkaufsliste, Heute) führt die
//   App der fragenden Person aus und vermerkt das Ergebnis in `result` – so bleibt die Logik
//   zum Zusammenführen der Einkaufsliste an einer Stelle und alles lässt sich rückgängig machen.

import "@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "@anthropic-ai/sdk";
import { withSupabase } from "@supabase/server";
import { ClaudeError, structured } from "../_shared/recipe.ts";
import { expandIdea } from "../_shared/expand.ts";
import { BudgetExceeded, budgetResponse, ensureBudget, saveUsage, UsageMeter } from "../_shared/budget.ts";
import {
  addDays,
  ASSISTANT_SCHEMA,
  type AssistantResult,
  dayKey,
  type MessageRow,
  type PlanRow,
  type RecipeRow,
  type ShoppingRow,
  systemPrompt,
  userPrompt,
  validActions,
} from "./prompt.ts";

const HISTORY = 30;

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return error(405, "Nur POST.");
    let body: { text?: unknown };
    try {
      body = await req.json();
    } catch {
      return error(400, "Ungültige Anfrage.");
    }
    const text = typeof body.text === "string" ? body.text.trim().slice(0, 2000) : "";
    if (!text) return error(400, "Was möchtest du nomi sagen?");
    const userId = ctx.userClaims?.id;
    if (!userId) return error(401, "Bitte melde dich an.");

    try {
      return await reply(ctx.supabase, ctx.supabaseAdmin, userId, text);
    } catch (e) {
      if (e instanceof BudgetExceeded) return budgetResponse(e);
      console.error("assistant failed", e);
      if (e instanceof Anthropic.RateLimitError) {
        return error(503, "nomi ist gerade ausgelastet. Probier es in einer Minute noch mal.");
      }
      if (e instanceof Anthropic.AnthropicError || e instanceof ClaudeError || e instanceof SyntaxError) {
        return error(502, "nomi hat dich gerade nicht verstanden. Probier es gleich noch mal.");
      }
      throw e;
    }
  }),
};

// deno-lint-ignore no-explicit-any
type Client = any;

/// `admin` nur für nomis Antwort (user_id null). Alles andere läuft über den RLS-Client der Person.
async function reply(supabase: Client, admin: Client, userId: string, text: string): Promise<Response> {
  const { data: membership } = await supabase
    .from("household_members").select("household_id").eq("user_id", userId).maybeSingle();
  if (!membership) return error(403, "Du bist noch in keinem Haushalt.");
  const householdId: string = membership.household_id;
  // Kostenbremse vor dem Speichern der Nachricht: Ist das Budget weg, bleibt der Verlauf unverändert
  await ensureBudget(admin, householdId);
  const meter = new UsageMeter();

  const { data: userMessage, error: insertError } = await supabase
    .from("assistant_messages").insert({ household_id: householdId, content: text }).select().single();
  if (insertError) throw insertError;

  try {
    return await answer({ supabase, admin, userId, householdId, userMessage, meter });
  } finally {
    await saveUsage(admin, { householdId, userId, fn: "assistant", meter });
  }
}

async function answer(
  { supabase, admin, userId, householdId, userMessage, meter }:
    { supabase: Client; admin: Client; userId: string; householdId: string; userMessage: unknown; meter: UsageMeter },
): Promise<Response> {
  const now = new Date();
  const today = dayKey(now);
  const [members, recipes, cooked, plan, shopping, staples, history] = await Promise.all([
    supabase.from("household_members").select("user_id, display_name").eq("household_id", householdId),
    supabase.from("recipes").select("id, title, total_minutes, tags, dish_type, diet")
      .eq("household_id", householdId).order("created_at", { ascending: false }).limit(300),
    supabase.from("cooking_log").select("recipe_id, cooked_on").eq("household_id", householdId)
      .order("cooked_on", { ascending: false }).limit(500),
    supabase.from("meal_plan_entries").select("day, recipe_id, servings, note, meal").eq("household_id", householdId)
      .gte("day", addDays(today, -7)).lte("day", addDays(today, 21)).order("day").order("position"),
    supabase.from("shopping_items").select("name, quantity, unit").eq("household_id", householdId).eq("checked", false),
    supabase.from("staple_items").select("name").eq("household_id", householdId).order("position"),
    supabase.from("assistant_messages").select("user_id, content, actions, result").eq("household_id", householdId)
      .order("created_at", { ascending: false }).limit(HISTORY),
  ]);
  for (const result of [members, recipes, cooked, plan, shopping, staples, history]) {
    if (result.error) throw result.error;
  }

  const names = new Map<string, string>(members.data.map((m: { user_id: string; display_name: string }) => [m.user_id, m.display_name]));
  const recipeRows = recipes.data as RecipeRow[];
  const lastCooked = new Map<string, string>();
  for (const row of cooked.data as { recipe_id: string; cooked_on: string }[]) {
    if (!lastCooked.has(row.recipe_id)) lastCooked.set(row.recipe_id, row.cooked_on);
  }

  const result = await structured<AssistantResult>({
    system: systemPrompt([...names.values()]),
    user: userPrompt({
      now,
      speaker: names.get(userId) ?? "Jemand",
      names,
      recipes: recipeRows,
      lastCooked,
      plan: plan.data as PlanRow[],
      shopping: shopping.data as ShoppingRow[],
      staples: (staples.data as { name: string }[]).map((s) => s.name),
      // Neueste zuerst geladen, für den Prompt chronologisch
      messages: (history.data as MessageRow[]).reverse(),
    }),
    schema: ASSISTANT_SCHEMA,
    meter,
  });

  const actions = validActions(result, new Set(recipeRows.map((r) => r.id)), today);

  // Neue Gerichte gleich ausarbeiten (parallel), damit die App sie wie jedes Rezept einplanen kann
  if (actions?.plan) {
    actions.plan = (await Promise.all(actions.plan.map(async (entry) => {
      if (entry.recipe_id || !entry.idea) return entry;
      try {
        const saved = await expandIdea(supabase, householdId, entry.idea, entry.servings, meter);
        return { ...entry, recipe_id: saved.id as string, idea: null };
      } catch (e) {
        console.error("expand failed", entry.idea.title, e);
        return null;
      }
    }))).filter((entry) => entry !== null);
    if (!actions.plan.length) actions.plan = null;
  }

  const { data: message, error: replyError } = await admin.from("assistant_messages").insert({
    household_id: householdId,
    user_id: null,
    content: result.reply.trim(),
    actions,
  }).select().single();
  if (replyError) throw replyError;

  return Response.json({ user_message: userMessage, message });
}

function error(status: number, message: string) {
  return Response.json({ error: message }, { status });
}
