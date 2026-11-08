# nomi – Wissen für Agents und Entwickler:innen

Persönliche iOS-App für einen Haushalt mit zwei Personen. Sie umfasst:
- nomi als Assistent für alles rund ums Essen, per Text und Sprache,
- das heutige Essen nach Mahlzeiten: allein festlegen oder gemeinsam per Swipe bis zum Match,
- die Rezeptsammlung mit Import aus Links, Social Posts, Fotos und Handschrift,
- eine gemeinsame Einkaufsliste live,
- den Wochenplan und den Kochmodus mit Timern.

Die UI-Sprache ist Deutsch. Diese Datei ist die einzige Wissensquelle des Projekts. `CLAUDE.md` verweist nur hierher.

## Grundsätze für die Arbeit am Projekt

- **Repo:** https://github.com/oneinchapps/nomi, Branch `main`. Pushen mit dem GitHub-Konto `oneinchapps`. Ist lokal ein anderes Konto aktiv, entweder einmalig mitgeben:
  ```sh
  git -c credential.helper= -c 'credential.helper=!f() { echo username=oneinchapps; echo "password=$(gh auth token --user oneinchapps)"; }; f' push
  ```
  oder dauerhaft umstellen mit `gh auth switch --user oneinchapps`.

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
- iPhone und iPad (`TARGETED_DEVICE_FAMILY "1,2"`): iPhone nur hochkant, iPad in allen Ausrichtungen (Pflicht für Split View und Stage Manager). Layouts siehe „iPad“ unter Design.
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
  | `supabase/functions/` | Edge Functions `import-recipe`, `decide`, `assistant`, `invite`, `account`, `speak`, gemeinsamer Code in `_shared/` |
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

## Version und Build

- Version (`MARKETING_VERSION`) und Build (`CURRENT_PROJECT_VERSION`) stehen einmal in `project.yml` und gelten für App und Teilen-Erweiterung.
- Vor jedem Upload nach App Store Connect die Build-Nummer erhöhen: `scripts/bump-build.sh`. Mit neuer Version: `scripts/bump-build.sh 0.2.0`. Das Skript führt auch `xcodegen generate` aus.
- Datenschutz-Manifeste: `Nomi/PrivacyInfo.xcprivacy` und `NomiShare/PrivacyInfo.xcprivacy`. Kein Tracking; erhoben werden E-Mail, Name, Fotos und Nutzerinhalte für die App-Funktion; UserDefaults mit Grund `CA92.1`. Bei neuen erhobenen Daten oder neuen „Required Reason“-Schnittstellen hier ergänzen.
- `ITSAppUsesNonExemptEncryption = false` ist in beiden Info.plists gesetzt; die App nutzt nur HTTPS.
- Den Plan für TestFlight und den App Store mit Status führt `AppStore.md`.

## Backend

**Projekte:**
- Live: `pohguhbhqvurdhnflpek` (eu-central-1), verknüpft per `supabase link`. Der Publishable Key steht in `SupabaseService.swift`.
- Lokal: `supabase start` auf den Ports 553xx (543xx gehört einem anderen Projekt, nicht anfassen). Mails landen in Mailpit unter http://127.0.0.1:55324.

**Migrationen:**
- Schemaänderungen nur als neue Datei in `supabase/migrations/`.
- Lokal einspielen: `supabase migration up --local`.
- Live einspielen: `supabase db push --linked`.
- Stand prüfen, bevor man etwas als „noch nicht live“ meldet: `supabase migration list --linked` (nur lesend, vergleicht lokal und live).

**`supabase config push`:** Der Befehl überträgt die **gesamte** `config.toml` sofort und ohne Rückfrage, auch ohne TTY und auch mit `echo n |`. Er ist schon einmal schiefgegangen: Lokale Standardwerte (MFA aus, Mail-Intervall 1 s, Bestätigungen aus) gingen live. Live-Werte, die bleiben müssen:
- `site_url http://localhost:3000`,
- MFA TOTP an,
- E-Mail-Bestätigung an,
- `max_frequency 60s`,
- `otp_length 6`,
- die OTP-Templates mit Betreff „Dein nomi-Code“,
- der eigene SMTP-Versand über Resend (siehe Mailversand); in `config.toml` steht er bewusst nicht.

Einzelne Auth-Werte ändert man besser gezielt im Dashboard oder über die Management API (`PATCH /v1/projects/<ref>/config/auth` nur mit den betroffenen Feldern).

**Neue Tabellen** brauchen:
- RLS über `public.is_member(household_id)` (security definer, damit Policies nicht rekursiv werden),
- explizite `grant … to authenticated`,
- bei Bedarf gezielt `grant … to service_role` (neue Tabellen haben auch dafür keine Standardrechte).

**Live-Sync:**
- Stores laden komplett neu, sobald sich etwas ändert (`observeTable` in `Services/Realtime.swift`).
- Delete-Events kommen bei gefilterten Abos nicht an. Darum hört `observeTable` zusätzlich ungefiltert auf Deletes.
- Tabellen mit Live-Sync gehören in die Publication `supabase_realtime`.

**Secrets:** `ANTHROPIC_API_KEY` und `ELEVENLABS_API_KEY` liegen lokal in `supabase/functions/.env` und kommen live per `supabase secrets set --env-file supabase/functions/.env`.

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
| `assistant` | nomi als Assistent, siehe unten; mit `mode: "cooking"` Fragen beim Kochen (siehe Kochmodus) |
| `invite` | Einmal-Code einlösen (öffentlich, `auth: "none"`), siehe Einladen |
| `account` | Konto löschen, siehe Konto löschen |
| `speak` | nomis Stimme: Text → MP3 über ElevenLabs, siehe Sprachausgabe |

