# nomi – Wissen für Agents und Entwickler:innen

Persönliche iOS-App für einen Haushalt mit zwei Personen. Sie umfasst:
- nomi als Assistent für alles rund ums Essen, per Text und Sprache,
- das heutige Essen nach Mahlzeiten: allein festlegen oder gemeinsam per Swipe bis zum Match,
- die Rezeptsammlung mit Import aus Links, Social Posts, Fotos und Handschrift,
- eine gemeinsame Einkaufsliste live,
- den Wochenplan und den Kochmodus mit Timern.

Die UI-Sprache ist Deutsch. Diese Datei ist die einzige Wissensquelle des Projekts. `CLAUDE.md` verweist nur hierher.

## Grundsätze für die Arbeit am Projekt

- **Texte:**
  - Alle sichtbaren Texte sind Deutsch, locker und per Du.
  - Code-Kommentare sind Deutsch, kurz und erklären das Warum.
  - Commit-Nachrichten sind Deutsch: eine Betreffzeile, darunter Stichpunkte.
- **Nachweis:** Jede Änderung wird gebaut und getestet (siehe Tests). UI-Änderungen werden zusätzlich per Screenshot aus dem Testlauf angesehen, nicht nur kompiliert.
- **Gestaltungsfragen:** Erst Vorschläge visuell zeigen, dann einbauen. Dafür rendert ein Swift-Skript in `design/` einen Bogen (PNG), der mit `open` in der Vorschau geöffnet wird. Bei mehreren Richtungen gibt es eine Empfehlung mit Begründung.
- **Doku:** Neue Erkenntnisse (Fallen, Abläufe, Entscheidungen) kommen in diese Datei.
- **Geheimnisse:** Keine Schlüssel ins Repo.
  - Der Anthropic-Key liegt nur als Supabase-Function-Secret und lokal in `supabase/functions/.env` (gitignored).
  - In der App stehen nur öffentliche Publishable Keys.
- **Signierung:** Nie mit dem Firmen-Team „Landeshauptstadt Stuttgart“ signieren. Es gilt das persönliche Team (Personal Team, `DEVELOPMENT_TEAM: C4JPAJ4QQM`).
- **Bot-Schutz** fremder Websites nicht umgehen. Rezepte von gesperrten Seiten werden übersprungen, gemeldet wurde z. B. livingbbq.de.

## Name

Die App hieß früher „nomnom“ und darf so nicht mehr heißen. Sichtbar und im Code heißt sie „nomi“. Bewusst „nomnom“ bleiben nur:
- der lokale Repo-Ordner,
- die lokale Supabase-`project_id` (Docker-Container und Daten hängen daran),
- Kommentare in schon eingespielten Migrationen.

## Stack und Struktur

- SwiftUI, iOS 26+ (für Liquid-Glass-APIs wie `sharedBackgroundVisibility`), Swift 6 mit Default-Isolation `MainActor`.
- Das Projekt erzeugt XcodeGen aus `project.yml`; `Nomi.xcodeproj` ist nicht eingecheckt.
- **Targets:**

  | Target | Inhalt |
  |---|---|
  | `Nomi` | die App |
  | `NomiShare` | Teilen-Erweiterung für Links, Text und bis zu 4 Bilder |
  | `NomiTests` | Swift Testing |
  | `NomiUITests` | UI-Tests |

