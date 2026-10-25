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

## Swift-6-Fallen
Die App nutzt Default-Isolation `MainActor`. Closures, die UIKit/SwiftUI auf anderen Threads aufruft (z. B. `UIColor { traits in … }`), müssen `nonisolated`/`@Sendable` sein, sonst stürzt die App zur Laufzeit ab.

## Struktur
- `NomNom/DesignSystem/`: Farben (`Color.canvas`, `.ink`, `.mist` …), Schriften (`Font.display`, `.meta` …), wiederverwendbare Komponenten. Neue Screens nutzen diese Tokens statt eigener Werte.
- `NomNom/Features/<Feature>/`: ein Ordner pro Feature
- `NomNom/Models/`

## Design
Creme-Grund, Serifen-Headlines (Fraunces), Fließtext DM Sans, Metazeilen in DM Mono als Versalien („25 MIN · FÜR ZWEI“), dunkle Pillen-Buttons. Mehrzeilige Headlines mit `DisplayHeadline` setzen, weil negatives `lineSpacing` in SwiftUI nicht greift.