Neue Gerichte arbeitet `_shared/expand.ts` aus (`expandIdea`); decide und assistant nutzen es beide.

**Prüfen und lokal starten:**
```sh
cd supabase/functions/<name> && deno check --config deno.json index.ts && deno test --config deno.json
supabase functions serve --env-file supabase/functions/.env     # alle Functions lokal, für die UI-Tests
```

**Deployen:** `supabase functions deploy <name> --project-ref pohguhbhqvurdhnflpek`. Live-Stand prüfen: `supabase functions list --project-ref pohguhbhqvurdhnflpek` (Version, `updated_at` in ms) mit `git log -1 -- supabase/functions/<name> supabase/functions/_shared` vergleichen. Live-Deployments bestätigt der Nutzer. In automatisierten Sitzungen sind sie teils gesperrt, dann gibt man den Befehl an ihn weiter.

**Nach einer neuen Function:** in `config.toml` einen Block `[functions.<name>]` mit `verify_jwt = false`, `import_map` und `entrypoint` anlegen. Der lokale Server muss neu starten, damit die Konfiguration greift.

## Kosten (Kostenbremse für Claude)

- **Messen:** Jede Claude-Anfrage läuft über `structured()` in `_shared/recipe.ts`. Ein `UsageMeter` (`_shared/budget.ts`) zählt die tatsächlichen Tokens aus der API-Antwort. Die Kosten rechnet er mit den Preisen von Claude Opus 5.5 um: 4 $ pro Million Eingabe-Tokens, 20 $ pro Million Ausgabe-Tokens.
- **Protokoll:** Tabelle `ai_usage`, eine Zeile pro Function-Anfrage mit Function, Tokens und `cost_micros` (Millionstel Dollar). Mitglieder dürfen den Verbrauch ihres Haushalts lesen.
- **Prüfen:** Vor der ersten Claude-Anfrage ruft jede Function `ensureBudget` auf; `ai_spend_today` liefert den Verbrauch seit Mitternacht Berliner Zeit. Ist ein Budget aufgebraucht, antwortet die Function mit 429 und einer freundlichen Meldung („nomi hat für heute genug gekocht …“), die die App anzeigt.
- **Budgets** (Function-Secrets, sonst Standard):
  - `AI_BUDGET_HOUSEHOLD_DAILY_USD`: pro Haushalt und Tag, Standard 2 $.
  - `AI_BUDGET_TOTAL_DAILY_USD`: alle Haushalte zusammen, Standard 10 $.
- **Erfahrungswerte:** Eine nomi-Antwort kostet bei kleiner Sammlung etwa 2 Cent. Vorschlagsrunden (alle Rezepte mit Zutaten im Prompt), Ausarbeiten und Foto-Import sind teurer.
- **Letzte Sicherung:** ein monatliches Ausgabenlimit in der Anthropic Console (Settings → Limits). Das setzt der Nutzer selbst.
- **Neue Function mit Claude:** `ensureBudget` vor dem Aufruf, `meter` an `structured()` durchreichen, `saveUsage` im `finally`.
- **Sprachausgabe** (`speak`) zählt fürs selbe Tagesbudget: `saveSpend` mit Kosten nach Zeichen (`ELEVENLABS_USD_PER_1K_CHARS`, Standard 0,05 $), protokolliert als `speak`, Modell `elevenlabs:<modell>`, `input_tokens` = Zeichen.

## Funktionen der App

### Anmeldung und Haushalt
- **Anmeldung** per E-Mail-Code (OTP, 6 Stellen), ohne Passwort. Sign in with Apple braucht einen bezahlten Developer-Account und kommt später.
- **Haushalt:** `create_household` und `join_household` (RPCs). Alle Daten hängen am Haushalt.
- **Mailversand:** Live verschickt Resend die Codes per SMTP, der Standard-Mailversand von Supabase erreicht nur Mitglieder des Supabase-Teams. Lokal landen Mails weiter in Mailpit.
  - Absender `code@mail.oneinchapps.com`, Name „nomi“. Die DNS-Einträge (DKIM, MX und SPF für `send.mail…`) liegen bei IONOS, Resend sendet aus der Region eu-west-1.
  - SMTP-Werte im Dashboard (Authentication → Emails → SMTP Settings): Host `smtp.resend.com`, Port 465, Benutzer `resend`, Passwort ist ein Resend-API-Key nur mit Sendezugriff. Der Key liegt nirgends im Repo.
  - Grenzen: Supabase schickt mit eigenem SMTP höchstens 30 Mails pro Stunde (`rate_limit_email_sent`), Resend kostenlos 100 am Tag.
  - **Vorlage** `supabase/templates/otp.html` (Entwurf B aus `design/mail/`): Chefi winkt, Wortmarke, Code als Himbeer-Pille, Vorschauzeile mit Code, nur helles Farbschema. Der Code bleibt eine durchgehende Zahl, damit man ihn kopieren kann. Schriften kommen über Google Fonts (Apple Mail), sonst die Systemschrift.
  - **Bilder** liegen im öffentlichen Bucket `mail` (`chefi.png`, `wordmark-on-light.png` aus `design/mail/assets/`), die Vorlage verweist fest auf die Live-URLs. Lokal lädt man sie mit dem lokalen `SERVICE_ROLE_KEY` hoch, live über das Dashboard (Storage → mail).
  - **Live ändern:** Die Vorlage im Dashboard unter Authentication → Emails → Templates bei „Confirm signup“ und „Magic Link“ einfügen, Betreff „Dein nomi-Code“. Nicht per `config push`.
  - **Lokal prüfen:** Ändert sich `config.toml` oder die Vorlage, `supabase stop && supabase start` (ein Neustart des Auth-Containers liest sie nicht neu). Dann einen Code anfordern, die Mail aus Mailpit holen (`/api/v1/message/<id>`, Feld `HTML`) und mit `swift design/mail/render-mail.swift --einzeln mail.html mail.png` ansehen.
  - Einladungen per Code funktionieren auch ohne Mail.