- **Backend:** Supabase (Postgres mit RLS, Auth, Realtime, Storage, Edge Functions in Deno). Claude läuft nur in Edge Functions.
- **Ordner:**

  | Ordner | Inhalt |
  |---|---|
  | `Nomi/App/` | Einstieg (`NomiApp`, `RootView` mit Splash), `AppModel` (Anmeldung, Haushalt, Phasen), `SplashView` |
  | `Nomi/DesignSystem/` | Farben, Schriften, Komponenten, Illustrationen (`FoodIllustration`, `ReactionIllustration`), `ChefiView` |
  | `Nomi/Features/<Feature>/` | ein Ordner pro Feature: Auth, Welcome, Household, Main, Nomi, Today, Plan, Recipes, Shopping, Cooking |
  | `Nomi/Models/` | Codable-Modelle und reine Logik (Parser, Zusammenführen, Skalieren), alles testbar |
  | `Nomi/Services/` | Supabase-Client, Function-Aufrufe, Realtime, Import, Bildkodierung |
  | `supabase/migrations/` | Schema, nur neue Dateien anlegen, nie eingespielte ändern |
  | `supabase/functions/` | Edge Functions `import-recipe`, `decide`, `assistant`, `invite`, gemeinsamer Code in `_shared/` |
  | `design/` | Entwürfe als PNG und die Swift-Render-Skripte dazu |

## Bauen, Simulator, iPhone

```sh
xcodegen generate                      # nach neuen oder umbenannten Dateien
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # xcode-select zeigt auf die CommandLineTools
xcodebuild -project Nomi.xcodeproj -scheme Nomi \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build build
```

**Echtes iPhone:**
- Anschließen per Kabel, in Xcode „Personal Team“ wählen, dann ⌘R. Auf dem Gerät müssen der Entwicklermodus aktiv und der Entwickler vertraut sein.
- Profile des kostenlosen Teams laufen nach 7 Tagen ab, danach erneut ⌘R.
- Die zweite Person bekommt die App nur, wenn ihr iPhone einmal am selben Mac hängt.

**Debugger-Halt:** Hält Xcode beim Start in `dyld`lldb_image_notifier`, ist das der Debugger, kein Absturz. Mit „Continue“ (⌃⌘Y) geht es weiter, oder man startet die App direkt vom Homescreen. Ohne Debugger starten:

```sh
xcrun devicectl device process launch --console --device <ID> de.gregorzoller.nomi
```

**Bundle-IDs:** `de.gregorzoller.nomi` und `de.gregorzoller.nomi.share`. App und Erweiterung teilen die Anmeldung über die Keychain-Gruppe `<Team>.de.gregorzoller.nomi.shared` (`KeychainLocalStorage` mit Service `nomi.auth`).

## Backend

**Projekte:**
- Live: `pohguhbhqvurdhnflpek` (eu-central-1), verknüpft per `supabase link`. Der Publishable Key steht in `SupabaseService.swift`.
- Lokal: `supabase start` auf den Ports 553xx (543xx gehört einem anderen Projekt, nicht anfassen). Mails landen in Mailpit unter http://127.0.0.1:55324.

**Migrationen:**
- Schemaänderungen nur als neue Datei in `supabase/migrations/`.
- Lokal einspielen: `supabase migration up --local`.
- Live einspielen: `supabase db push --linked`.

**`supabase config push`:** Der Befehl überträgt die **gesamte** `config.toml` sofort und ohne Rückfrage, auch ohne TTY und auch mit `echo n |`. Er ist schon einmal schiefgegangen: Lokale Standardwerte (MFA aus, Mail-Intervall 1 s, Bestätigungen aus) gingen live. Live-Werte, die bleiben müssen:
- `site_url http://localhost:3000`,
- MFA TOTP an,
- E-Mail-Bestätigung an,
- `max_frequency 60s`,
- `otp_length 6`,
- die OTP-Templates mit Betreff „Dein nomi-Code“.

Einzelne Auth-Werte ändert man besser gezielt im Dashboard oder über die Management API (`PATCH /v1/projects/<ref>/config/auth` nur mit den betroffenen Feldern).

**Neue Tabellen** brauchen:
- RLS über `public.is_member(household_id)` (security definer, damit Policies nicht rekursiv werden),
- explizite `grant … to authenticated`,
- bei Bedarf gezielt `grant … to service_role` (neue Tabellen haben auch dafür keine Standardrechte).

