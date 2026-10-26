// Gemeinsam entscheiden: KI-Vorschläge für den Swipe-Stapel und Ausarbeiten einer Idee nach dem Match.
//
// POST { action: "suggest", session_id } → { reply, candidates }
//   Liest Chat, Sammlung und bisherige Stimmen, schreibt eine Antwort von nomi in chat_messages
//   und neue Karten in session_candidates.
// POST { action: "expand", candidate_id } → { recipe }
//   Macht aus einer KI-Idee ein vollständiges Rezept, speichert es in der Sammlung
//   und verknüpft die Karte damit (recipe_id statt ai_recipe).

import "@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "@anthropic-ai/sdk";
import { withSupabase } from "@supabase/server";
import { ClaudeError, type ExtractedRecipe, FULL_RECIPE_SCHEMA, structured } from "../_shared/recipe.ts";
import {
  type CandidateRow,
  EXPAND_SYSTEM,
  expandPrompt,
  type Idea,
  type MessageRow,
  type RecipeRow,
  SUGGEST_SCHEMA,
  sessionCourses,
  type SuggestResult,
  systemPrompt,
  userPrompt,
  validSuggestions,
  type VoteRow,
} from "./suggest.ts";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return error(405, "Nur POST.");
    let body: { action?: string; session_id?: string; candidate_id?: string };
    try {
      body = await req.json();
    } catch {
      return error(400, "Ungültige Anfrage.");
    }

    try {
      if (body.action === "suggest" && body.session_id) return await suggest(ctx.supabase, ctx.supabaseAdmin, body.session_id);
      if (body.action === "expand" && body.candidate_id) return await expand(ctx.supabase, body.candidate_id);
      return error(400, "Unbekannte Aktion.");
    } catch (e) {
      console.error(body.action, "failed", e);
      if (e instanceof Anthropic.RateLimitError) {
        return error(503, "nomi ist gerade ausgelastet. Probier es in einer Minute noch mal.");
      }
      if (e instanceof Anthropic.AnthropicError || e instanceof ClaudeError || e instanceof SyntaxError) {
        return error(502, "nomi hat gerade keine Idee. Probier es gleich noch mal.");
      }
      throw e;
    }
  }),
};

// deno-lint-ignore no-explicit-any
type Client = any;