### Konto löschen
- In der Haushaltsübersicht gibt es „Konto löschen“ mit Sicherheitsabfrage. Apple verlangt das bei jeder App mit Kontoerstellung.
- Die Edge Function `account` (`{ action: "delete" }`) erledigt Folgendes:
  - Sie löscht die eigenen Chat-Nachrichten; ohne Absender sähen sie sonst wie nomi aus.
  - Sie löscht das eigene Profilfoto.
  - Ist die Person allein im Haushalt, löscht sie den ganzen Haushalt per Cascade, dazu die Rezeptfotos im Speicher.
  - Zum Schluss löscht sie das Anmeldekonto.
- Die nötigen Rechte für `service_role` stehen in der Migration `account_deletion`.

### Demo-Zugang (App-Prüfung)
- Ein wiederverwendbarer Einladungscode (`household_invites.reusable`) führt immer in dasselbe Demo-Konto und wird beim Einlösen nicht verbraucht.
- `scripts/setup-demo.sh local|live` legt einen Demo-Haushalt mit vier Beispielrezepten und den Code `NOMI-DEMO` an (anderer Code über `DEMO_CODE=…`).
- In der App: „Ich habe eine Einladung“ → Code, Name beliebig. Der Code gehört in die Prüfhinweise in App Store Connect.

### Einladen (zweite Person)
- **Einmal-Code:** 8 Zeichen ohne verwechselbare Zeichen, 7 Tage gültig. Die RPC `create_invite` erzeugt ihn, verschickt wird er über das Teilen-Menü per WhatsApp oder Nachricht. Im Code: `InviteCard` und `InviteCode` (Format „XXXX-XXXX“, findet den Code auch in einer eingefügten Nachricht).
- **Einlösen:** Die Function `invite` legt ein Konto `<uuid>@einladung.nomi.invalid` an, trägt es in den Haushalt ein und gibt einen Magic-Link-`token_hash` zurück. Die App macht daraus per `verifyOTP(tokenHash:type: .magiclink)` eine Sitzung.
- **Neues Handy:** `create_invite(member)` erzeugt einen Anmeldecode für ein bestehendes Mitglied. Das geht nur für Konten ohne echte Mail (`is_invited_account`).
- **`join_household`** nimmt Einmal-Codes und den alten 6-stelligen Haushalts-Code.

### Tabs
- Reihenfolge: **nomi, Heute, Woche, Rezepte, Einkauf**. `AppNavigation` (`tab`, `decideMeal`) erlaubt Sprünge zwischen Tabs.
- **Toolbar:** Jeder Hauptscreen setzt sie selbst per `mainToolbar { … }`: Logo links, eigene Knöpfe, das Profil-Icon immer ganz rechts. `TabRoot` setzt keine Toolbar-Elemente, weil die eines äußeren Rahmens vor denen des Screens landen würden.

### Profil
- **Anzeige:** `ProfileButton` oben rechts zeigt das Profilfoto (`MemberAvatar`) oder die Initialen und öffnet die Haushaltsübersicht.
- **Ändern:** In der Übersicht ändert man sein Foto über `AvatarEditor`: auswählen, aufnehmen oder entfernen.
- **Speicher:**
  - `AppModel.setAvatar` schneidet quadratisch zu, verkleinert auf 600 px und lädt nach `avatars/<household>/<user>/<uuid>.jpg` hoch, mit neuem Namen gegen Caches.
  - Die URL steht in `household_members.avatar_url`; das alte Bild wird gelöscht.
- **Rechte:** Schreiben darf jede Person nur in den eigenen Ordner. Die Speicherregel vergleicht mit `auth.uid()`, darum UUIDs im Pfad kleinschreiben.
- **Live:** Über Live-Sync von `household_members` sieht die andere Person das Foto sofort.

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
  - `Speaker` liest Antworten auf gesprochene Fragen vor (abschaltbar), siehe Sprachausgabe.
  - Audio-Callbacks laufen in der `nonisolated` Klasse `RecognitionSession`.
  - Auf dem Gerät ist die Sprache noch nicht getestet.

