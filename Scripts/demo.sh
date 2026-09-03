#!/usr/bin/env bash
# Launch the app in DEMO mode — every store routed to an ephemeral suite
# seeded with the fixed screenshot cast (names, a mid-run bracket, full
# hiscore boards; see PuckaroundKit's DemoMode). The real simulator data is
# never touched. For App Store screenshots prefer `make shots` (guided,
# captures for you); this is the bare launcher for freehand poking.
#   PLATFORM=iphone|ipad   (default iphone)
#   DEVICE=<name pattern>  override the simulator pick
set -euo pipefail
cd "$(dirname "$0")/.."

PLATFORM="${PLATFORM:-iphone}"
BUNDLE="fi.misaki.puckaround"

case "$PLATFORM" in
    iphone) pat="${DEVICE:-iPhone 1[6-9] Pro Max}" ;;
    ipad) pat="${DEVICE:-iPad Pro 13-inch}" ;;
    *) echo "PLATFORM must be iphone | ipad" >&2; exit 2 ;;
esac

udid=$(xcrun simctl list devices available | grep -E "$pat" \
    | grep -oE "[0-9A-F]{8}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{4}-[0-9A-F]{12}" | tail -1)
[ -n "$udid" ] || { echo "No simulator matching /$pat/ installed." >&2; exit 1; }
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || true
open -a Simulator

# The pristine marketing status bar, same as `make shots` (9:41; the ISO
# timestamp pins the iPad's date too). Left in place — this launcher is for
# freehand captures; `xcrun simctl status_bar <udid> clear` undoes it.
xcrun simctl status_bar "$udid" override --time "2007-01-09T09:41:00+0000" \
    --batteryState charged --batteryLevel 100 --wifiBars 3 --dataNetwork wifi

app="$(find .build-xcode/Build/Products/Debug-iphonesimulator \
    -maxdepth 1 -name '*.app' -print -quit 2>/dev/null)"
[ -n "$app" ] && [ -d "$app" ] || { echo "Build the app first (make build-ios)." >&2; exit 1; }

xcrun simctl terminate "$udid" "$BUNDLE" >/dev/null 2>&1 || true
xcrun simctl install "$udid" "$app"
xcrun simctl launch "$udid" "$BUNDLE" -puckaround-demo >/dev/null
echo "Demo launched — seeded names, tournament, and boards; nothing persists."
