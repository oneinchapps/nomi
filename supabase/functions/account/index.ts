// Konto löschen – Apple verlangt das bei jeder App mit Kontoerstellung.
//
// POST { action: "delete" } → { deleted: true }
//   1. Eigene Chat-Nachrichten löschen (sonst sähen sie ohne Absender wie Antworten von nomi aus)
//   2. Eigenes Profilfoto löschen
//   3. War die Person allein im Haushalt: den ganzen Haushalt löschen – Daten per Cascade,
//      dazu Rezept- und Profilfotos im Speicher. Sonst bleibt der Haushalt für die anderen.
//   4. Anmeldekonto löschen

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";

export default {
  fetch: withSupabase({ auth: "user" }, async (req, ctx) => {
    if (req.method !== "POST") return error(405, "Nur POST.");
    let body: { action?: unknown };
    try {
      body = await req.json();
    } catch {
      return error(400, "Ungültige Anfrage.");
    }
    if (body.action !== "delete") return error(400, "Unbekannte Aktion.");
    const userId = ctx.userClaims?.id;
    if (!userId) return error(401, "Bitte melde dich an.");

    try {
      await deleteAccount(ctx.supabaseAdmin, userId);
      return Response.json({ deleted: true });
    } catch (e) {
      console.error("delete account failed", e);
      return error(500, "Das Konto ließ sich gerade nicht löschen. Probier es gleich noch mal.");
    }
  }),
};

// deno-lint-ignore no-explicit-any
type Client = any;

async function deleteAccount(admin: Client, userId: string) {
  const { data: membership } = await admin
    .from("household_members").select("household_id").eq("user_id", userId).maybeSingle();
  const householdId: string | null = membership?.household_id ?? null;

  for (const table of ["assistant_messages", "chat_messages"]) {
    const { error } = await admin.from(table).delete().eq("user_id", userId);
    if (error) throw error;
  }

  if (householdId) {
    await removeFolder(admin, "avatars", `${householdId}/${userId}`);
    const { count, error } = await admin
      .from("household_members").select("user_id", { count: "exact", head: true })
      .eq("household_id", householdId).neq("user_id", userId);
    if (error) throw error;
    if (!count) {
      // Allein im Haushalt: alles weg, auch die Fotos im Speicher
      await removeFolder(admin, "recipe-images", householdId);
      const { error: deleteError } = await admin.from("households").delete().eq("id", householdId);
      if (deleteError) throw deleteError;
    }
  }

  // Mitgliedschaft, Stimmen usw. hängen per Cascade am Konto
  const { error } = await admin.auth.admin.deleteUser(userId);
  if (error) throw error;
}

/** Löscht alle Dateien unter einem Ordner (eine Ebene tief, wie es die App anlegt). */
async function removeFolder(admin: Client, bucket: string, folder: string) {
  const storage = admin.storage.from(bucket);
  for (;;) {
    const { data, error } = await storage.list(folder, { limit: 100 });
    if (error) throw error;
    const files = (data ?? []).filter((entry: { id: string | null }) => entry.id).map((entry: { name: string }) => `${folder}/${entry.name}`);
    if (!files.length) return;
    const { error: removeError } = await storage.remove(files);
    if (removeError) throw removeError;
  }
}

function error(status: number, message: string) {
  return Response.json({ error: message }, { status });
}
