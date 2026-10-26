// Einladung einlösen: Die zweite Person meldet sich mit einem Einmal-Code an, ganz ohne E-Mail.
//
// POST { code, display_name } → { token_hash }
//   Legt ein Konto ohne echte Mailadresse an, fügt es dem Haushalt hinzu und gibt einen
//   Magic-Link-Token zurück, den die App per verifyOTP in eine Sitzung tauscht.
//   Gehört der Code zu einem bestehenden Mitglied (member_id), wird nur dieses angemeldet –
//   so kommt man auf einem neuen Handy wieder in sein Konto.
//
// Codes legt die App über die RPC create_invite() an. Ein Code gilt einmal und 7 Tage.
// Ausnahme: wiederverwendbare Codes (reusable) für den Demo-Zugang der App-Prüfung – sie führen
// immer in dasselbe Konto und werden nicht verbraucht (siehe scripts/setup-demo.sh).

import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { cleanName, INVITED_DOMAIN, normalizeCode } from "./code.ts";

type Invite = { code: string; household_id: string; member_id: string | null; created_by: string | null; expires_at: string };

export default {
  // Öffentlich: Wer einlöst, hat noch kein Konto. Der Code selbst ist der Nachweis.
  fetch: withSupabase({ auth: "none" }, async (req, ctx) => {
    if (req.method !== "POST") return error(405, "Nur POST.");
    let body: { code?: unknown; display_name?: unknown };
    try {
      body = await req.json();
    } catch {
      return error(400, "Ungültige Anfrage.");
    }
    const code = normalizeCode(body.code);
    if (!code) return error(400, "Der Code hat 8 Zeichen.");

    const admin = ctx.supabaseAdmin;
    // Einmal-Codes sofort verbrauchen, damit derselbe Code nicht zweimal eingelöst wird
    const now = new Date().toISOString();
    const { data: consumed, error: consumeError } = await admin
      .from("household_invites")
      .delete()
      .eq("code", code)
      .eq("reusable", false)
      .gt("expires_at", now)
      .select()
      .maybeSingle();
    if (consumeError) throw consumeError;
    let invite = consumed;
    if (!invite) {
      const { data: reusable } = await admin
        .from("household_invites").select().eq("code", code).eq("reusable", true).gt("expires_at", now).maybeSingle();
      invite = reusable;
    }
    if (!invite) return error(404, "Diesen Code gibt es nicht oder er ist abgelaufen. Lass dir einen neuen schicken.");

    try {
      const email = invite.member_id
        ? await memberEmail(admin, invite as Invite)
        : await createMember(admin, invite as Invite, cleanName(body.display_name));

      const { data: link, error: linkError } = await admin.auth.admin.generateLink({ type: "magiclink", email });
      if (linkError) throw linkError;
      return Response.json({ token_hash: link.properties.hashed_token });
    } catch (e) {
      // Einmal-Code zurücklegen, damit ein zweiter Versuch klappt
      if (consumed) await admin.from("household_invites").insert(consumed);
      if (e instanceof InviteError) return error(e.status, e.message);
      console.error("redeem failed", e);
      return error(500, "Das hat nicht geklappt. Probier es gleich noch mal.");
    }
  }),
};

// deno-lint-ignore no-explicit-any
type Client = any;

class InviteError extends Error {
  constructor(readonly status: number, message: string) {
    super(message);
  }
}

async function memberEmail(admin: Client, invite: Invite): Promise<string> {
  const { data, error: userError } = await admin.auth.admin.getUserById(invite.member_id);
  if (userError || !data.user?.email?.endsWith(`@${INVITED_DOMAIN}`)) {
    throw new InviteError(404, "Dieses Konto gibt es nicht mehr. Lass dir eine neue Einladung schicken.");
  }
  return data.user.email;
}

async function createMember(admin: Client, invite: Invite, name: string | null): Promise<string> {
  if (!name) throw new InviteError(400, "Wie heißt du?");
  const email = `${crypto.randomUUID()}@${INVITED_DOMAIN}`;
  const { data, error: createError } = await admin.auth.admin.createUser({
    email,
    email_confirm: true,
    user_metadata: { display_name: name, invited_by: invite.created_by },
  });
  if (createError) throw createError;

  const { error: memberError } = await admin
    .from("household_members")
    .insert({ household_id: invite.household_id, user_id: data.user.id, display_name: name });
  if (memberError) {
    await admin.auth.admin.deleteUser(data.user.id);
    throw memberError;
  }
  return email;
}

function error(status: number, message: string) {
  return Response.json({ error: message }, { status });
}
