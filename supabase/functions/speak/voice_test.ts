import { assertEquals } from "jsr:@std/assert@1";
import { costMicros, DEFAULT_MODEL, DEFAULT_VOICE_ID, elevenLabsRequest, MAX_CHARS, speakableText, voiceConfig } from "./voice.ts";

Deno.test("ohne Schlüssel ist nichts eingerichtet, die Stimme hat einen Standard", () => {
  assertEquals(voiceConfig(() => undefined), null);
  assertEquals(voiceConfig((n) => (n === "ELEVENLABS_API_KEY" ? "k" : undefined))?.voiceId, DEFAULT_VOICE_ID);
  const config = voiceConfig((n) => ({ ELEVENLABS_API_KEY: "k", ELEVENLABS_VOICE_ID: "v" } as Record<string, string>)[n]);
  assertEquals(config, { apiKey: "k", voiceId: "v", model: DEFAULT_MODEL, usdPer1kChars: 0.05 });
});

Deno.test("Text wird gesäubert und am Satzende gekürzt", () => {
  assertEquals(speakableText("  **Schritt 1:**\n\nZwiebeln   würfeln. "), "Schritt 1: Zwiebeln würfeln.");
  assertEquals(speakableText(42), "");
  const long = "Rühren. ".repeat(400);
  const cut = speakableText(long);
  assertEquals(cut.length <= MAX_CHARS, true);
  assertEquals(cut.endsWith("Rühren."), true);
});

Deno.test("Kosten nach Zeichen in Millionstel Dollar", () => {
  // 1000 Zeichen zu 0,05 $ = 50.000 Millionstel
  assertEquals(costMicros("x".repeat(1000), { usdPer1kChars: 0.05 }), 50_000);
  assertEquals(costMicros("Hallo", { usdPer1kChars: 0.05 }), 250);
});

Deno.test("Anfrage an ElevenLabs", () => {
  const { url, init } = elevenLabsRequest("Hallo", { apiKey: "k", voiceId: "a b", model: "m", usdPer1kChars: 0.05 });
  assertEquals(url, "https://api.elevenlabs.io/v1/text-to-speech/a%20b?output_format=mp3_44100_64");
  assertEquals((init.headers as Record<string, string>)["xi-api-key"], "k");
  assertEquals(JSON.parse(init.body as string), { text: "Hallo", model_id: "m", language_code: "de" });
});
