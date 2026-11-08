// nomi spricht: Text → Sprache über ElevenLabs. Der Schlüssel bleibt hier, die App bekommt nur das Audio.
//
// POST { text } → audio/mpeg
//   503, wenn ElevenLabs nicht eingerichtet ist – die App liest dann mit der Stimme des Geräts vor.
//   429 bei aufgebrauchtem Tagesbudget (dieselbe Kostenbremse wie für Claude, Protokoll als „speak“).

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { BudgetExceeded, budgetResponse, ensureBudget, saveSpend } from "../_shared/budget.ts";
import { costMicros, elevenLabsRequest, speakableText, voiceConfig } from "./voice.ts";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return error(405, "Nur POST.");
    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return error(400, "Ungültige Anfrage.");
    }
    const text = speakableText(body.text);
    if (!text) return error(400, "Was soll nomi sagen?");
    const userId = ctx.userClaims?.id;
    if (!userId) return error(401, "Bitte melde dich an.");
    const config = voiceConfig((name) => Deno.env.get(name));
    if (!config) return error(503, "Die Stimme von nomi ist nicht eingerichtet.");

    const { data: membership } = await ctx.supabase
      .from("household_members").select("household_id").eq("user_id", userId).maybeSingle();
    if (!membership) return error(403, "Du bist noch in keinem Haushalt.");
    const householdId: string = membership.household_id;

    try {
      await ensureBudget(ctx.supabaseAdmin, householdId);
    } catch (e) {
      if (e instanceof BudgetExceeded) return budgetResponse(e);
      throw e;
    }

    const { url, init } = elevenLabsRequest(text, config);
    const response = await fetch(url, init);
    if (!response.ok || !response.body) {
      console.error("elevenlabs failed", response.status, await response.text().catch(() => ""));
      return error(502, "nomi hat gerade keine Stimme.");
    }
    // Abgerechnet wird, sobald ElevenLabs liefert – das Audio geht direkt durch an die App
    await saveSpend(ctx.supabaseAdmin, {
      householdId,
      userId,
      fn: "speak",
      model: `elevenlabs:${config.model}`,
      calls: 1,
      inputTokens: text.length,
      costMicros: costMicros(text, config),
    });
    return new Response(response.body, {
      headers: { "content-type": "audio/mpeg", "x-nomi-voice": `${config.voiceId}:${config.model}` },
    });
  }),
};

function error(status: number, message: string): Response {
  return Response.json({ error: message }, { status });
}
