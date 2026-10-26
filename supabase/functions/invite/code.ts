/// Konten aus Einladungen bekommen eine Adresse, an die nie eine Mail geht (siehe is_invited_account()).
export const INVITED_DOMAIN = "einladung.nomnom.invalid";

/// „abcd-efgh“, „ABCD EFGH“ → „ABCDEFGH“
export function normalizeCode(input: unknown): string | null {
  if (typeof input !== "string") return null;
  const code = input.toUpperCase().replace(/[^A-Z0-9]/g, "");
  return code.length === 8 ? code : null;
}

export function cleanName(input: unknown): string | null {
  if (typeof input !== "string") return null;
  const name = input.trim().replace(/\s+/g, " ").slice(0, 40);
  return name.length > 0 ? name : null;
}
