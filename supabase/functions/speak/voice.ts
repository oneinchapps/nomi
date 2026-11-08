// Sprachausgabe über ElevenLabs – reine Funktionen ohne Netzwerk, damit testbar.
//
// Secrets:
//   ELEVENLABS_API_KEY   – Pflicht
//   ELEVENLABS_VOICE_ID  – sonst Ben (deutsche Bibliotheksstimme, jung und locker – gewählt nach Hörprobe)
//   ELEVENLABS_MODEL     – sonst eleven_v4_turbo (für Echtzeit gedacht, kurze Wartezeit)
//   ELEVENLABS_USD_PER_1K_CHARS – Preis fürs Kostenprotokoll, sonst 0,05 $

export const DEFAULT_MODEL = "eleven_v4_turbo";
/** „Ben – Effortless and Casual“ aus der ElevenLabs-Bibliothek */
export const DEFAULT_VOICE_ID = "aTTiK3YzK3dXETpuDE2h";
const DEFAULT_USD_PER_1K_CHARS = 0.05;
/** Längster Text: ein langer Rezeptschritt passt, ein ganzer Roman nicht */
export const MAX_CHARS = 1500;
/** Klein, aber klar genug für Sprache – spart Daten und Wartezeit */
export const OUTPUT_FORMAT = "mp3_44100_64";

export interface VoiceConfig {
  apiKey: string;
  voiceId: string;
  model: string;
  usdPer1kChars: number;
}

/** null = nicht eingerichtet; die App liest dann mit der Stimme des Geräts vor */
export function voiceConfig(env: (name: string) => string | undefined): VoiceConfig | null {
  const apiKey = env("ELEVENLABS_API_KEY")?.trim();
  if (!apiKey) return null;
  const voiceId = env("ELEVENLABS_VOICE_ID")?.trim() || DEFAULT_VOICE_ID;
  const price = Number(env("ELEVENLABS_USD_PER_1K_CHARS"));
  return {
    apiKey,
    voiceId,
    model: env("ELEVENLABS_MODEL")?.trim() || DEFAULT_MODEL,
    usdPer1kChars: Number.isFinite(price) && price > 0 ? price : DEFAULT_USD_PER_1K_CHARS,
  };
}

/** Text so, wie er gesprochen werden soll: ohne Markdown-Reste, Leerraum zusammengefasst, gekürzt. */
export function speakableText(value: unknown): string {
  if (typeof value !== "string") return "";
  const cleaned = value
    .replace(/[*_#`>~|]+/g, " ")
    .replace(/\s+/g, " ")
    .trim();
  if (cleaned.length <= MAX_CHARS) return cleaned;
  // Am Satzende kürzen, damit nicht mitten im Wort abgebrochen wird
  const cut = cleaned.slice(0, MAX_CHARS);
  const end = Math.max(cut.lastIndexOf(". "), cut.lastIndexOf("! "), cut.lastIndexOf("? "));
  return (end > MAX_CHARS / 2 ? cut.slice(0, end + 1) : cut).trim();
}

/** Kosten in Millionstel Dollar – abgerechnet wird nach Zeichen */
export function costMicros(text: string, config: Pick<VoiceConfig, "usdPer1kChars">): number {
  return Math.ceil(text.length * config.usdPer1kChars * 1000);
}

export function elevenLabsRequest(text: string, config: VoiceConfig): { url: string; init: RequestInit } {
  const url = `https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(config.voiceId)}` +
    `?output_format=${OUTPUT_FORMAT}`;
  return {
    url,
    init: {
      method: "POST",
      headers: { "xi-api-key": config.apiKey, "content-type": "application/json", accept: "audio/mpeg" },
      body: JSON.stringify({ text, model_id: config.model, language_code: "de" }),
    },
  };
}
