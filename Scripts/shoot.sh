#!/usr/bin/env bash
# Guided App Store screenshot capture. Walks every language × every shot:
# launches the app, tells you what to stage, and CAPTURES for you — no ⌘S, no
# renaming, no file shuffling. Output lands canonically named at
#   <OUT>/<platform>/<lang>/<shot>-<platform>.png
# ready for the ASC upload (make asc-screenshots-apply).
#   PLATFORM=iphone|ipad   (default iphone)
#   LANGS=en               (default en — the listing is en-US only for now)
#   OUT=shots              (default ./shots)
# The default devices are chosen for their PIXEL SIZE — the one ASC accepts
# per platform (screenshots.py enforces it): iPhone Pro Max 1320×2868, iPad
# Pro 13-inch 2064×2752. Override with DEVICE= only if you know the size fits.
# The app launches in DEMO mode: every store routed to an ephemeral suite
# seeded with the fixed screenshot cast (names, a mid-run bracket, full
# boards) — the simulator's real data is never shown or touched.
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${PLATFORM:-iphone}"
LANGS="${LANGS:-en}"
OUT="${OUT:-shots}"
BUNDLE="fi.misaki.puckaround"

case "$PLATFORM" in
    iphone) pat="${DEVICE:-iPhone 1[6-9] Pro Max}" ;;
    ipad) pat="${DEVICE:-iPad Pro 13-inch}" ;;
    *) echo "PLATFORM must be iphone | ipad" >&2; exit 2 ;;
esac

make build-ios >/dev/null

pick_udid() {  # $1 = name pattern
    xcrun simctl list devices available | grep -E "$1" \
        | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" | tail -1
}
UDID=$(pick_udid "$pat")
[ -n "$UDID" ] || { echo "No simulator matching /$pat/ installed." >&2; exit 1; }
name=$(xcrun simctl list devices available | grep "$UDID" | sed -E 's/ *\(.*//' | xargs)
echo "Booting ${name}…"
xcrun simctl bootstatus "$UDID" -b >/dev/null 2>&1 || true
open -a Simulator

# Find the built .app by glob — the product name is "Puck Around", and this
# survives renames (same trick as run-ios.sh).
app="$(find .build-xcode/Build/Products/Debug-iphonesimulator \
    -maxdepth 1 -name '*.app' -print -quit 2>/dev/null)"
[ -n "$app" ] && [ -d "$app" ] || { echo "Build the app first (make build-ios)." >&2; exit 1; }

capture() {  # $1 = output file
    mkdir -p "$(dirname "$1")"
    # --display=internal silences the "No display specified" note.
    xcrun simctl io "$UDID" screenshot --display=internal "$1" >/dev/null
}

IFS=',' read -ra langs <<< "$LANGS"
total=$(python3 Scripts/asc/organize-shots.py "$PLATFORM" --plain | wc -l | tr -d ' ')

for lang in "${langs[@]}"; do
    echo ""
    echo "━━━ $PLATFORM / $lang — launching ━━━"
    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
    xcrun simctl install "$UDID" "$app"
    xcrun simctl launch "$UDID" "$BUNDLE" -puckaround-demo -AppleLanguages "($lang)" >/dev/null
    sleep 3  # let the launch settle before the first stage prompt

    i=0
    while IFS=$'\t' read -r shot desc; do
        i=$((i + 1))
        file="$OUT/$PLATFORM/$lang/${shot}-${PLATFORM}.png"
        echo ""
        echo "[$lang $i/$total] $shot"
        echo "  $desc"
        printf "  ⏎ capture · s skip · q quit: "
        read -r reply </dev/tty
        [ "$reply" = q ] && exit 0
        [ "$reply" = s ] && continue
        while :; do
            capture "$file"
            printf "  saved %s — ⏎ next · r retake: " "$file"
            read -r again </dev/tty
            [ "$again" = r ] || break
        done
    done < <(python3 Scripts/asc/organize-shots.py "$PLATFORM" --plain)

    xcrun simctl terminate "$UDID" "$BUNDLE" >/dev/null 2>&1 || true
done

echo ""
echo "Done. Sets under $OUT/$PLATFORM/ — commit them, then make asc-screenshots-apply."
