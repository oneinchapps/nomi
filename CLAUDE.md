# nomi

Persönliche iOS-App für zwei: nomi als Assistent für alles rund ums Essen (Text und Sprache), heutiges Essen allein festlegen oder gemeinsam per Swipe, Einkaufsliste, Wochenplan, Kochmodus. UI-Sprache Deutsch.

Die App hieß früher „nomnom“ und darf so nicht mehr heißen. Überall sichtbar und im Code heißt sie „nomi“. Nur diese Namen bleiben bewusst „nomnom“: der Repo-Ordner, die lokale Supabase-`project_id` (Docker-Container und Daten hängen daran) und Kommentare in schon eingespielten Migrationen.

## Stack
- SwiftUI, iOS 26+ (für Liquid-Glass-APIs wie `sharedBackgroundVisibility`), Swift 6 (Default-Isolation `MainActor`)
- Projekt wird mit XcodeGen aus `project.yml` erzeugt; `Nomi.xcodeproj` ist nicht eingecheckt
- Backend: Supabase (Postgres, Auth, Realtime, Edge Functions). Der Anthropic-Key liegt nur als Supabase-Secret vor, nie in der App

## Bauen
```sh
xcodegen generate
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # solange xcode-select auf die CommandLineTools zeigt
xcodebuild -project Nomi.xcodeproj -scheme Nomi \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build build
```
Nach neuen oder umbenannten Dateien `xcodegen generate` erneut ausführen.

## Backend
- Live-Projekt: `pohguhbhqvurdhnflpek` (eu-central-1), verknüpft per `supabase link`. Schemaänderungen nur als neue Datei in `supabase/migrations/`, dann `supabase db push --linked`.
- `supabase config push` überträgt die **gesamte** `config.toml` sofort und ohne Rückfrage. Vorher sicherstellen, dass alle Werte dem gewünschten Live-Stand entsprechen.
- Lokal: `supabase start` (Ports 553xx, damit kein Konflikt mit anderen lokalen Projekten). Mails landen in Mailpit unter http://127.0.0.1:55324.
- Neue Tabellen brauchen explizite `grant … to authenticated` und RLS über `public.is_member(household_id)`.

## Rezept-Import
- Edge Function `supabase/functions/import-recipe`: Seite laden (`scrape.ts`: JSON-LD, Open Graph, TikTok-oEmbed), Claude liest per JSON-Schema aus (`extract.ts`), Bild wird in `recipe-images` kopiert. Auth über `withSupabase({ auth: "user" })`, deshalb `verify_jwt = false` in config.toml.
- Einheiten und Abteilungen im Schema müssen zu `IngredientParser.units` und `Aisle` in der App passen.
- Secret `ANTHROPIC_API_KEY`: lokal in `supabase/functions/.env` (gitignored), live per `supabase secrets set --env-file supabase/functions/.env`.
- Prüfen: `cd supabase/functions/import-recipe && deno check --config deno.json index.ts && deno test --config deno.json`
- Lokal starten: `supabase functions serve import-recipe`
- Teilen-Erweiterung `NomiShare` nutzt Design-System, Modelle und Services der App mit (siehe project.yml) und teilt die Anmeldung über die Keychain-Gruppe `<Team>.de.gregorzoller.nomi.shared`.

## Einladen (zweite Person)
- Ohne E-Mail: Der Standard-Mailversand von Supabase erreicht nur Mitglieder des Supabase-Teams. Darum lädt man per Einmal-Code ein (8 Zeichen, 7 Tage gültig, RPC `create_invite`), der über das Teilen-Menü per WhatsApp oder Nachricht rausgeht.
- Edge Function `supabase/functions/invite` (`auth: "none"`) löst den Code ein: Sie legt ein Konto mit der Adresse `<uuid>@einladung.nomi.invalid` an, trägt es in den Haushalt ein und gibt einen Magic-Link-`token_hash` zurück. Die App tauscht ihn per `verifyOTP(tokenHash:type: .magiclink)` gegen eine Sitzung.
- Neues Handy: `create_invite(member)` erzeugt einen Anmeldecode für ein bestehendes Mitglied. Das geht nur für Konten ohne echte Mailadresse (`is_invited_account`).
- `join_household` nimmt Einmal-Codes und den alten 6-stelligen Haushalts-Code an. Das ist der Weg für Leute, die per E-Mail angemeldet sind.