### Sprachausgabe (nomis Stimme)
- `Speaker` (`Features/Nomi/Voice.swift`) holt die Stimme über `CloudVoice` von der Function `speak` (ElevenLabs, MP3) und spielt sie mit `AVAudioPlayer`. Klappt das nicht innerhalb von 8 s, liest `AVSpeechSynthesizer` mit der besten deutschen Gerätestimme vor.
- `isSpeaking` ist schon während des Ladens wahr, damit der Kochmodus nichts als Befehl wertet. Meldungen einer abgebrochenen Ansage zählen nicht (Abgleich über `ObjectIdentifier`).
- `CloudVoice` merkt sich die letzten 40 Sätze im Speicher. Antwortet `speak` mit 503 (nicht eingerichtet) oder 429 (Tageslimit), fragt die App bis zum nächsten Start nicht mehr.
- **Function `speak`:** Text gesäubert und auf 1500 Zeichen gekürzt (`voice.ts`), Modell `ELEVENLABS_MODEL` (Standard `eleven_v4_turbo`, für Echtzeit), `language_code: "de"`, `mp3_44100_64`. Stimme ist „Ben“ (`DEFAULT_VOICE_ID`, gewählt nach Hörprobe aus Ben, Lucy Fennek, Mark und Jessica), übersteuerbar per `ELEVENLABS_VOICE_ID`. Fehlt der Schlüssel, antwortet die Function mit 503.
- Bibliotheksstimmen brauchen beim ersten Aufruf bis zu 12 s (kalt), danach rund 0,3 s bis zum ersten Ton. Der Schlüssel „nomi“ in ElevenLabs hat ein eigenes Credit-Limit; ist es aufgebraucht, kommt `quota_exceeded` (die Function meldet 502, die App liest mit der Gerätestimme).
- UI-Tests setzen `NOMI_LOCAL_VOICE=1` und geben so nichts für Stimmen aus.

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
  - Toolbar: Zahnrad für die Einstellungen fürs Einkaufen, links vom Profil.
  - Die Liste wird aus Rezepten gefüllt und zusammengeführt (`ShoppingMerge`, Einheiten vergleichbar gemacht), nach Abteilung sortiert und live gemeinsam abgehakt.
  - Jeder Artikel steht nur einmal auf der Liste: Kommt etwas dazu, das schon unter „Erledigt“ liegt, öffnet `ShoppingMerge.merge` diesen Eintrag wieder, mit der neuen Menge (die alte war schon gekauft). Ein offener Eintrag geht dabei vor; „Rückgängig“ legt ihn zurück zu „Erledigt“.
  - Wiederkehrende Einträge stehen in `staple_items`.
  - **Kategorie wechseln:** Einen offenen Eintrag halten und in eine andere Kategorie ziehen. Leere Kategorien erreicht man per Wischen nach rechts („Abteilung“).
    - Die offenen Einträge sind dafür eine flache Liste aus Überschriften und Einträgen mit `onMove`; `CategoryMove` bestimmt die Kategorie aus der Überschrift über der Ablagestelle.
    - Gewählt wird überall im selben Blatt `CategoryPickerSheet`: alle Kategorien als Chips, die aktuelle mit Haken, `Aisle.guess` als dunkler Vorschlag.
    - **Zuordnungen** im Zahnrad (`CategoryMappingsView`, Entwurf `design/shopping/zuordnungen.png`): alle gemerkten Artikel nach Kategorie, mit Suche. Tippen ändert (`ShoppingStore.assign`, offene Einträge wandern mit), Wischen vergisst (`forget`), „+“ legt vorab an. Gespeichert ist nur der kleingeschriebene Name; angezeigt wird die Schreibweise von Liste, Standardartikeln oder Rezepten (`CategoryMappings.displayName`).
    - Der Haushalt merkt sich die Wahl in `aisle_preferences` (Schlüssel `ShoppingMerge.key`, dazu `category_id` bei eigenen Kategorien). Sie geht beim Hinzufügen vor Rezept, KI und Raten (`ShoppingMerge.applyPreferences`, `applyCategories`).
  - **Supermärkte und Kategorien** (Zahnrad im Einkauf, `ShoppingSettingsSheet`):
    - Kategorien = die 11 festen Abteilungen (`Aisle`, Postgres-Enum) plus eigene des Haushalts. `shopping_categories` hält Umbenennungen fester Abteilungen (mit `aisle`) und eigene Kategorien (ohne). Schlüssel in der App: `CategoryKey` (`aisle:<wert>` oder UUID).
    - Einträge behalten immer ihre feste Abteilung; `shopping_items.category_id` legt sie zusätzlich in eine eigene Kategorie. Wird die gelöscht (`on delete set null`), gilt wieder die Abteilung. KI und Raten ordnen nur in feste Abteilungen ein.
    - `shopping_stores.category_order` ist die Laufreihenfolge pro Supermarkt; Fehlendes hängt `CategoryCatalog.ordered(for:)` hinten an. Ohne Supermarkt gilt die Standard-Reihenfolge, die Pille „Sortiert für …“ erscheint erst ab einem Supermarkt.
    - Welcher Supermarkt aktiv ist, gilt pro Person und liegt in den UserDefaults (`activeStore.<haushalt>`); Supermärkte und Reihenfolgen teilt der Haushalt live.
  - **Autovervollständigung:** Beim Tippen ersetzen Vorschlags-Chips die Standardartikel. Ein Tipp setzt den Eintrag direkt auf die Liste, die eingetippte Menge bleibt („2 l Mi“ → „2 l Milch“).
    - Die Logik steht getestet in `ShoppingSuggestions`.
    - Quellen nach Gewicht: eigener Verlauf, Standardartikel, die Liste, Rezeptzutaten, Grundwortschatz.
    - Rangfolge: Treffer am Namensanfang vor Treffer am Wortanfang vor Treffer im Wort (ab 3 Zeichen). Groß-/Kleinschreibung und Umlaute zählen nicht.
    - Der Verlauf (`ShoppingHistory`) liegt pro Haushalt in den UserDefaults, nur auf dem Gerät. Erledigtes verschwindet beim „Leeren“ aus der Datenbank.
  - Die Anzahl offener Einträge steht im Kreis.
  - „Erledigt“ (Abgehaktes) ist beim Öffnen zugeklappt; der Kopf klappt auf (`cart-toggle`).
  - **Live einkaufen** (`LiveShoppingView`, Entwurf B aus `design/shopping/live-einkaufen.png`): „Einkaufen starten“ unter dem Eingabefeld, sobald etwas offen ist und nicht getippt wird.
    - Vollbild wie der Kochmodus, Bildschirm bleibt an. Eine Seite pro Abteilung in der Reihenfolge des Supermarkts (`LiveShopping.pages`), abgehakte Einträge bleiben an ihrem Platz. Wer das Letzte einer Abteilung abhakt, springt nach 0,6 s zur nächsten mit Offenem.
    - Abgleich: Realtime wie immer, dazu im Modus alle 3 s `load()` und beim Zurückkehren in die App. Eigene Haken, die noch gespeichert werden, gehen beim Laden vor (`pendingChecks`, `LiveShopping.applyPending`), sonst springen sie kurz zurück.
    - Haken der anderen Person leuchten 4 s grün (`partnerHighlights`, erkannt in `load()` über `LiveShopping.newlyCheckedByOthers`).
    - „Sam kauft mit“: Realtime Presence auf dem Kanal `shopping-live-<haushalt>`, Schlüssel ist die User-ID (`ShoppingPresence`), ohne Tabelle.
    - Auge oben rechts blendet Abgehaktes aus und ein (`@AppStorage("liveShopping.hidesCart")`, pro Gerät; `NOMI_RESET_SESSION` setzt es zurück). Was die andere Person gerade abgehakt hat, bleibt sichtbar, solange es aufleuchtet (`LiveShopping.visibleItems`).
    - Seiten gibt es nur für Abteilungen, in denen beim Start etwas offen ist (`startedWith`); kommt während des Einkaufs Offenes in eine andere Abteilung, bekommt sie eine Seite. Der Fortschritt zählt nur die gezeigten Abteilungen.
    - Halten öffnet die Kategorie-Wahl (`CategoryPickerSheet`), danach zeigt ein Hinweis „Vesper Käse → Kühlregal“ mit „Hinspringen“. Das Loslassen nach dem Halten würde sonst abhaken, darum `swallowTap`.
    - Ist alles abgehakt: „Alles erledigt!“ mit „Fertig, Liste leeren“ oder „Liste behalten“.