/// `admin` nur für die Antwort von nomi (user_id null) – Nutzer:innen dürfen nur als sie selbst schreiben.
/// Die Zugehörigkeit zur Runde ist vorher über den RLS-Client geprüft.
async function suggest(supabase: Client, admin: Client, sessionId: string): Promise<Response> {
  // RLS sorgt dafür, dass nur Sessions des eigenen Haushalts sichtbar sind
  const { data: session } = await supabase
    .from("decide_sessions").select("id, household_id, status, courses").eq("id", sessionId).maybeSingle();
  if (!session) return error(404, "Diese Runde gibt es nicht.");
  if (session.status !== "open") return error(409, "Diese Runde ist schon entschieden.");
  const householdId: string = session.household_id;

  const [members, recipes, messages, candidates, votes] = await Promise.all([
    supabase.from("household_members").select("user_id, display_name").eq("household_id", householdId),
    supabase.from("recipes").select("id, title, summary, total_minutes, tags, ingredients")
      .eq("household_id", householdId).order("created_at", { ascending: false }).limit(300),
    supabase.from("chat_messages").select("user_id, content").eq("session_id", sessionId).order("created_at"),
    supabase.from("session_candidates").select("id, recipe_id, ai_recipe, course, position").eq("session_id", sessionId).order("position"),
    supabase.from("session_votes").select("candidate_id, user_id, liked").eq("session_id", sessionId),
  ]);
  for (const result of [members, recipes, messages, candidates, votes]) {
    if (result.error) throw result.error;
  }

  const names = new Map<string, string>(members.data.map((m: { user_id: string; display_name: string }) => [m.user_id, m.display_name]));
  const recipeRows = recipes.data as RecipeRow[];
  const candidateRows = candidates.data as (CandidateRow & { position: number })[];
  const voteRows = votes.data as VoteRow[];

  // Schon entschiedene Gänge: eine Karte des Gangs, die alle mögen
  const memberCount = Math.max(1, names.size);
  const titleOf = new Map(recipeRows.map((r) => [r.id, r.title]));
  const decided = new Map<string, string>();
  for (const c of candidateRows) {
    if (!c.course || decided.has(c.course)) continue;
    const likes = voteRows.filter((v) => v.candidate_id === c.id && v.liked).length;
    if (likes >= memberCount) decided.set(c.course, c.recipe_id ? titleOf.get(c.recipe_id) ?? "Rezept" : c.ai_recipe?.title ?? "Idee");
  }

  const result = await structured<SuggestResult>({
    system: systemPrompt([...names.values()]),
    user: userPrompt({
      now: new Date(),
      names,
      recipes: recipeRows,
      messages: messages.data as MessageRow[],
      candidates: candidateRows,
      votes: voteRows,
      courses: session.courses,
      decided,
    }),
    schema: SUGGEST_SCHEMA,
  });

  // Menü: Gangfolge einmal festlegen, danach bleibt sie für die Runde
  const courses = sessionCourses(session.courses, result.courses);
  if (courses && !session.courses?.length) {
    const { error: courseError } = await supabase.from("decide_sessions").update({ courses }).eq("id", sessionId);
    if (courseError) throw courseError;
  }

  const already = new Set<string>([
    ...candidateRows.flatMap((c) => (c.recipe_id ? [c.recipe_id] : [])),
    ...candidateRows.flatMap((c) => (c.ai_recipe ? [c.ai_recipe.title.trim().toLowerCase()] : [])),
  ]);
  const suggestions = validSuggestions(result, new Set(recipeRows.map((r) => r.id)), already, courses, new Set(decided.keys()));
  const nextPosition = candidateRows.reduce((max, c) => Math.max(max, c.position), -1) + 1;

  const { error: messageError } = await admin.from("chat_messages").insert({
    session_id: sessionId,
    household_id: householdId,
    user_id: null,
    content: result.reply.trim(),
  });
  if (messageError) throw messageError;

  let inserted: unknown[] = [];
  if (suggestions.length) {
    const { data, error: candidateError } = await supabase.from("session_candidates").insert(
      suggestions.map((s, index) => ({
        session_id: sessionId,
        household_id: householdId,
        recipe_id: s.recipe_id,
        ai_recipe: s.idea,
        reason: s.reason.trim(),
        course: s.course,
        position: nextPosition + index,
      })),
    ).select();
    if (candidateError) throw candidateError;
    inserted = data;
  }

  return Response.json({ reply: result.reply, candidates: inserted });
}

async function expand(supabase: Client, candidateId: string): Promise<Response> {
  const { data: candidate } = await supabase
    .from("session_candidates").select("id, household_id, recipe_id, ai_recipe").eq("id", candidateId).maybeSingle();
  if (!candidate) return error(404, "Diesen Vorschlag gibt es nicht.");

  // Schon ausgearbeitet (z. B. von der anderen Person) → vorhandenes Rezept zurückgeben
  if (candidate.recipe_id) {
    const { data: recipe } = await supabase.from("recipes").select().eq("id", candidate.recipe_id).maybeSingle();
    return Response.json({ recipe });
  }

  const idea = candidate.ai_recipe as Idea;
  const full = await structured<Omit<ExtractedRecipe, "found_recipe">>({
    system: EXPAND_SYSTEM,
    user: expandPrompt(idea, 2),
    schema: FULL_RECIPE_SCHEMA,
    effort: "medium",
  });

  const recipe = {
    id: crypto.randomUUID(),
    household_id: candidate.household_id,
    title: full.title.trim() || idea.title,
    summary: full.summary ?? idea.summary,
    source: "ai",
    source_url: null,
    image_url: null,
    total_minutes: full.total_minutes && full.total_minutes > 0 ? full.total_minutes : idea.total_minutes,
    servings: full.servings > 0 ? full.servings : 2,
    ingredients: full.ingredients,
    steps: full.steps,
    tags: full.tags,
    dish_type: full.dish_type,
    diet: full.diet,
  };
  const { data: saved, error: insertError } = await supabase.from("recipes").insert(recipe).select().single();
  if (insertError) throw insertError;

  const { error: linkError } = await supabase
    .from("session_candidates").update({ recipe_id: saved.id, ai_recipe: null }).eq("id", candidateId);
  if (linkError) throw linkError;

  return Response.json({ recipe: saved });
}

function error(status: number, message: string) {
  return Response.json({ error: message }, { status });
}
