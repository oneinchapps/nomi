#!/bin/sh
# Richtet den Demo-Zugang für Apples App-Prüfung ein: ein eigener Demo-Haushalt mit Beispielrezepten
# und ein wiederverwendbarer Anmeldecode, der immer in dasselbe Demo-Konto führt.
# In der App: „Ich habe eine Einladung“ → Code eingeben (Name beliebig).
#
#   scripts/setup-demo.sh local          # gegen supabase start (zum Ausprobieren)
#   scripts/setup-demo.sh live           # gegen das Live-Projekt
#   DEMO_CODE=ABCD2345 scripts/setup-demo.sh live
#
# Der Code steht danach in den Prüfhinweisen in App Store Connect. Mehrfach ausführen legt jeweils
# einen neuen Demo-Haushalt an; alte lassen sich in der Datenbank löschen (households, Cascade).
set -eu
cd "$(dirname "$0")/.."

target="${1:-}"
code="${DEMO_CODE:-NOMIDEMO}"
case "$target" in
    local)
        db="--local"
        url="http://127.0.0.1:55321"
        key="sb_publishable_ACJWlzQHlZjBrEguHvfOxg_3BJgxAaH"
        ;;
    live)
        db="--linked"
        url="https://pohguhbhqvurdhnflpek.supabase.co"
        key="sb_publishable_Hv2JSw9p_1q10ldOqVRe_A_ho1pa1pH"
        ;;
    *) echo "Aufruf: scripts/setup-demo.sh local|live" >&2; exit 1 ;;
esac

sql() { supabase db query $db --output-format json "$1" 2>/dev/null | python3 -c 'import json,sys; rows=json.load(sys.stdin)["rows"]; print(rows[0][next(iter(rows[0]))] if rows else "")'; }

# 1. Haushalt und ein Einmal-Code, mit dem die Function das Demo-Konto anlegt
bootstrap=$(python3 -c 'import secrets; print("".join(secrets.choice("ABCDEFGHJKLMNPQRSTUVWXYZ23456789") for _ in range(8)))')
household=$(sql "insert into public.households (name, invite_code) values ('Demo-Haushalt', public.generate_invite_code()) returning id")
sql "insert into public.household_invites (code, household_id, created_by) values ('$bootstrap', '$household', null) returning code" >/dev/null

# 2. Einlösen: legt das Konto (ohne echte Mail) an und macht es zum Mitglied
curl -sf -X POST "$url/functions/v1/invite" -H "apikey: $key" -H "Content-Type: application/json" \
    -d "{\"code\":\"$bootstrap\",\"display_name\":\"Demo\"}" >/dev/null
member=$(sql "select user_id from public.household_members where household_id = '$household'")

# 3. Wiederverwendbarer Anmeldecode für dieses Konto (alter Demo-Code wird ersetzt)
sql "delete from public.household_invites where code = '$code' returning code" >/dev/null
sql "insert into public.household_invites (code, household_id, member_id, reusable, expires_at, created_by)
     values ('$code', '$household', '$member', true, '2099-12-31', null) returning code" >/dev/null