- **Woche:**
  - Die Pfeile stehen neben der Kalenderwoche, die Headline hat die volle Breite.
  - Tage als Datumsspalte (Entwurf `design/week/`): links Wochentag und Tageszahl, heute im Himbeer-Kreis, rechts die Gerichte.
  - Einträge zeigen die Mahlzeit, die Rezeptauswahl lässt die Mahlzeit wählen.
  - Einträge lassen sich halten und auf einen anderen Tag ziehen (`.draggable`/`.dropDestination`, hier in einer `ScrollView` problemlos). Sie behalten die Mahlzeit und kommen als letzter Gang ans Ende (`MealPlanEntry.moved`). Die Mahlzeit wechselt man im „…“-Menü.
  - „Zutaten der Woche einkaufen“ füllt die Einkaufsliste.

### Kochmodus
- `Features/Cooking`: Vollbild, der Bildschirm bleibt an, Portionen sind einstellbar.
- Timer laufen über einen Endzeitpunkt (`CookingTimers`).
- Geklingelt wird über **AlarmKit** (`CookingAlarm`, iOS 26): ein System-Timer pro Schritt, der auch bei Stummschaltung, gesperrt und im Hintergrund klingelt. Die Rückfrage kommt beim ersten Timer (`NSAlarmKitUsageDescription` in `project.yml`). „OK“ in der App lässt ihn verstummen, Pause und Zurücksetzen brechen ihn ab.
  - Unter iOS 26.0 braucht `AlarmPresentation.Alert` noch einen `stopButton`, ab 26.1 ist der veraltet; darum `#available`.
  - `AlarmAttributes` werden kodiert: feste Farbe statt `Color.brand` (dynamische Farben gehen verloren).
