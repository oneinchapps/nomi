# nomi in TestFlight und den App Store bringen

Der Plan, um nomi zuerst per TestFlight zu testen und danach im App Store zu veröffentlichen. Bei jedem Schritt steht, wer ihn erledigt. Der Status wird hier gepflegt.

**Voraussetzung:** ein bezahlter Apple-Developer-Account. Das kostenlose „Personal Team“, mit dem die App bisher aufs iPhone kommt, kann weder TestFlight noch den App Store.

## 1. Apple Developer Program (Gregor)

- [ ] **Mitglied werden** unter developer.apple.com/programs: 99 € pro Jahr, Freischaltung meist in ein bis zwei Tagen.
  - **Als Privatperson:** Im Store steht dann der eigene Name als Anbieter.
  - **Als Firma** (z. B. oneinchapps): Dafür braucht es eine D-U-N-S-Nummer, was ein paar Tage bis Wochen dauern kann. Im Store steht dann der Firmenname.
- [ ] **App in App Store Connect anlegen:** Bundle-ID `de.gregorzoller.nomi`, Primärsprache Deutsch, Kategorie „Essen und Trinken“.
- [ ] **Store-Namen klären:** Er muss frei sein, „nomi“ allein ist es möglicherweise nicht. Eine Variante wie „nomi – Essen zu zweit“ einplanen; auf dem Homescreen bleibt „nomi“. Markenrechte vorher prüfen.

## 2. Projekt vorbereiten für TestFlight (Claude)

- [ ] **Team umstellen:** In `project.yml` das Personal Team (`C4JPAJ4QQM`) durch das bezahlte Team ersetzen. Bundle-IDs (`de.gregorzoller.nomi`, `de.gregorzoller.nomi.share`) und die Keychain-Gruppe registriert Xcode dann automatisch.
- [x] **Versionsablauf:** Version und Build-Nummer müssen bei jedem Upload steigen. Siehe „Hochladen“ weiter unten.
- [x] **Datenschutz-Manifest** `PrivacyInfo.xcprivacy` für App und Teilen-Erweiterung: Gründe für genutzte Schnittstellen (z. B. UserDefaults) und Angaben zu erhobenen Daten.
- [x] **Verschlüsselungsvermerk** (`ITSAppUsesNonExemptEncryption = NO`, nur HTTPS). Dann fragt App Store Connect nicht bei jedem Upload nach.
- [x] **Konto löschen in der App:** Apple verlangt das bei jeder App mit Kontoerstellung.
- [x] **Demo-Zugang für Apples Prüfer:innen:** wiederverwendbarer Einladungscode `NOMI-DEMO` für einen Demo-Haushalt mit Beispielrezepten.
  - [ ] Live einrichten vor der Einreichung: `scripts/setup-demo.sh live`

### Hochladen
1. In Xcode als Ziel „Any iOS Device (arm64)“ wählen.
2. Build-Nummer erhöhen: `scripts/bump-build.sh`. Mit neuer Version: `scripts/bump-build.sh 0.2.0`.
3. „Product → Archive“, dann im Organizer „Distribute App → App Store Connect → Upload“.
4. Nach etwa 15 bis 30 Minuten ist der Build in App Store Connect unter TestFlight verfügbar.

### Testende
- **Intern:** bis 100 Personen ohne Apple-Prüfung, sofort verfügbar. Sie müssen Nutzer:innen im App-Store-Connect-Team sein.
- **Extern:** bis 10.000 Personen per E-Mail oder öffentlichem Link. Das braucht eine kurze Beta-Prüfung durch Apple (meist innerhalb eines Tages) und eine Datenschutzerklärung.
- Für die zweite Person im Haushalt ist der öffentliche Link am einfachsten: kein Kabel, keine 7-Tage-Grenze. TestFlight-Builds laufen 90 Tage.

## 3. Zusätzlich für den App Store

- [ ] **Eigener Mailversand (Claude + Gregor):** Der Standard-Mailversand von Supabase schickt Anmeldecodes nur an Mitglieder des Supabase-Teams. Für fremde Nutzer:innen braucht es eigenen SMTP-Versand, z. B. Resend mit eigener Domain. Einladungen per Code funktionieren schon ohne Mail.
- [ ] **Supabase-Tarif (Gregor):** Im kostenlosen Tarif wird das Projekt nach einer Woche ohne Nutzung pausiert. Für echten Betrieb den Pro-Tarif nehmen.
- [x] **Kostenbremse für Claude (Claude):** Tagesbudgets pro Haushalt (2 $) und insgesamt (10 $), Verbrauch protokolliert in `ai_usage` (siehe `AGENTS.md`, Abschnitt „Kosten“).
- [ ] **Ausgabenlimit in der Anthropic Console (Gregor):** Settings → Limits, als letzte Sicherung.
- [ ] **Datenschutzerklärung als URL (Gregor, Claude liefert einen Entwurf):** Pflicht. Sie muss erwähnen:
  - Konto (E-Mail, Name), Profilfoto, Rezepte und Fotos, Einkaufsliste und Wochenplan liegen bei Supabase (EU).
  - Texte und Fotos werden zur Verarbeitung an Anthropic geschickt.
  - Spracheingabe wird möglichst auf dem Gerät erkannt.
- [ ] **Support-URL, Beschreibung, Stichworte und Werbetext** in App Store Connect (Claude liefert Texte).
- [ ] **Datenschutz-Angaben** in App Store Connect: Kontaktdaten (E-Mail, Name), Fotos, Nutzerinhalte (Rezepte, Chat). Alles dient der App-Funktion, nichts dem Tracking.
- [ ] **Altersfreigabe:** Den Fragebogen ausfüllen, inklusive der Frage nach KI-erzeugten Inhalten.
- [ ] **Screenshots für 6,9″-iPhones (Claude):** aus den UI-Tests in der richtigen Größe erzeugen.
- [ ] **Hinweise für die Prüfung:** Demo-Zugang eintragen und kurz erklären, dass die App für Haushalte zu zweit gedacht ist und wie man allein testet.

## Reihenfolge

1. Gregor meldet sich beim Developer Program an.
2. Claude baut parallel die Store-Voraussetzungen ein (Abschnitt 2).
3. Nach der Freischaltung: Team umstellen, ersten Build hochladen, TestFlight mit dem Haushalt.
4. Danach Mailversand, Kostenbremse live, Texte, Screenshots und Einreichung im App Store.