**Live-Sync:**
- Stores laden komplett neu, sobald sich etwas ändert (`observeTable` in `Services/Realtime.swift`).
- Delete-Events kommen bei gefilterten Abos nicht an. Darum hört `observeTable` zusätzlich ungefiltert auf Deletes.
- Tabellen mit Live-Sync gehören in die Publication `supabase_realtime`.

**Secrets:** `ANTHROPIC_API_KEY` liegt lokal in `supabase/functions/.env` und kommt live per `supabase secrets set --env-file supabase/functions/.env`.

**Uploads aus Skripten:** Storage-Uploads aus Skripten brauchen den alten `service_role`-JWT. Der neue `sb_secret`-Key ist kein JWT und scheitert mit „Invalid Compact JWS“.

### Edge Functions

- **Gemeinsames Muster:**
  - Alle nutzen `withSupabase({ auth: … })` aus `@supabase/server`, deshalb steht `verify_jwt = false` in `config.toml`.
  - Claude läuft über `_shared/recipe.ts` (`structured<T>()`):
    - Modell `claude-opus-5-5`, Anthropic SDK 1.3.0,
    - Structured Outputs per `output_config.format` (JSON-Schema),
    - Beta `server-side-fallback-2026-07-01` mit `fallbacks: "default"`,
    - Effort meist `low`, beim Ausarbeiten von Rezepten `medium`.

| Function | Aufgabe |
|---|---|
| `import-recipe` | Link holen (`scrape.ts`: JSON-LD, Open Graph, TikTok-oEmbed), Platzhalterbilder verwerfen (z. B. Chefkochs grünes „C“), Claude liest aus (`extract.ts`, auch Fotos und Handschrift), Bild nach `recipe-images` kopieren. |
| `decide` | `suggest`: aus Chat, Sammlung und Stimmen 5 Karten mit Antwort von nomi, Menüs mit Gängen. `expand`: Idee zu vollständigem Rezept, danach `plan_decision`. |
| `assistant` | nomi als Assistent, siehe unten |
| `invite` | Einmal-Code einlösen (öffentlich, `auth: "none"`), siehe Einladen |

Neue Gerichte arbeitet `_shared/expand.ts` aus (`expandIdea`); decide und assistant nutzen es beide.

**Prüfen und lokal starten:**
```sh
cd supabase/functions/<name> && deno check --config deno.json index.ts && deno test --config deno.json
supabase functions serve --env-file supabase/functions/.env     # alle Functions lokal, für die UI-Tests
```

**Deployen:** `supabase functions deploy <name> --project-ref pohguhbhqvurdhnflpek`. Live-Deployments bestätigt der Nutzer. In automatisierten Sitzungen sind sie teils gesperrt, dann gibt man den Befehl an ihn weiter.

**Nach einer neuen Function:** in `config.toml` einen Block `[functions.<name>]` mit `verify_jwt = false`, `import_map` und `entrypoint` anlegen. Der lokale Server muss neu starten, damit die Konfiguration greift.

## Funktionen der App

### Anmeldung und Haushalt
- **Anmeldung** per E-Mail-Code (OTP, 6 Stellen), ohne Passwort. Sign in with Apple braucht einen bezahlten Developer-Account und kommt später.
- **Haushalt:** `create_household` und `join_household` (RPCs). Alle Daten hängen am Haushalt.
- **Mailversand:** Der Standard-Mailversand von Supabase erreicht nur Mitglieder des Supabase-Teams. Deshalb gibt es den Einladungsweg ohne Mail.

### Einladen (zweite Person)
- **Einmal-Code:** 8 Zeichen ohne verwechselbare Zeichen, 7 Tage gültig. Die RPC `create_invite` erzeugt ihn, verschickt wird er über das Teilen-Menü per WhatsApp oder Nachricht. Im Code: `InviteCard` und `InviteCode` (Format „XXXX-XXXX“, findet den Code auch in einer eingefügten Nachricht).
- **Einlösen:** Die Function `invite` legt ein Konto `<uuid>@einladung.nomi.invalid` an, trägt es in den Haushalt ein und gibt einen Magic-Link-`token_hash` zurück. Die App macht daraus per `verifyOTP(tokenHash:type: .magiclink)` eine Sitzung.
- **Neues Handy:** `create_invite(member)` erzeugt einen Anmeldecode für ein bestehendes Mitglied. Das geht nur für Konten ohne echte Mail (`is_invited_account`).
- **`join_household`** nimmt Einmal-Codes und den alten 6-stelligen Haushalts-Code.

