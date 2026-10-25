// Rezept aus einem geteilten Link (Blog, Instagram, TikTok) auslesen.
//
// POST { url: string, text?: string, save?: boolean }
// → { recipe: Recipe, found_recipe: boolean, saved: boolean }
//
// `recipe` hat das Format der Tabelle public.recipes und lässt sich in der App direkt als Recipe dekodieren.
// Mit save=true wird es sofort gespeichert (Teilen-Erweiterung), sonst nur zurückgegeben (Editor in der App).

import "@supabase/functions-js/edge-runtime.d.ts";
import Anthropic from "@anthropic-ai/sdk";
import { withSupabase } from "@supabase/server";
import type { SupabaseClient } from "npm:@supabase/supabase-js@2";
import { assertPublicURL, scrape } from "./scrape.ts";
import { ExtractionError, extractRecipe } from "./extract.ts";

const BUCKET = "recipe-images";
const MAX_IMAGE_BYTES = 5 * 1024 * 1024;
const IMAGE_TYPES: Record<string, string> = {
  "image/jpeg": "jpg",
  "image/png": "png",
  "image/webp": "webp",
};

interface ImportRequest {
  url?: string;
  text?: string;
  save?: boolean;
}

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") {
      return error(405, "Nur POST.");
    }
    const userId = ctx.userClaims?.id;
    if (!userId) return error(401, "Nicht angemeldet.");

    let body: ImportRequest;
    try {
      body = await req.json();
    } catch {
      return error(400, "Ungültige Anfrage.");
    }
    const sharedText = body.text?.trim() || null;
    const rawURL = body.url?.trim() || firstURL(sharedText);
    if (!rawURL) return error(400, "Kein Link gefunden.");

    const { data: membership } = await ctx.supabase
      .from("household_members")
      .select("household_id")
      .eq("user_id", userId)
      .maybeSingle();
    if (!membership) return error(403, "Kein Haushalt.");
    const householdId: string = membership.household_id;

    // 1. Seite laden
    let page;
    try {
      page = await scrape(rawURL);
    } catch (e) {
      console.error("scrape failed", rawURL, e);
      if (!sharedText) {
        return error(422, "Die Seite ließ sich nicht öffnen. Kopier den Rezepttext und füg ihn ein.");
      }
      // Ohne Seite, aber mit mitgeschicktem Text (z. B. kopierte Caption) geht es trotzdem
      page = {
        url: rawURL,
        platform: "web" as const,
        title: null,
        description: null,
        imageURL: null,
        recipeJSON: null,
        text: null,
      };
    }

    // 2. Rezept auslesen
    let extracted;
    try {
      extracted = await extractRecipe(page, sharedText);
    } catch (e) {
      console.error("extract failed", e);
      if (e instanceof Anthropic.RateLimitError) {
        return error(503, "nomnom ist gerade ausgelastet. Probier es in einer Minute noch mal.");
      }
      if (e instanceof Anthropic.AnthropicError || e instanceof ExtractionError || e instanceof SyntaxError) {
        return error(502, "Das Rezept ließ sich nicht auslesen.");
      }
      throw e;
    }

    // 3. Bild in den eigenen Speicher kopieren – Instagram/TikTok-Bildlinks laufen nach Tagen ab
    const imageURL = page.imageURL ? await copyImage(ctx.supabase, householdId, page.imageURL) : null;

    const recipe = {
      id: crypto.randomUUID(),
      household_id: householdId,
      title: extracted.title.trim() || "Neues Rezept",
      summary: extracted.summary,
      source: page.platform,
      source_url: page.url,
      image_url: imageURL,
      total_minutes: extracted.total_minutes && extracted.total_minutes > 0 ? extracted.total_minutes : null,
      servings: extracted.servings > 0 ? extracted.servings : 2,
      ingredients: extracted.ingredients,
      steps: extracted.steps,
      tags: extracted.tags,
    };

    let saved = false;
    if (body.save) {
      const { error: insertError } = await ctx.supabase.from("recipes").insert(recipe);
      if (insertError) {
        console.error("insert failed", insertError);
        return error(500, "Speichern hat nicht geklappt.");
      }
      saved = true;
    }

    return Response.json({ recipe, found_recipe: extracted.found_recipe, saved });
  }),
};

function error(status: number, message: string) {
  return Response.json({ error: message }, { status });
}

function firstURL(text: string | null): string | null {
  return text?.match(/https?:\/\/\S+/)?.[0] ?? null;
}

async function copyImage(supabase: SupabaseClient, householdId: string, source: string): Promise<string | null> {
  try {
    const url = assertPublicURL(source);
    const response = await fetch(url, { signal: AbortSignal.timeout(15_000) });
    const type = response.headers.get("content-type")?.split(";")[0].trim() ?? "";
    const ext = IMAGE_TYPES[type];
    const size = Number(response.headers.get("content-length") ?? 0);
    if (!response.ok || !ext || size > MAX_IMAGE_BYTES) {
      await response.body?.cancel();
      return null;
    }
    const bytes = new Uint8Array(await response.arrayBuffer());
    if (bytes.byteLength > MAX_IMAGE_BYTES) return null;

    const path = `${householdId}/${crypto.randomUUID()}.${ext}`;
    const { error: uploadError } = await supabase.storage
      .from(BUCKET)
      .upload(path, bytes, { contentType: type, cacheControl: "31536000" });
    if (uploadError) {
      console.error("image upload failed", uploadError);
      return null;
    }
    return supabase.storage.from(BUCKET).getPublicUrl(path).data.publicUrl;
  } catch (e) {
    console.error("image copy failed", source, e);
    return null;
  }
}