## nomi-Tab (Assistent)
Erster Tab. Ein gemeinsamer Verlauf pro Haushalt in `assistant_messages`, live für beide.

**Edge Function `supabase/functions/assistant`:**
- Sie speichert die Nachricht der Person und liest Sammlung, Kochhistorie, Wochenplan, Einkaufsliste und Verlauf.
- Claude antwortet strukturiert mit `reply` plus Aktionen: `plan`, `shopping`, `today`, `navigate`.
- Prompt, Schema und Prüfung der Aktionen (`validActions`) liegen in `prompt.ts` und sind getestet.
- Neue Gerichte im Plan werden per `_shared/expand.ts` gleich ausgearbeitet und gespeichert. decide nutzt dasselbe Modul.

**Aktionen führt die App der fragenden Person aus** (`AssistantStore.execute`):
- Sie nutzt dieselbe Logik wie beim Antippen, darunter `ShoppingMerge`.
- Was angelegt oder geändert wurde, landet in `result`: Plan-IDs und `ShoppingChange` mit den vorherigen Ständen. Daraus macht „Rückgängig“ alles rückgängig.
- Mitglieder dürfen nur die Spalte `result` ändern.

**Navigation:**
- `AppNavigation.tab` wechselt nach der Antwort in den passenden Tab.
- `today` startet im Heute-Tab eine Runde mit dem Wunsch (`DecideStore.startRound`).

**Sprache:**
- `VoiceInput` nutzt `SFSpeechRecognizer` für de-DE, wenn möglich auf dem Gerät. Eine Pause von 1,6 s beendet die Aufnahme.
- `Speaker` liest Antworten auf gesprochene Fragen mit der besten deutschen Stimme vor. Das lässt sich im Toolbar-Knopf abschalten.
- Audio-Callbacks laufen in der `nonisolated` Klasse `RecognitionSession`.

## Heute-Tab (heutiges Essen)
- Edge Function `supabase/functions/decide`: `suggest` (Chat + Sammlung + bisherige Stimmen → 5 Karten, Antwort von nomi) und `expand` (Idee → vollständiges Rezept in der Sammlung). Prompts in `suggest.ts`, gemeinsames Rezeptschema und Claude-Aufruf in `supabase/functions/_shared/recipe.ts`.
- Match entsteht per Trigger `check_match`, sobald alle Mitglieder dieselbe Karte mögen.
- „Das nehmen wir“ legt allein fest: Die RPC `decide_alone` stimmt im Namen aller Mitglieder für die Karte und setzt `decided_by`. Dadurch greift dieselbe Match-Logik, auch für Menüs.
- Der Heute-Tab hat keinen eigenen Chat mehr, nur Wunsch-Chips. Freie Wünsche laufen über nomi.
- Antworten von nomi (`user_id` null) schreibt nur die Function mit `supabaseAdmin`; Nutzer:innen dürfen per RLS nur als sie selbst schreiben.
- Neue Tabellen haben auch für `service_role` keine Standardrechte – bei Bedarf gezielt `grant`.

## Kochmodus
`Features/Cooking`: Vollbild aus der Rezeptansicht, Bildschirm bleibt an. Timer laufen über einen Endzeitpunkt (`CookingTimers`), zusätzlich gibt es eine lokale Mitteilung für den Hintergrund. Timer kommen aus `Recipe.Step.timerSeconds` – beim Import/Ausarbeiten von Claude gesetzt, im Editor per Menü oder automatisch aus dem Text erkannt (`StepText.detectTimer`).

## Tests
- `NomiTests` (Swift Testing): Zutaten-Parser, Mengenformat, Skalierung, Abteilungs-Zuordnung
- `NomiUITests`: Onboarding mit zwei Personen und Rezept-Flow (anlegen, öffnen, Portionen skalieren). Gemeinsame Helfer stehen in `UITestSupport.swift`.

