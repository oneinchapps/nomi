// Kostenbremse für Claude: Verbrauch messen, Tagesbudget prüfen, Verbrauch speichern.
//
// Ablauf in jeder Function:
//   await ensureBudget(admin, householdId)          // vor der ersten Claude-Anfrage
//   const meter = new UsageMeter()                   // an structured() durchreichen
//   …
//   await saveUsage(admin, { householdId, userId, fn: "assistant", meter })
//
// Budgets per Function-Secret, sonst die Standardwerte unten:
//   AI_BUDGET_HOUSEHOLD_DAILY_USD – pro Haushalt und Tag
//   AI_BUDGET_TOTAL_DAILY_USD     – alle Haushalte zusammen pro Tag

import type Anthropic from "@anthropic-ai/sdk";

export const MODEL = "claude-opus-5-5";

/** Preise von Claude Opus 5.5 in Millionstel Dollar pro Token (= $ pro Million Tokens) */
const PRICE = { input: 4, output: 20, cacheRead: 0.2 };

const DEFAULT_HOUSEHOLD_DAILY_USD = 2;
const DEFAULT_TOTAL_DAILY_USD = 10;

/** Sammelt den Verbrauch aller Claude-Anfragen einer Function-Anfrage (auch parallele). */
export class UsageMeter {
  calls = 0;
  inputTokens = 0;
  outputTokens = 0;
  cacheReadTokens = 0;

  record(usage: Anthropic.Beta.BetaUsage | null | undefined) {
    if (!usage) return;
    this.calls += 1;
    this.inputTokens += (usage.input_tokens ?? 0) + (usage.cache_creation_input_tokens ?? 0);
    this.outputTokens += usage.output_tokens ?? 0;
    this.cacheReadTokens += usage.cache_read_input_tokens ?? 0;
  }

  get costMicros(): number {
    return Math.ceil(
      this.inputTokens * PRICE.input + this.outputTokens * PRICE.output + this.cacheReadTokens * PRICE.cacheRead,
    );
  }
}

export class BudgetExceeded extends Error {
  constructor(readonly scope: "household" | "total") {
    super(`budget exceeded: ${scope}`);
  }
}

export interface Limits {
  householdMicros: number;
  totalMicros: number;
}

function usd(name: string, fallback: number): number {
  const value = Number(Deno.env.get(name));
  return Number.isFinite(value) && value > 0 ? value : fallback;
}

export function limits(): Limits {
  return {
    householdMicros: Math.round(usd("AI_BUDGET_HOUSEHOLD_DAILY_USD", DEFAULT_HOUSEHOLD_DAILY_USD) * 1_000_000),
    totalMicros: Math.round(usd("AI_BUDGET_TOTAL_DAILY_USD", DEFAULT_TOTAL_DAILY_USD) * 1_000_000),
  };
}

/** Reine Entscheidung, damit testbar: null = noch Budget übrig */
export function exceeded(spent: { household: number; total: number }, limit: Limits): "household" | "total" | null {
  if (spent.total >= limit.totalMicros) return "total";
  if (spent.household >= limit.householdMicros) return "household";
  return null;
}

// deno-lint-ignore no-explicit-any
type Client = any;

/** Wirft BudgetExceeded, wenn das Tagesbudget des Haushalts oder insgesamt aufgebraucht ist. */
export async function ensureBudget(admin: Client, householdId: string): Promise<void> {
  const { data, error } = await admin.rpc("ai_spend_today", { household: householdId }).single();
  if (error) throw error;
  const scope = exceeded({ household: Number(data.household_micros), total: Number(data.total_micros) }, limits());
  if (scope) throw new BudgetExceeded(scope);
}

/** Speichert den gemessenen Verbrauch. Fehler hier dürfen die eigentliche Antwort nicht kaputt machen. */
export async function saveUsage(
  admin: Client,
  entry: { householdId: string | null; userId: string | null; fn: string; meter: UsageMeter },
): Promise<void> {
  if (entry.meter.calls === 0) return;
  const { error } = await admin.from("ai_usage").insert({
    household_id: entry.householdId,
    user_id: entry.userId,
    function: entry.fn,
    model: MODEL,
    calls: entry.meter.calls,
    input_tokens: entry.meter.inputTokens,
    output_tokens: entry.meter.outputTokens,
    cache_read_tokens: entry.meter.cacheReadTokens,
    cost_micros: entry.meter.costMicros,
  });
  if (error) console.error("saveUsage failed", error);
}

/** Einheitliche, freundliche Antwort für die App (429) */
export function budgetResponse(e: BudgetExceeded): Response {
  const message = e.scope === "household"
    ? "nomi hat für heute genug gekocht: Euer Tageslimit für KI-Anfragen ist erreicht. Morgen geht's weiter."
    : "nomi macht für heute Pause: Das Tageslimit für KI-Anfragen ist erreicht. Morgen geht's weiter.";
  return Response.json({ error: message }, { status: 429 });
}