- Ohne AlarmKit-Erlaubnis: lokale Mitteilung für den Hintergrund (bei Stummschaltung lautlos) und in der offenen App ein eigener Ton (`TimerChime`, Audio-Sitzung `.playback`, übergeht den Stummschalter). Hört nomi gerade zu, bleibt die Sitzung `.playAndRecord` (übergeht den Stummschalter ebenso).
- Start aus der Rezeptansicht oder per „Jetzt kochen“ im Heute-Tab.
- **Timer-Alarm** (`TimerAlarmView`, Entwurf A in `design/cooking/timer-alarm.png`): Vollbild über allem, auch über der Leiste. Chefi hüpft hinter der „Scheibe“ hoch, klopft zweimal (Wackeln per `keyframeAnimator`, Haptik), drückt Pfoten (`GlassPaw`) und Nase ans Glas und winkt dann neben der Karte „Alles klar“. Die Lage richtet sich nach dem Gesicht (60 % von oben im Raster). Mit „Bewegung reduzieren“ gleich das letzte Bild.
- **Rezept fertig** (`CookingDoneView`, Entwurf B in `design/cooking/rezept-fertig.png`): Chefi tanzt mit Lachaugen und Löffel (sechs Wipper), Herzen steigen links und rechts auf (`RisingHearts`, rein aus der Zeit berechnet), dann bleibt er mit Herzaugen stehen und atmet leise. Startet erst, wenn die letzte Seite wirklich gezeigt wird (`isActive`), weil die Seitenansicht Seiten vorab anlegt. Die Herz-Zeitleiste hält danach an, sonst rendert sie endlos weiter.
- **„Hey nomi“** (Sprachsteuerung, Entwurf B in `design/cooking/sprachsteuerung.png`): Mikro-Knopf in der Leiste (`voice-toggle`), merkt sich das Gerät (`@AppStorage("cooking.voice")`).
  - **Zuhören** (`Services/CookingListener`): `SpeechAnalyzer` von iOS 26 mit `SpeechTranscriber`, sonst `DictationTranscriber`, durchgehend und nur auf dem Gerät. Das deutsche Modell lädt iOS beim ersten Mal (`AssetInventory`). Audio-Sitzung `.playAndRecord` mit `.defaultToSpeaker` und `.mixWithOthers` (Musik läuft weiter). `contextualStrings` enthalten „nomi“, sonst schreibt die Erkennung oft „Naomi“.
  - **Weckwort und Befehl** (getestet in `Models/VoiceCommands.swift`): `WakeWord` findet „nomi“ in vielen Schreibweisen; `VoiceTurn` sammelt nach dem Weckwort die Segmente der Erkennung bis zu 1,2 s Sprechpause (auch „Hey nomi.“ … „Wie viel Salz?“) und ignoriert Segmente, in denen nomi selbst spricht. `CookingCommand.parse` erkennt weiter, zurück, nochmal, Zutaten, Menge („wie viel Salz“ → `Ingredient.best`), Timer starten/stoppen, Restzeit, „alles klar“ (beendet den Alarm) und fertig. Navigation nur bei kurzen Sätzen; alles ab zwei Wörtern sonst ist eine Frage.
  - **Fragen** gehen an `assistant` mit `mode: "cooking"` (`cooking.ts`): Die App schickt Titel, umgerechnete Zutaten, Schritte und die aktuelle Seite. Antwort kurz zum Vorlesen, nichts landet im Verlauf. Kostenbremse wie immer, protokolliert als `assistant-cooking`.
  - **Ablauf** (`CookingVoice`): bereit → „Hey nomi“ (Zuhören: Bild dimmt, Rand leuchtet, Chefi springt hoch) → Befehl → Antwort in der Blase neben Chefi, vorgelesen über `Speaker` mit `managesSession = false` (sonst verstummt das Mikrofon). Tipp auf Chefi oder die Antwort hört ohne Weckwort zu, Tipp auf die gedimmte Fläche bricht ab. Im Hintergrund und bei Unterbrechungen (Anruf, System-Alarm) wird neu gestartet.
  - Vorlesen: `CookingSpeech.speakable` schreibt Einheiten aus („2 EL“ → „2 Esslöffel“), sonst buchstabiert die Stimme.

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
- Wischaktionen schreiben immer weiß: nie mit `Color.ink` einfärben (im Dunkelmodus fast weiß), sondern mit `Color.swipeNeutral`.

**iPad** (Entwurf B in `design/ipad/vorschlaege.png`): Entschieden wird nach verfügbarer Breite, nicht nach Gerät – ein schmales Fenster im Split View sieht aus wie das iPhone. Hilfen in `DesignSystem/Layout.swift`: `trackWidth($width)`, `readableColumn()`, `Metrics.readableWidth` (680), `.wideWidth` (900), `.boardWidth` (1100).
- **Lesespalte** für nomi-Chat, Heute, Formulare, Willkommen und die Seiten im Live-Einkauf. `BrandHeader(contentWidth:)` setzt den Text im Kopf über die Spalte, die Fläche bleibt voll breit.
- **Rezepte:** Raster mit `.adaptive(minimum: 200)` ab 900 pt; Rezept zweispaltig (links Bild, Portionen, Zutaten; rechts Aktionen, Schritte), beide Seiten scrollen getrennt.
- **Kochmodus:** ab 900 pt Zutaten links fest (die des aktuellen Schritts hervorgehoben), Schritte rechts mit 34-pt-Text.
- **Woche:** Board mit sieben Spalten erst ab 1100 pt (quer); hochkant die Liste in der Lesespalte. Ziehen zwischen Tagen geht in beiden.
- **Einkauf:** ab 900 pt Abteilungen in zwei bzw. ab 1100 pt drei Spalten (`ShoppingColumns.split`, Laufreihenfolge bleibt), „Einkaufen starten“ im Kopf. Ziehen zwischen Abteilungen gibt es dort nicht (`onMove` geht nur in einer `List`); Halten öffnet ein Menü mit „Abteilung“ und „Löschen“.
- Die Tab-Leiste ist auf dem iPad die iOS-26-Kapsel oben (nur Text, ohne unsere Icons).

**Gleiche Kopfhöhe:** Rezepte, Einkauf und Woche haben exakt gleich hohe Köpfe:
- `BrandHeader(bottomPadding: 22)` mit einer Zeile `DisplayHeadline`, rechts daneben höchstens kleine Elemente (Anzahl-Kreis, Wochenpfeile).
- Zusätzliche Zeilen gehören in den Inhalt darunter, nicht in den Kopf (z. B. „Zur aktuellen Woche“).
- nomi und Heute sind bewusst Ausnahmen.

