// Lädt eine geteilte Seite und zieht heraus, was für die Rezept-Extraktion zählt:
// schema.org-Rezeptdaten, Open-Graph-Tags (Titel, Caption, Bild) und den sichtbaren Text.

export type Platform = "web" | "instagram" | "tiktok";

export interface ScrapedPage {
  url: string;
  platform: Platform;
  title: string | null;
  description: string | null;
  imageURL: string | null;
  /** JSON-LD-Objekt mit @type Recipe, falls vorhanden. */
  recipeJSON: unknown | null;
  /** Sichtbarer Text der Seite, nur wenn keine Rezeptdaten gefunden wurden. */
  text: string | null;
}

const BROWSER_UA =
  "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1";
// Instagram liefert Open-Graph-Tags zuverlässig nur an Link-Vorschau-Crawler
const PREVIEW_UA = "facebookexternalhit/1.1 (+http://www.facebook.com/externalhit_uatext.php)";

/** Kostenbremse: Seitentext ohne Rezeptdaten ist meist Navigation, Kommentare und Werbung. */
const MAX_TEXT_CHARS = 40_000;

export function detectPlatform(url: URL): Platform {
  const host = url.hostname.replace(/^www\./, "");
  if (host === "instagram.com" || host.endsWith(".instagram.com")) return "instagram";
  if (host === "tiktok.com" || host.endsWith(".tiktok.com")) return "tiktok";
  return "web";
}

/** Nur öffentliche http(s)-Adressen – die Funktion soll keine internen Dienste abfragen. */
export function assertPublicURL(raw: string): URL {
  const url = new URL(raw);
  if (url.protocol !== "https:" && url.protocol !== "http:") {
    throw new Error("unsupported protocol");
  }
  const host = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
  const privateHost =
    host === "localhost" ||
    host.endsWith(".localhost") ||
    host.endsWith(".local") ||
    host.endsWith(".internal") ||
    /^(0|10|127)\./.test(host) ||
    /^169\.254\./.test(host) ||
    /^172\.(1[6-9]|2\d|3[01])\./.test(host) ||
    /^192\.168\./.test(host) ||
    host === "::1" ||
    /^f[cd][0-9a-f]{2}:/.test(host) ||
    /^fe80:/.test(host);
  if (privateHost) throw new Error("private address");
  return url;
}