### Tabs
Reihenfolge: **nomi, Heute, Woche, Rezepte, Einkauf**. `AppNavigation` (`tab`, `decideMeal`) erlaubt Sprünge zwischen Tabs.

### nomi (Assistent)
- **Verlauf:** ein gemeinsamer Verlauf pro Haushalt in `assistant_messages` (user_id null bedeutet nomi), live für beide.
- **Ablauf in der Function `assistant`:**
  - Sie speichert die Nachricht und liest Sammlung, Kochhistorie, Wochenplan (Mahlzeiten), Einkaufsliste, Wiederkehrendes und Verlauf.
  - Claude antwortet mit `reply` (kurz, vorlesbar, ohne Markdown) und Aktionen:
    - `plan[]`: Datum, `meal`, Rezept oder neue Idee, Portionen, Gang,
    - `shopping`: Rezepte, `include_new_plan`, freie Einträge,
    - `today`: Wunsch und `meal`, übergibt an den Heute-Tab,
    - `navigate`.
  - Prompt, Schema und Prüfung (`validActions`) liegen getestet in `prompt.ts`.
  - Offene Wünsche fürs heutige Essen gehen immer an den Heute-Tab. Nur konkret genannte Gerichte plant nomi direkt.
- **Aktionen führt die App der fragenden Person aus** (`AssistantStore.execute`):
  - Sie nutzt dieselbe Logik wie beim Antippen (`ShoppingMerge`).
  - `result` hält Plan-IDs und `ShoppingChange` mit den vorherigen Ständen. Daraus macht „Rückgängig“ alles rückgängig.
  - Mitglieder dürfen nur die Spalte `result` ändern.
- **Sprache:**
  - `VoiceInput` nutzt `SFSpeechRecognizer` für de-DE, wenn möglich auf dem Gerät. Nach 1,6 s Pause wird abgeschickt.
  - `Speaker` (AVSpeechSynthesizer, beste installierte deutsche Stimme) liest Antworten auf gesprochene Fragen vor. Das lässt sich abschalten.
  - Audio-Callbacks laufen in der `nonisolated` Klasse `RecognitionSession`.
  - Auf dem Gerät ist die Sprache noch nicht getestet.

### Heute (Mahlzeiten von heute)
- **Aufbau:**
  - Mittag- und Abendessen sind feste Plätze, Frühstück kommt bei Bedarf dazu.
  - Leere Plätze zeigen „Noch nichts geplant“ mit „Vorschläge“ und „Rezept“.
  - Weitere Gänge kommen per „+ Gang“ dazu. Jedes Gericht hat „Jetzt kochen“.
- **Daten:** `meal_plan_entries.meal` (`fruehstueck`/`mittag`/`abend`) und `position` (Gang-Reihenfolge). `MealPlanStore` lädt immer auch heute.
- **Vorschläge:** Sie öffnen `DecideSheet` für eine Mahlzeit, mit Wunsch-Chips, Kartenstapel und Match. Eine Runde (`decide_sessions.meal`) gehört zu einer Mahlzeit; pro Haushalt läuft immer nur eine Runde.
- **Entscheiden:**
  - Ein **Match** entsteht per Trigger `check_match`, sobald alle Mitglieder dieselbe Karte mögen. Menüs gelten als entschieden, wenn jeder Gang eine solche Karte hat.
  - **„Das nehmen wir“** legt allein fest: `decide_alone` stimmt im Namen aller Mitglieder ab und setzt `decided_by`. Die Karte zeigt dann „Du hast entschieden“ bzw. „Alex hat entschieden“.
  - Nach der Entscheidung trägt **`plan_decision`** das Gericht in die Mahlzeit ein; `candidate_id` verhindert Doppel-Einträge. Ideen ohne Rezept trägt `decide` nach dem Ausarbeiten nach.

