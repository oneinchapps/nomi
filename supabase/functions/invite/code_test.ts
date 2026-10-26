import { assertEquals } from "jsr:@std/assert@1";
import { cleanName, normalizeCode } from "./code.ts";

Deno.test("Code wird normalisiert, falsche Länge abgelehnt", () => {
  assertEquals(normalizeCode("abcd-efgh"), "ABCDEFGH");
  assertEquals(normalizeCode(" ABCD EFGH\n"), "ABCDEFGH");
  assertEquals(normalizeCode("ABC123"), null);
  assertEquals(normalizeCode(42), null);
});

Deno.test("Name wird bereinigt", () => {
  assertEquals(cleanName("  Sam   Lee "), "Sam Lee");
  assertEquals(cleanName("   "), null);
  assertEquals(cleanName(undefined), null);
});
