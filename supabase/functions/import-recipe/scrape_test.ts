import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import { assertPublicURL, detectPlatform, parsePage } from "./scrape.ts";

const base = new URL("https://www.beispiel-blog.de/rezepte/tacos");

Deno.test("findet schema.org-Rezept im @graph und nimmt dessen Bild", () => {
  const html = `<html><head>
    <meta property="og:title" content="Halloumi-Tacos | Blog">
    <meta property="og:image" content="https://cdn.example.com/og.jpg">
    <script type="application/ld+json">{"@context":"https://schema.org","@graph":[
      {"@type":"WebPage","name":"x"},
      {"@type":"Recipe","name":"Halloumi-Tacos","image":["/img/small.jpg","/img/large.jpg"],
       "recipeIngredient":["250 g Halloumi"]}
    ]}</script></head><body><nav>Menü</nav><p>Viel Text</p></body></html>`;

  const page = parsePage(html, base, "web");
  assertEquals((page.recipeJSON as { name: string }).name, "Halloumi-Tacos");
  assertEquals(page.imageURL, "https://www.beispiel-blog.de/img/large.jpg");
  assertEquals(page.title, "Halloumi-Tacos | Blog");
  // Mit Rezeptdaten wird kein Seitentext mitgeschickt
  assertEquals(page.text, null);
});

Deno.test("ohne Rezeptdaten: sichtbarer Text ohne Skripte und Navigation", () => {
  const html = `<html><head><title>Omas Kuchen</title><script>var tracking = 1;</script></head>
    <body><nav>Startseite Rezepte</nav><h1>Omas Kuchen</h1><p>200 g Mehl &amp; 100 g Zucker</p>
    <footer>Impressum</footer></body></html>`;

  const page = parsePage(html, base, "web");
  assertEquals(page.recipeJSON, null);
  assertEquals(page.title, "Omas Kuchen");
  assertEquals(page.text, "Omas Kuchen\n200 g Mehl & 100 g Zucker");
});

Deno.test("Instagram-Caption aus og:description, auch mit Apostroph und Entities", () => {
  const html = `<meta content="Anna&#39;s Pasta: 200g Spaghetti, 1 Zitrone 🍋" property="og:description" />
    <meta property="og:image" content='https://scontent.cdninstagram.com/p.jpg?x=1&amp;y=2'>`;

  const page = parsePage(html, new URL("https://www.instagram.com/p/abc/"), "instagram");
  assertEquals(page.description, "Anna's Pasta: 200g Spaghetti, 1 Zitrone 🍋");
  assertEquals(page.imageURL, "https://scontent.cdninstagram.com/p.jpg?x=1&y=2");
});

Deno.test("Recipe-Typ als Array und kaputtes JSON-LD davor", () => {
  const html = `<script type="application/ld+json">{ kaputt </script>
    <script type="application/ld+json">{"@type":["Recipe","NewsArticle"],"name":"Dal","image":{"url":"https://x.de/dal.jpg"}}</script>`;

  const page = parsePage(html, base, "web");
  assertEquals((page.recipeJSON as { name: string }).name, "Dal");
  assertEquals(page.imageURL, "https://x.de/dal.jpg");
});

Deno.test("Plattform-Erkennung", () => {
  assertEquals(detectPlatform(new URL("https://www.instagram.com/reel/xyz")), "instagram");
  assertEquals(detectPlatform(new URL("https://vm.tiktok.com/ZM123/")), "tiktok");
  assertEquals(detectPlatform(new URL("https://www.chefkoch.de/rezepte/1")), "web");
});

Deno.test("interne Adressen werden abgelehnt", () => {
  for (const url of [
    "http://localhost:54321/rest/v1",
    "http://127.0.0.1/",
    "http://10.0.0.5/",
    "http://169.254.169.254/latest/meta-data",
    "http://192.168.1.1/",
    "http://172.20.0.1/",
    "http://[::1]/",
    "file:///etc/passwd",
    "http://db.internal/",
  ]) {
    assertThrows(() => assertPublicURL(url), Error, undefined, url);
  }
  assertEquals(assertPublicURL("https://www.chefkoch.de/x").hostname, "www.chefkoch.de");
});

Deno.test("Platzhalterbild ohne Rezeptfoto wird verworfen (Chefkoch)", () => {
  const html = `<html><head>
    <meta property="og:image" content="https://img.chefkoch-cdn.de/images/crop-960x540/assets/v2/img/placeholders/16x9/c.png">
    <script type="application/ld+json">{"@type":"Recipe","name":"Carne em vinho","image":{"@id":"https://www.chefkoch.de/x#primaryimage"}}</script>
  </head></html>`;
  const page = parsePage(html, new URL("https://www.chefkoch.de/rezepte/1/x.html"), "web");
  assertEquals(page.imageURL, null);
});