### Rezepte
- **Ansicht:** Startseite mit „Zuletzt gekocht“, „Neu“, Kategorie-Kacheln und Schnell-Links. Die gefilterte Ansicht hat Chips, die links einrasten.
- **Kopf:** Die Anzahl steht im Kreis (`CountBadge`), die Suche liegt hinter dem Lupen-Knopf.
- **Kategorien:** `dish_type` und `diet` am Rezept. Claude setzt sie beim Import, im Editor lassen sie sich ändern.
- **Kochhistorie:** `cooking_log`, ein Eintrag pro Rezept und Tag, geschrieben bei „Los geht's“ im Kochmodus.
- **Editor:** Schritte als einzelne Blöcke, Timer per Menü oder automatisch erkannt (`StepText.detectTimer`).
- **Skalieren:** überall über `scaledIngredients(for:)` und `QuantityFormatter`. kg↔g und l↔ml werden umgerechnet, Einheiten wie Zehen, Dosen und Gläser stehen in der Mehrzahl.
- **Import:**
  - aus Links und aus der Teilen-Erweiterung,
  - per Foto (höchstens 4, 1600 px, JPEG 0,75), auch Handschrift.
- **Einheiten und Abteilungen** im Function-Schema müssen zu `IngredientParser.units` und `Aisle` passen.

### Einkauf und Woche
- **Einkauf:**
  - Die Liste wird aus Rezepten gefüllt und zusammengeführt (`ShoppingMerge`, Einheiten vergleichbar gemacht), nach Abteilung sortiert und live gemeinsam abgehakt.
  - Wiederkehrende Einträge stehen in `staple_items`.
  - Die Anzahl offener Einträge steht im Kreis.
- **Woche:**
  - Die Pfeile stehen neben der Kalenderwoche, die Headline hat die volle Breite.
  - Einträge zeigen die Mahlzeit, die Rezeptauswahl lässt die Mahlzeit wählen.
  - „Zutaten der Woche einkaufen“ füllt die Einkaufsliste.

### Kochmodus
- `Features/Cooking`: Vollbild, der Bildschirm bleibt an, Portionen sind einstellbar.
- Timer laufen über einen Endzeitpunkt (`CookingTimers`), dazu kommt eine lokale Mitteilung für den Hintergrund.
- Start aus der Rezeptansicht oder per „Jetzt kochen“ im Heute-Tab.

## Design