**Headlines und Buttons:**
- Mehrzeilige Headlines setzt man mit `DisplayHeadline`, weil negatives `lineSpacing` in SwiftUI nicht greift. Zeilen brechen nie um, sondern werden notfalls kleiner und behalten dabei ihre volle Zeilenhöhe.
- Dunkle Pillen-Buttons: `.primary` ist einzeilig, `.secondary` ist der Rahmen-Button.

**Illustrationen im Stil „Linie“** statt Emojis:
- feine Tintenkontur, Pastellflächen, Himbeer-Akzent,
- `FoodIllustration`: 23 Motive, gewählt nach Titel, Kategorie oder Ernährungsweise,
- `ReactionIllustration` für Jubel, Warten, Lecker, Korb und Ratlos.
- Alle Motive zeigt der Start mit `NOMI_GALLERY=1`.

**Maskottchen Chefi** (kleiner Koch in Mint, Kochmütze mit Himbeer-Band, Holzlöffel):
- Entwürfe liegen in `design/mascot/`. `ChefiView` zeichnet dieselben Formen; Löffel-Neigung und -Höhe sind animierbar, dazu gibt es Zwinkern, Winken, eine Pfote an der Scheibe (`pawOnGlass` + `GlassPaw`), Münder (`mouth: .oh`, `.laugh`) und Augen (`eyes: .happy` für ^^, `.hearts`; glückliche Augen bekommen Herzbäckchen).
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
- `NomiTests` (Swift Testing): Parser, Mengen, Skalieren, Zusammenführen, Einkaufsvorschläge, Live-Einkauf, Zuordnungen, Einladungscodes, Kategorien, Kochhistorie, Function-Datumsformat.
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
| `NOMI_LOCAL_VOICE` | nur Gerätestimme, keine Anfragen an `speak` (Standard in `UITestSupport`) |
| `NOMI_VOICE_TEST` | „Hey nomi“ ohne Mikrofon; Leuchtrand steht still, Sprechpause 3 s |
| `NOMI_VOICE_SCRIPT` | Sätze durch „\|“ getrennt; jeder Tipp auf Chefi „sagt“ den nächsten (siehe `CookingVoiceUITests`) |

**Screenshots** aus einem Lauf holen und ansehen:
```sh
xcrun xcresulttool export attachments --path build/run.xcresult --output-path <ordner>
```
Die Dateinamen stehen in `manifest.json` unter `suggestedHumanReadableName`.

**Animationen:** In der App lassen sie sich im Test als Bildfolge festhalten: `XCUIScreen.main.screenshot()` in einer Schleife mit kurzer Pause wartet nicht auf „idle“ (siehe `CookingFlowTests`, `62-alarm-…`). Für den Start vor der App nimmt man ein Video auf und zieht Einzelbilder heraus:
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
- **iPad:** Tabs über `app.tab("Heute")` ansprechen – auf dem iPad gibt es kein `tabBars`-Element, die Kapsel-Knöpfe hängen direkt in der Hierarchie. „Abteilung“ im Einkauf über `chooseAisle(app, item:)` (iPhone wischen, iPad halten). Querformat-Screenshots mit `XCUIScreen.main.screenshot()`; `app.screenshot()` liefert quer ein verschobenes Bild. Beim Verkleinern solcher PNGs `ffmpeg` statt `sips` nehmen, `sips` wertet die Ausrichtung falsch aus.
- iPad-Tests: `-destination 'platform=iOS Simulator,name=iPad Pro 13-inch (M5)'`; `IPadLayoutTests` dreht ins Querformat und prüft Raster, Board, Spalten und Kochmodus (auf dem iPhone übersprungen).
- Die `TabView` hält verborgene Tabs im Accessibility-Baum. `app.buttons[...]` kann eine unsichtbare Kachel treffen; Abfragen eingrenzen, z. B. `app.collectionViews.buttons`, oder eindeutige Labels vergeben.
- Zeilen-Buttons brauchen einen `Spacer`, sonst endet die Tippfläche am Textende.
- In Sheets keine zufälligen IDs als Schlüssel für `@State` verwenden: Das Sheet wird neu erzeugt, der State bleibt.
- Mehrzeilige `TextField`s lösen bei „Senden“ kein `onSubmit` aus, sondern fügen einen Umbruch ein. Deshalb schicken die Chat-Felder ab, sobald ein Umbruch auftaucht.
- Formulare (`FormScreen`) bleiben mit `defaultScrollAnchor(.bottom, for: .sizeChanges)` unten verankert, damit Felder nicht hinter Tastatur und Button verschwinden. `scrollTo` funktionierte dort nicht.
- Nach dem Eintreffen neuer Inhalte scrollen Ansichten animiert (z. B. zum Kartenstapel). Ein Tipp in dieser Zeit verfehlt den Knopf, ohne Fehler. Im Test vor dem Tippen kurz warten.
- Ziehen in Listen: `.draggable`/`.dropDestination` zwischen Sections einer `List` kam nicht an, `onMove` in einem einzigen `ForEach` schon. Ein `.contextMenu` an derselben Zeile schluckt das Halten, dann startet kein Zug. Im Test langsam ziehen: `press(forDuration:thenDragTo:withVelocity: .slow, thenHoldForDuration:)`.
- `launchFresh(extraEnvironment:)`: Werte des Tests gehen vor den Standards, z. B. `NOMI_DISABLE_NOTIFICATIONS: "0"`, um AlarmKit im Test zu nutzen. Die Rückfrage tippt der Test auf dem Springboard weg („Erlauben“/„Allow“).
- Ständig laufende Animationen (`TimelineView(.animation)`) lassen XCUITest-Abfragen auf „idle“ warten, bis sie scheitern. Im Testmodus anhalten (siehe `ListeningGlow`).
- Eine per `if` eingeblendete Ebene fängt beim Ausblenden (Transition) noch Tipps ab. Ebenen, unter denen sofort wieder getippt wird, dauerhaft einbauen und mit `opacity` und `allowsHitTesting` schalten (siehe `voiceListening` im Kochmodus).
- Ein unsichtbarer Test-Knopf bzw. ein Textfeld über der Seitenansicht des Kochmodus bekam im Test keine Tipps bzw. keinen Fokus. Test-Eingaben darum über einen echten Knopf (Chefi) einspeisen.
- Eingabefelder nicht bei jedem Tastendruck umschreiben (z. B. Formatieren); XCUITest und schnelles Tippen verlieren sonst Zeichen. Erst formatieren, wenn die Eingabe vollständig ist.