export async function scrape(rawURL: string): Promise<ScrapedPage> {
  let url = assertPublicURL(rawURL);
  const platform = detectPlatform(url);

  if (platform === "tiktok") {
    return await scrapeTikTok(url);
  }

  const response = await fetch(url, {
    headers: {
      "User-Agent": platform === "instagram" ? PREVIEW_UA : BROWSER_UA,
      "Accept-Language": "de-DE,de;q=0.9,en;q=0.8",
    },
    redirect: "follow",
    signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error(`fetch failed: ${response.status}`);
  url = assertPublicURL(response.url || url.toString());
  return parsePage(await response.text(), url, platform);
}

/** Reiner HTML-Teil, ohne Netzwerk – damit testbar. */
export function parsePage(html: string, url: URL, platform: Platform): ScrapedPage {
  const recipeJSON = findRecipeJSON(html);
  return {
    url: url.toString(),
    platform,
    title: meta(html, "og:title") ?? tagText(html, "title"),
    description: meta(html, "og:description") ?? meta(html, "description"),
    imageURL: withoutPlaceholder(absolute(recipeImage(recipeJSON) ?? meta(html, "og:image"), url)),
    recipeJSON,
    text: recipeJSON ? null : visibleText(html).slice(0, MAX_TEXT_CHARS),
  };
}

/** TikTok blockiert normales Scraping, die oEmbed-Schnittstelle liefert aber Caption und Vorschaubild. */
async function scrapeTikTok(url: URL): Promise<ScrapedPage> {
  // Kurzlinks (vm.tiktok.com) erst auflösen, oEmbed braucht die volle Video-URL
  const resolved = await fetch(url, {
    headers: { "User-Agent": BROWSER_UA },
    redirect: "follow",
    signal: AbortSignal.timeout(15_000),
  });
  const finalURL = assertPublicURL(resolved.url || url.toString());
  await resolved.body?.cancel();

  const oembed = await fetch(
    `https://www.tiktok.com/oembed?url=${encodeURIComponent(finalURL.toString())}`,
    { signal: AbortSignal.timeout(15_000) },
  );
  if (!oembed.ok) throw new Error(`tiktok oembed failed: ${oembed.status}`);
  const data = await oembed.json() as { title?: string; author_name?: string; thumbnail_url?: string };

  return {
    url: finalURL.toString(),
    platform: "tiktok",
    title: data.author_name ? `TikTok von ${data.author_name}` : null,
    description: data.title ?? null,
    imageURL: data.thumbnail_url ?? null,
    recipeJSON: null,
    text: null,
  };
}

// MARK: - HTML-Helfer (kein DOM im Edge-Runtime, daher gezielte Muster)

function decodeEntities(s: string): string {
  return s
    .replace(/&#(\d+);/g, (_, n) => String.fromCodePoint(Number(n)))
    .replace(/&#x([0-9a-f]+);/gi, (_, n) => String.fromCodePoint(parseInt(n, 16)))
    .replace(/&quot;/g, '"')
    .replace(/&#39;|&apos;/g, "'")
    .replace(/&lt;/g, "<")
    .replace(/&gt;/g, ">")
    .replace(/&nbsp;/g, " ")
    .replace(/&amp;/g, "&");
}

function meta(html: string, name: string): string | null {
  const escaped = name.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
  // Attributwert in "…" oder '…' – das jeweils andere Anführungszeichen darf im Text vorkommen
  const value = `(?:"([^"]*)"|'([^']*)')`;
  const key = `(?:property|name)=["']${escaped}["']`;
  const patterns = [
    new RegExp(`<meta[^>]+${key}[^>]*content=${value}`, "i"),
    new RegExp(`<meta[^>]+content=${value}[^>]*${key}`, "i"),
  ];
  for (const p of patterns) {
    const m = html.match(p);
    const content = m?.[1] ?? m?.[2];
    if (content) return decodeEntities(content).trim();
  }
  return null;
}

function tagText(html: string, tag: string): string | null {
  const m = html.match(new RegExp(`<${tag}[^>]*>([\\s\\S]*?)</${tag}>`, "i"));
  return m ? decodeEntities(m[1]).trim() || null : null;
}

function findRecipeJSON(html: string): unknown | null {
  const scripts = html.matchAll(/<script[^>]+type=["']application\/ld\+json["'][^>]*>([\s\S]*?)<\/script>/gi);
  for (const [, body] of scripts) {
    try {
      const found = findRecipeNode(JSON.parse(body.trim()));
      if (found) return found;
    } catch {
      // Kaputtes JSON-LD kommt vor – einfach den nächsten Block versuchen
    }
  }
  return null;
}

function findRecipeNode(node: unknown): unknown | null {
  if (Array.isArray(node)) {
    for (const item of node) {
      const found = findRecipeNode(item);
      if (found) return found;
    }
    return null;
  }
  if (node && typeof node === "object") {
    const obj = node as Record<string, unknown>;
    const type = obj["@type"];
    if (type === "Recipe" || (Array.isArray(type) && type.includes("Recipe"))) return obj;
    if (obj["@graph"]) return findRecipeNode(obj["@graph"]);
  }
  return null;
}

function recipeImage(recipe: unknown): string | null {
  if (!recipe || typeof recipe !== "object") return null;
  const image = (recipe as Record<string, unknown>).image;
  const pick = (v: unknown): string | null => {
    if (typeof v === "string") return v;
    if (Array.isArray(v)) return v.length ? pick(v[v.length - 1]) : null; // meist größtes zuletzt
    if (v && typeof v === "object") return pick((v as Record<string, unknown>).url);
    return null;
  };
  return pick(image);
}

/** Seiten ohne Rezeptfoto liefern oft ein Platzhalterbild (Chefkoch: grünes „C“) – lieber gar kein Bild. */
const PLACEHOLDER_IMAGE = /placeholder|default[-_]?(image|img)|no[-_]?image/i;

function withoutPlaceholder(src: string | null): string | null {
  return src && PLACEHOLDER_IMAGE.test(src) ? null : src;
}

function absolute(src: string | null, base: URL): string | null {
  if (!src) return null;
  try {
    return new URL(src, base).toString();
  } catch {
    return null;
  }
}

function visibleText(html: string): string {
  return decodeEntities(
    html
      .replace(/<(head|script|style|noscript|svg|nav|header|footer|form|iframe)[\s\S]*?<\/\1>/gi, " ")
      .replace(/<br\s*\/?>|<\/(p|div|li|h[1-6]|tr)>/gi, "\n")
      .replace(/<[^>]+>/g, " "),
  )
    .split("\n")
    .map((line) => line.replace(/\s+/g, " ").trim())
    .filter(Boolean)
    .join("\n");
}