**Grundfarben:**
- Markenfarbe Himbeere `Color.brand` (#CC335E, dunkel #B8284F), Schrift darauf `Color.onBrand`.
- Creme-Grund `Color.canvas`, Tinte `Color.ink`, dazu `mist`, `surface`, `hairline`, `sage`, `tomato`.
- Akzent Ocker #F2B33D.

**Schriften:**
- Überschriften in Bricolage Grotesque, immer über `Font.heading(...)`, `.display` oder `.cardTitle`, nie direkt per Schriftname.
- Fließtext DM Sans.
- Metazeilen DM Mono in Versalien („25 MIN · FÜR ZWEI“, `MetaLabel`).

**Hauptscreens:**
- Sie beginnen mit `BrandHeader` und `.brandNavigationBar()`. Die Leiste bleibt durchsichtig, darunter liegt eine Fläche in Markenfarbe; ein eigener Leisten-Hintergrund wirkt unter iOS 26 dunkler.
- Toolbar-Elemente auf Himbeere haben keine Glas-Kapsel (`.sharedBackgroundVisibility(.hidden)`).

**Headlines und Buttons:**
- Mehrzeilige Headlines setzt man mit `DisplayHeadline`. Zeilen brechen nie um, sondern werden notfalls kleiner, weil negatives `lineSpacing` in SwiftUI nicht greift.
- Dunkle Pillen-Buttons: `.primary` ist einzeilig, `.secondary` ist der Rahmen-Button.

**Illustrationen im Stil „Linie“** statt Emojis:
- feine Tintenkontur, Pastellflächen, Himbeer-Akzent,
- `FoodIllustration`: 23 Motive, gewählt nach Titel, Kategorie oder Ernährungsweise,
- `ReactionIllustration` für Jubel, Warten, Lecker, Korb und Ratlos.
- Alle Motive zeigt der Start mit `NOMI_GALLERY=1`.

**Maskottchen Chefi** (kleiner Koch in Mint, Kochmütze mit Himbeer-Band, Holzlöffel):
- Entwürfe liegen in `design/mascot/`. `ChefiView` zeichnet dieselben Formen; Löffel-Neigung und -Höhe sind animierbar, dazu gibt es Zwinkern und Winken.
- Chefi trägt überall die Mütze, nur im App-Icon nicht.

**Splash:**
- `SplashView` spielt bei jedem Start etwa 2,5 s: hereinhüpfen, Löffel heben und zwinkern, winken, Wortmarke erscheint.
- Das gilt auch nach mindestens 10 s im Hintergrund. Ist die App noch nicht fertig, rührt Chefi weiter.
- Der statische Startbildschirm ist die Farbe `LaunchBackground`. In Simulator-Videos wirkt er knalliger; das liegt an der Aufnahme.

**Wortmarke:**
- DynaPuff (`design/fonts`, OFL) mit angebissenem Ocker-o.
- In der App ist sie das Vektor-PDF `Wordmark` bzw. `WordmarkOnLight`, eingebunden über die Komponente `Wordmark` (feste Breite, damit die Toolbar sie nicht staucht).
- In der Kopfzeile ist sie 31 pt hoch.

**App-Icon:** Konzept D2, die Wortmarke oben, darunter Chefi ohne Mütze. Icon und Wortmarke erzeugt:
```sh
swift design/appicon/render-icon-concepts.swift design/fonts/DynaPuff.ttf Nomi/Resources/Fonts --export Nomi/Resources/Assets.xcassets
```

**Tab-Symbole:**
- Eigene Linien-Icons als Vorlagenbilder (`Tab<Name>` und `Tab<Name>Active`): Chefi-Gesicht, Pfanne, Kalender, Rezeptkarte, Tasche.
- Gerendert von `design/tabbar/render-tab-assets.swift`. Aktive Varianten haben gefüllte Akzente; iOS färbt Tab-Symbole immer einfarbig.

## Tests

**Arten:**
- `NomiTests` (Swift Testing): Parser, Mengen, Skalieren, Zusammenführen, Einladungscodes, Kategorien, Kochhistorie, Function-Datumsformat.
- `NomiUITests`: alle Hauptabläufe, mit zweiter Person über die REST-API. Gemeinsame Helfer stehen in `UITestSupport.swift`.
- Deno-Tests in jeder Function (`deno test`).

**UI-Tests** laufen gegen das lokale Supabase und die lokal laufenden Functions (mit echtem Claude):
```sh
supabase start
supabase functions serve --env-file supabase/functions/.env      # im Hintergrund
xcodebuild test -project Nomi.xcodeproj -scheme Nomi \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build -resultBundlePath build/run.xcresult
```

**Umgebungsvariablen**, die Debug-Builds lesen:

| Variable | Wirkung |
|---|---|
| `NOMI_SUPABASE_URL`, `NOMI_SUPABASE_KEY` | Supabase-Ziel |
| `NOMI_RESET_SESSION` | frisch abgemeldet starten |
| `NOMI_DISABLE_NOTIFICATIONS` | keine Rückfrage nach Mitteilungen |
| `NOMI_SKIP_SPLASH` | ohne Splash, Standard in `UITestSupport` |
| `NOMI_GALLERY` | Illustrations-Galerie statt App (`1`, `light`, `dark`) |

**Screenshots** aus einem Lauf holen und ansehen:
```sh
xcrun xcresulttool export attachments --path build/run.xcresult --output-path <ordner>
```
Die Dateinamen stehen in `manifest.json` unter `suggestedHumanReadableName`.

**Animationen:** Lassen sie sich per Test nicht greifen (zu schnell), nimmt man den Start als Video auf und zieht Einzelbilder heraus:
```sh
xcrun simctl io <sim> recordVideo …
xcrun simctl launch …              # Umgebungsvariablen mit Präfix SIMCTL_CHILD_
ffmpeg -i video.mp4 -vf fps=8 f_%02d.png
```

**Wackelige Stellen:**
- Tests mit Claude hängen von der API ab.
- Der lokale Edge Runtime beendet ruhende Prozesse etwa 2,5 Minuten nach einer Anfrage („early termination“); das ist harmlos.
- Schlägt ein Claude-Test einmal fehl, zuerst einzeln wiederholen.
- Im Simulator kommt es gelegentlich vor, dass „App animations complete notification not received“ jeden Schritt 60 s warten lässt. Ein Testlauf dauert dann extrem lange. Lauf abbrechen und neu starten.

## Fallen

**UI-Tests:**
- Die `TabView` hält verborgene Tabs im Accessibility-Baum. `app.buttons[...]` kann eine unsichtbare Kachel treffen; Abfragen eingrenzen, z. B. `app.collectionViews.buttons`, oder eindeutige Labels vergeben.
- Zeilen-Buttons brauchen einen `Spacer`, sonst endet die Tippfläche am Textende.
- In Sheets keine zufälligen IDs als Schlüssel für `@State` verwenden: Das Sheet wird neu erzeugt, der State bleibt.
- Mehrzeilige `TextField`s lösen bei „Senden“ kein `onSubmit` aus, sondern fügen einen Umbruch ein. Deshalb schicken die Chat-Felder ab, sobald ein Umbruch auftaucht.
- Formulare (`FormScreen`) bleiben mit `defaultScrollAnchor(.bottom, for: .sizeChanges)` unten verankert, damit Felder nicht hinter Tastatur und Button verschwinden. `scrollTo` funktionierte dort nicht.
- Eingabefelder nicht bei jedem Tastendruck umschreiben (z. B. Formatieren); XCUITest und schnelles Tippen verlieren sonst Zeichen. Erst formatieren, wenn die Eingabe vollständig ist.

**Swift 6:**
- Mit Default-Isolation `MainActor` müssen Closures, die Frameworks auf anderen Threads aufrufen, `nonisolated` bzw. `@Sendable` sein. Sonst stürzt die App zur Laufzeit ab. Betroffen sind z. B. `UIColor { traits in }`, Decoder-Datumsclosures, Speech-Callbacks und Audio-Taps.
- Laufende `.task`-Closures sehen eine Kopie der View; Werte, die sich ändern, über `@State` spiegeln (siehe `SplashView.ready`).

**SwiftUI und iOS:**
- In der Toolbar stauchen sich Bilder auf Symbolgröße. Darum gibt `Wordmark` feste Breite und Höhe vor.
- Der Functions-Client dekodiert ohne Datumsformat; Postgres liefert Mikrosekunden. Antworten deshalb über `FunctionDecoding.decoder` lesen.
- `CTLineGetImageBounds` rechnet die aktuelle Textposition mit ein; in Render-Skripten vor dem Messen `textPosition = .zero` setzen.

## Offen und zu prüfen

- Die Edge Functions `assistant` und `decide` müssen nach den letzten Änderungen live deployt werden (Mahlzeiten, `plan_decision`).
- Auf dem iPhone noch ungetestet sind die Sprache (Mikrofon, Erkennung, Vorlesen) und der Farbübergang vom Startbildschirm zum Splash.
- Sign in with Apple kommt, sobald es einen bezahlten Developer-Account gibt.
