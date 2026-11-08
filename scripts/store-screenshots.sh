#!/bin/zsh
# App-Store-Screenshots erzeugen: startet den Screenshot-Test auf iPhone 17 Pro Max (6,9″) und iPad Pro 13″
# gegen das lokale Supabase, mit aufgeräumter Statusleiste, und legt die Bilder in store/screenshots/roh/ ab.
# Danach: swift store/render-store-frames.swift … (Rahmen mit Überschrift)
# Aufruf: scripts/store-screenshots.sh [iphone|ipad]   (ohne Angabe beide)
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer

# Lokaler Service-Schlüssel (nur lokal gültig) – damit legt der Test Beispieldaten an RLS vorbei an
key=$(supabase status -o json 2>/dev/null | python3 -I -c "import json,sys; print(json.load(sys.stdin)['SERVICE_ROLE_KEY'])")

targets=(${1:-iphone ipad})
for target in $targets; do
  case $target in
    iphone) device="iPhone 17 Pro Max" ;;
    ipad) device="iPad Pro 13-inch (M5)" ;;
    *) echo "Unbekannt: $target"; exit 1 ;;
  esac
  udid=$(xcrun simctl list devices available | grep "$device (" | head -1 | grep -oE "[0-9A-F-]{36}")
  xcrun simctl shutdown all >/dev/null 2>&1 || true
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" >/dev/null
  # 9:41, volle Balken, voller Akku
  xcrun simctl status_bar "$udid" override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
    --cellularMode active --cellularBars 4 --batteryState discharging --batteryLevel 100
  xcrun simctl ui "$udid" appearance light

  result="build/store-$target.xcresult"
  rm -rf "$result"
  TEST_RUNNER_NOMI_SERVICE_KEY="$key" xcodebuild test -project Nomi.xcodeproj -scheme Nomi \
    -destination "id=$udid" -derivedDataPath build -resultBundlePath "$result" \
    -only-testing:NomiUITests/StoreScreenshotTests > "build/store-$target.log" 2>&1 \
    || { echo "Test auf $device fehlgeschlagen, siehe build/store-$target.log"; exit 1; }

  out="store/screenshots/roh/$target"
  rm -rf "$out" "build/store-$target-export"
  mkdir -p "$out" "build/store-$target-export"
  xcrun xcresulttool export attachments --path "$result" --output-path "build/store-$target-export" >/dev/null
  python3 -I - "build/store-$target-export" "$out" <<'PY'
import json, shutil, sys
src, dst = sys.argv[1], sys.argv[2]
for test in json.load(open(f"{src}/manifest.json")):
    for a in test["attachments"]:
        name = (a.get("suggestedHumanReadableName") or "").split("_0_")[0]
        if name.startswith("store-"):
            shutil.copy(f"{src}/{a['exportedFileName']}", f"{dst}/{name.split('-', 2)[2]}.png")
PY
  # Querformat-Bilder kommen hochkant mit Drehangabe; App Store Connect braucht echte Pixelmaße
  for f in "$out"/*.png; do ffmpeg -loglevel error -y -i "$f" -frames:v 1 "$f.tmp.png" && mv "$f.tmp.png" "$f"; done
  xcrun simctl status_bar "$udid" clear
  echo "$device: $(ls $out | wc -l | tr -d ' ') Screenshots in $out"
done
