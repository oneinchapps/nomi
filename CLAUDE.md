# nomnom

Persönliche iOS-App für zwei: Rezepte gemeinsam per KI-Chat und Swipe auswählen, Einkaufsliste, Wochenplan, Kochmodus. UI-Sprache Deutsch.

## Stack
- SwiftUI, iOS 18+, Swift 6 (Default-Isolation `MainActor`)
- Projekt wird mit XcodeGen aus `project.yml` erzeugt; `NomNom.xcodeproj` ist nicht eingecheckt
- Backend: Supabase (Postgres, Auth, Realtime, Edge Functions). Der Anthropic-Key liegt nur als Supabase-Secret vor, nie in der App

## Bauen
```sh
xcodegen generate
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer   # solange xcode-select auf die CommandLineTools zeigt
xcodebuild -project NomNom.xcodeproj -scheme NomNom \
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
- Teilen-Erweiterung `NomNomShare` nutzt Design-System, Modelle und Services der App mit (siehe project.yml) und teilt die Anmeldung über die Keychain-Gruppe `<Team>.de.gregorzoller.nomnom.shared`.

## Tests
- `NomNomTests` (Swift Testing): Zutaten-Parser, Mengenformat, Skalierung, Abteilungs-Zuordnung
- `NomNomUITests`: Onboarding mit zwei Personen und Rezept-Flow (anlegen, öffnen, Portionen skalieren). Gemeinsame Helfer stehen in `UITestSupport.swift`.

Die UI-Tests laufen gegen das lokale Supabase:
```sh
supabase start
xcodebuild test -project NomNom.xcodeproj -scheme NomNom \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -derivedDataPath build
```
Debug-Builds lesen `NOMNOM_SUPABASE_URL`, `NOMNOM_SUPABASE_KEY` und `NOMNOM_RESET_SESSION` aus der Umgebung.

## Live-Sync
Stores laden komplett neu, sobald sich etwas ändert (`observeTable` in `Services/Realtime.swift`). Delete-Events kommen in Supabase Realtime nicht bei gefilterten Abos an, deshalb hört `observeTable` zusätzlich ungefiltert auf Deletes. Neue Tabellen mit Live-Sync in die Publication `supabase_realtime` aufnehmen.

## UI-Test-Fallen
- Die `TabView` hält verborgene Tabs im Accessibility-Baum. Ein `app.buttons[...]` kann deshalb eine unsichtbare Kachel aus einem anderen Tab treffen. Abfragen eingrenzen, z. B. `app.collectionViews.buttons`.
- Zeilen-Buttons brauchen einen `Spacer`, sonst endet die Tippfläche am Textende.
- In Sheets keine zufälligen IDs als Schlüssel für `@State` verwenden: Das Sheet wird bei jedem Neuzeichnen neu erzeugt, der State bleibt aber bestehen.

## Swift-6-Fallen
Die App nutzt Default-Isolation `MainActor`. Closures, die UIKit/SwiftUI auf anderen Threads aufruft (z. B. `UIColor { traits in … }`), müssen `nonisolated`/`@Sendable` sein, sonst stürzt die App zur Laufzeit ab.

## Struktur
- `NomNom/DesignSystem/`: Farben (`Color.canvas`, `.ink`, `.mist` …), Schriften (`Font.display`, `.meta` …), wiederverwendbare Komponenten. Neue Screens nutzen diese Tokens statt eigener Werte.
- `NomNom/Features/<Feature>/`: ein Ordner pro Feature
- `NomNom/Models/`

## Design
Creme-Grund, Serifen-Headlines (Fraunces), Fließtext DM Sans, Metazeilen in DM Mono als Versalien („25 MIN · FÜR ZWEI“), dunkle Pillen-Buttons. Mehrzeilige Headlines mit `DisplayHeadline` setzen, weil negatives `lineSpacing` in SwiftUI nicht greift.