Die UI-Tests laufen gegen das lokale Supabase:
```sh
supabase start
xcodebuild test -project Nomi.xcodeproj -scheme Nomi \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build
```
Debug-Builds lesen diese Variablen aus der Umgebung:
- `NOMI_SUPABASE_URL`, `NOMI_SUPABASE_KEY`, `NOMI_RESET_SESSION`
- `NOMI_DISABLE_NOTIFICATIONS`: keine Rückfrage nach Mitteilungen in UI-Tests
- `NOMI_SKIP_SPLASH`: ohne Splash-Animation; setzt `UITestSupport` für alle Flow-Tests
- `NOMI_GALLERY`: zeigt statt der App alle Illustrationen und Chefi-Posen (`1`/`light`/`dark`)

## Live-Sync
Stores laden komplett neu, sobald sich etwas ändert (`observeTable` in `Services/Realtime.swift`). Delete-Events kommen in Supabase Realtime nicht bei gefilterten Abos an, deshalb hört `observeTable` zusätzlich ungefiltert auf Deletes. Neue Tabellen mit Live-Sync in die Publication `supabase_realtime` aufnehmen.

## UI-Test-Fallen
- Die `TabView` hält verborgene Tabs im Accessibility-Baum. Ein `app.buttons[...]` kann deshalb eine unsichtbare Kachel aus einem anderen Tab treffen. Abfragen eingrenzen, z. B. `app.collectionViews.buttons`.
- Zeilen-Buttons brauchen einen `Spacer`, sonst endet die Tippfläche am Textende.
- In Sheets keine zufälligen IDs als Schlüssel für `@State` verwenden: Das Sheet wird bei jedem Neuzeichnen neu erzeugt, der State bleibt aber bestehen.

## Swift-6-Fallen
Die App nutzt Default-Isolation `MainActor`. Closures, die UIKit/SwiftUI auf anderen Threads aufruft (z. B. `UIColor { traits in … }`), müssen `nonisolated`/`@Sendable` sein, sonst stürzt die App zur Laufzeit ab.

## Struktur
- `Nomi/DesignSystem/`: Farben (`Color.canvas`, `.ink`, `.mist` …), Schriften (`Font.display`, `.meta` …), wiederverwendbare Komponenten. Neue Screens nutzen diese Tokens statt eigener Werte.
- `Nomi/Features/<Feature>/`: ein Ordner pro Feature
- `Nomi/Models/`

## Design
Markenfarbe Himbeere (`Color.brand`, Schrift darauf `Color.onBrand`). Jeder Hauptscreen beginnt mit `BrandHeader` und nutzt `.brandNavigationBar()`: Die Leiste bleibt durchsichtig, darunter liegt eine Fläche in Markenfarbe (ein eigener Leisten-Hintergrund würde unter iOS 26 dunkler wirken). Toolbar-Elemente auf der Markenfarbe ohne Glas-Kapsel (`.sharedBackgroundVisibility(.hidden)`). Entwürfe und das Render-Skript fürs App-Icon liegen in `design/`.
Maskottchen **Chefi** (kleiner Koch in Mint mit Kochmütze und Holzlöffel):
- Entwürfe und Render-Skript liegen in `design/mascot/`. Das App-Icon ist dessen `app-icon.png` (Ausschnitt B), kopiert nach `AppIcon.appiconset`.
- In der App zeichnet `ChefiView` dieselben Formen. Löffel-Neigung und -Höhe sind animierbar, dazu gibt es die Posen Zwinkern und Winken.
- `SplashView` spielt bei jedem Start etwa 2,5 Sekunden: hereinhüpfen, Löffel heben und zwinkern, winken mit Wortmarke. Das gilt auch, wenn die App nach mindestens 10 Sekunden aus dem Hintergrund zurückkommt. Ist die App dann noch nicht fertig, rührt Chefi weiter.
- Der statische Startbildschirm ist die Farbe `LaunchBackground`. In Simulator-Videoaufnahmen wirkt er knalliger als der Splash; das liegt an der Aufnahme, die Farbe selbst stimmt.

Creme-Grund, Überschriften in Bricolage Grotesque (immer über `Font.heading(...)` bzw. `.display`/`.cardTitle`, nie direkt per Schriftname), Fließtext DM Sans, Metazeilen in DM Mono als Versalien („25 MIN · FÜR ZWEI“), dunkle Pillen-Buttons. Mehrzeilige Headlines mit `DisplayHeadline` setzen, weil negatives `lineSpacing` in SwiftUI nicht greift.
