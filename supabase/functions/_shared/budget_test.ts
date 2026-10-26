import { assertEquals } from "jsr:@std/assert@1";
import { exceeded, UsageMeter } from "./budget.ts";

Deno.test("Kosten aus Tokens: Opus 5.5 kostet 4 $ / 20 $ pro Million Tokens", () => {
  const meter = new UsageMeter();
  meter.record({ input_tokens: 10_000, output_tokens: 1_000, cache_read_input_tokens: 0, cache_creation_input_tokens: 0 } as never);
  meter.record({ input_tokens: 5_000, output_tokens: 500 } as never)
  assertEquals(meter.calls, 2);
  // 15.000 × 4 + 1.500 × 20 = 90.000 Millionstel Dollar = 0,09 $
  assertEquals(meter.costMicros, 90_000);
});

Deno.test("Ohne Anfrage keine Kosten", () => {
  const meter = new UsageMeter();
  meter.record(undefined);
  assertEquals(meter.calls, 0);
  assertEquals(meter.costMicros, 0);
});

Deno.test("Budget: Haushalt und gesamt, gesamt hat Vorrang", () => {
  const limit = { householdMicros: 2_000_000, totalMicros: 10_000_000 };
  assertEquals(exceeded({ household: 1_999_999, total: 5_000_000 }, limit), null);
  assertEquals(exceeded({ household: 2_000_000, total: 5_000_000 }, limit), "household");
  assertEquals(exceeded({ household: 100, total: 10_000_000 }, limit), "total");
  assertEquals(exceeded({ household: 3_000_000, total: 12_000_000 }, limit), "total");
});
