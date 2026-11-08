// Fragen beim Kochen („Hey nomi, kann ich statt Sahne Milch nehmen?“). Reine Funktionen ohne Netzwerk – damit testbar.
//
// Die App schickt das Rezept so mit, wie es gerade gekocht wird (Mengen schon auf die Portionen
// umgerechnet), dazu den aktuellen Schritt. Die Antwort wird vorgelesen, darum kurz und ohne Markdown.
// Fragen und Antworten landen nicht im gemeinsamen Verlauf mit nomi – sie gelten nur für den Moment am Herd.

export interface CookingRequest {
  question: string;
  title: string;
  servings: number;
  ingredients: string[];
  steps: string[];
  /** 0 = Vorbereitung, 1…n = Schritt, n+1 = fertig */
  step: number;
}

export interface CookingResult {
  reply: string;
}

export const COOKING_SCHEMA = {
  type: "object",
  additionalProperties: false,
  required: ["reply"],
  properties: { reply: { type: "string" } },
};

const text = (value: unknown, max: number) => typeof value === "string" ? value.trim().slice(0, max) : "";
const lines = (value: unknown, count: number, max: number) =>
  Array.isArray(value) ? value.map((line) => text(line, max)).filter(Boolean).slice(0, count) : [];

/** Prüft und kürzt, was die App schickt. null = unbrauchbar. */
export function parseCookingRequest(body: Record<string, unknown>): CookingRequest | null {
  const question = text(body.text, 500);
  const recipe = (body.recipe ?? {}) as Record<string, unknown>;
  const title = text(recipe.title, 200);
  if (!question || !title) return null;
  const servings = Number(recipe.servings);
  const step = Number(body.step);
  return {
    question,
    title,
    servings: Number.isInteger(servings) && servings > 0 && servings <= 100 ? servings : 2,
    ingredients: lines(recipe.ingredients, 80, 200),
    steps: lines(recipe.steps, 60, 1500),
    step: Number.isInteger(step) && step >= 0 ? step : 0,
  };
}

export function cookingSystemPrompt(): string {
  return `Du bist nomi und stehst gerade mit jemandem in der Küche. Die Person kocht nach einem Rezept, hat die Hände voll und fragt dich per Sprache. Deine Antwort wird vorgelesen.

So antwortest du (reply):
- Deutsch, locker, per Du, ohne Markdown, ohne Aufzählungszeichen, ohne Emojis.
- Sehr kurz: höchstens zwei kurze Sätze, zusammen unter 30 Wörtern. Erst die Antwort, dann höchstens ein Tipp. Lieber knapp als vollständig – wer mehr wissen will, fragt nach.
- Mengen und Zeiten so, wie man sie spricht („zwei Esslöffel“, „etwa fünf Minuten“).
- Beziehe dich auf das Rezept und den aktuellen Schritt. Die Mengen im Rezept sind schon auf die Portionen umgerechnet.
- Bei Ersatz-Zutaten: sag, ob es geht und was sich ändert.
- Bei Fragen zur Lebensmittelsicherheit (z. B. Geflügel, Eier, Reste) bist du vorsichtig und nennst die sichere Variante.
- Geht es gar nicht ums Kochen, antworte freundlich in einem Satz und lenk zurück zum Rezept.`;
}

export function cookingUserPrompt(request: CookingRequest): string {
  const { title, servings, ingredients, steps, step } = request;
  const where = step === 0
    ? "Gerade: Vorbereitung (Zutaten bereitstellen)."
    : step > steps.length
    ? "Gerade: Alle Schritte sind erledigt."
    : `Gerade: Schritt ${step} von ${steps.length}.`;
  return [
    `Rezept: ${title} (für ${servings} ${servings === 1 ? "Portion" : "Portionen"})`,
    "",
    "Zutaten:",
    ...(ingredients.length ? ingredients.map((line) => `- ${line}`) : ["- (keine angegeben)"]),
    "",
    "Schritte:",
    ...(steps.length ? steps.map((line, index) => `${index + 1}. ${line}`) : ["(keine angegeben)"]),
    "",
    where,
    "",
    `Frage: ${request.question}`,
  ].join("\n");
}