**Swift 6:**
- Mit Default-Isolation `MainActor` müssen Closures, die Frameworks auf anderen Threads aufrufen, `nonisolated` bzw. `@Sendable` sein. Sonst stürzt die App zur Laufzeit ab. Betroffen sind z. B. `UIColor { traits in }`, Decoder-Datumsclosures, Speech-Callbacks und Audio-Taps.
- `AVAudioPCMBuffer`: `frameLength` nie größer als `frameCapacity`. Kapazität aus denselben gerundeten Einzelwerten berechnen wie das Füllen, sonst bricht AVFoundation mit einer Exception ab.
- Laufende `.task`-Closures sehen eine Kopie der View; Werte, die sich ändern, über `@State` spiegeln (siehe `SplashView.ready`).

**SwiftUI und iOS:**
- In der Toolbar stauchen sich Bilder auf Symbolgröße. Darum gibt `Wordmark` feste Breite und Höhe vor.
- Der Functions-Client dekodiert ohne Datumsformat; Postgres liefert Mikrosekunden. Antworten deshalb über `FunctionDecoding.decoder` lesen.
- `CTLineGetImageBounds` rechnet die aktuelle Textposition mit ein; in Render-Skripten vor dem Messen `textPosition = .zero` setzen.

## Store und Website

- **Website** `website/` für https://nomi.oneinchapps.com: Startseite, `datenschutz.html`, `support.html`, `impressum.html`. Rein statisch, Schriften und Bilder lokal (keine Anfragen an Dritte, keine Cookies). Platzhalter in eckigen Klammern (Anschrift, Kontakt-Mail, Hoster, Fristen) vor dem Veröffentlichen füllen. Ansehen: `swift design/mail/render-mail.swift --einzeln website/<seite>.html <bild>.png`.
- **Datenschutzerklärung** aktuell halten, wenn neue Daten oder Dienstleister dazukommen (z. B. neue Tabellen, neue Function mit Claude). Die Namen der Haushaltsmitglieder gehen in den Prompts von `assistant` und `decide` mit, E-Mail-Adressen nicht.
- **Store-Texte, Datenschutz-Etiketten, Prüfhinweise:** `store/app-store.md`.
- **Screenshots:** `scripts/store-screenshots.sh [iphone|ipad]` (iPhone 17 Pro Max = 6,9″, iPad Pro 13″ quer, Statusleiste 9:41) legt Rohbilder in `store/screenshots/roh/`, dann `swift store/render-store-frames.swift` → `store/screenshots/{iphone,ipad}/` mit Überschrift in den von Apple verlangten Größen. Stil B (Entwurf `store/vorschlag-dynamisch.png`): Gerät per `CIPerspectiveTransform` geneigt, Neigung und Chefis Seite wechseln von Bild zu Bild, Chefi schaut mit wechselnder Pose hinter dem Gerät hervor.
  - Der Test `StoreScreenshotTests` läuft nur über das Skript: Es reicht den lokalen Service-Schlüssel per `TEST_RUNNER_NOMI_SERVICE_KEY` herein. Normale Daten legt die zweite Person mit ihrem Zugang an (RLS wie in echt); den Service-Schlüssel braucht es nur für Chat-Zeilen von nomi und Alex. `service_role` hat absichtlich nicht überall Rechte – nicht pauschal freigeben, sonst verdeckt lokal, was live fehlt.
  - Querformat-Screenshots sind hochkant mit Drehangabe gespeichert; das Skript schreibt sie mit `ffmpeg` in echte Pixelmaße um.

## Offen und zu prüfen

- Auf dem iPhone noch ungetestet sind die Sprache (Mikrofon, Erkennung, Vorlesen), „Hey nomi“ im Kochmodus (Weckwort-Erkennung, laute Küche, Vorlesen bei laufendem Mikrofon, Laden des Sprachmodells), der Farbübergang vom Startbildschirm zum Splash und die Koch-Timer per AlarmKit bei Stummschaltung (im Simulator klingeln sie im Hintergrund).
- „Sam kauft mit“ (Presence im Live-Einkauf) ist nur gebaut, nicht mit zwei Geräten getestet; die UI-Tests steuern die zweite Person über REST, das erreicht Presence nicht.
- Für TestFlight und App Store gilt der Plan mit Status in `AppStore.md`.
- Sign in with Apple kommt, sobald es einen bezahlten Developer-Account gibt.