# 4. Beispielrezepte, damit es etwas zu sehen und vorzuschlagen gibt
sql "insert into public.recipes (household_id, title, summary, total_minutes, servings, dish_type, diet, tags, ingredients, steps, created_by) values
 ('$household', 'Linsen-Dal mit Kokosmilch', 'Cremig, wärmend und in einer halben Stunde fertig.', 30, 2, 'hauptgericht', 'vegan', '{schnell,indisch}',
  '[{\"name\":\"rote Linsen\",\"quantity\":200,\"unit\":\"g\",\"note\":null,\"aisle\":\"trockenwaren\"},{\"name\":\"Kokosmilch\",\"quantity\":1,\"unit\":\"Dose\",\"note\":null,\"aisle\":\"konserven\"},{\"name\":\"Zwiebel\",\"quantity\":1,\"unit\":null,\"note\":\"fein gewürfelt\",\"aisle\":\"obst_gemuese\"},{\"name\":\"Currypulver\",\"quantity\":2,\"unit\":\"TL\",\"note\":null,\"aisle\":\"gewuerze_oele\"}]',
  '[{\"text\":\"Zwiebel in etwas Öl glasig dünsten, Currypulver kurz mitrösten.\",\"timer_seconds\":null},{\"text\":\"Linsen, Kokosmilch und 300 ml Wasser dazugeben und 20 Minuten köcheln lassen.\",\"timer_seconds\":1200},{\"text\":\"Mit Salz abschmecken und mit Reis servieren.\",\"timer_seconds\":null}]', '$member'),
 ('$household', 'Spaghetti Carbonara', 'Der Klassiker – ohne Sahne, mit Ei und Pecorino.', 20, 2, 'hauptgericht', 'fleisch', '{schnell,italienisch}',
  '[{\"name\":\"Spaghetti\",\"quantity\":250,\"unit\":\"g\",\"note\":null,\"aisle\":\"trockenwaren\"},{\"name\":\"Guanciale\",\"quantity\":100,\"unit\":\"g\",\"note\":\"gewürfelt\",\"aisle\":\"kuehlregal\"},{\"name\":\"Eier\",\"quantity\":3,\"unit\":null,\"note\":null,\"aisle\":\"kuehlregal\"},{\"name\":\"Pecorino\",\"quantity\":50,\"unit\":\"g\",\"note\":\"gerieben\",\"aisle\":\"kuehlregal\"}]',
  '[{\"text\":\"Spaghetti in Salzwasser 9 Minuten kochen.\",\"timer_seconds\":540},{\"text\":\"Guanciale knusprig braten. Eier mit Pecorino verquirlen.\",\"timer_seconds\":null},{\"text\":\"Nudeln mit etwas Kochwasser zum Speck geben, vom Herd nehmen und die Eimasse unterrühren.\",\"timer_seconds\":null}]', '$member'),
 ('$household', 'Ofengemüse mit Feta', 'Bunt, einfach und fast ohne Arbeit.', 40, 2, 'hauptgericht', 'vegetarisch', '{ofen,einfach}',
  '[{\"name\":\"Paprika\",\"quantity\":2,\"unit\":null,\"note\":null,\"aisle\":\"obst_gemuese\"},{\"name\":\"Zucchini\",\"quantity\":1,\"unit\":null,\"note\":null,\"aisle\":\"obst_gemuese\"},{\"name\":\"Feta\",\"quantity\":200,\"unit\":\"g\",\"note\":null,\"aisle\":\"kuehlregal\"},{\"name\":\"Olivenöl\",\"quantity\":3,\"unit\":\"EL\",\"note\":null,\"aisle\":\"gewuerze_oele\"}]',
  '[{\"text\":\"Gemüse in Stücke schneiden, mit Öl, Salz und Pfeffer mischen.\",\"timer_seconds\":null},{\"text\":\"Feta in die Mitte legen und bei 200 °C 30 Minuten backen.\",\"timer_seconds\":1800}]', '$member'),
 ('$household', 'Kaiserschmarrn', 'Fluffig, karamellisiert, mit Puderzucker.', 30, 2, 'dessert', 'vegetarisch', '{süß,österreichisch}',
  '[{\"name\":\"Mehl\",\"quantity\":125,\"unit\":\"g\",\"note\":null,\"aisle\":\"trockenwaren\"},{\"name\":\"Milch\",\"quantity\":250,\"unit\":\"ml\",\"note\":null,\"aisle\":\"kuehlregal\"},{\"name\":\"Eier\",\"quantity\":3,\"unit\":null,\"note\":\"getrennt\",\"aisle\":\"kuehlregal\"},{\"name\":\"Butter\",\"quantity\":30,\"unit\":\"g\",\"note\":null,\"aisle\":\"kuehlregal\"}]',
  '[{\"text\":\"Mehl, Milch und Eigelb verrühren, Eiweiß steif schlagen und unterheben.\",\"timer_seconds\":null},{\"text\":\"Teig in Butter 5 Minuten stocken lassen, wenden, in Stücke reißen und mit Zucker karamellisieren.\",\"timer_seconds\":300}]', '$member')
 returning id" >/dev/null

pretty=$(echo "$code" | sed 's/^\(....\)/\1-/')
echo "Demo-Zugang bereit: Haushalt $household, Code $pretty (in der App „Ich habe eine Einladung“)."
