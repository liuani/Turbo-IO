#!/usr/bin/env bash
# CI-only helper: build the source-only RayNeoCompanion target (no vendor frameworks,
# no glasses transport) for the iOS Simulator and capture the four main tabs in
# light and dark appearance using the app's existing --ui-demo / --ui-tab launch flags.
# Usage: scripts/ci-screenshots.sh <output-dir>
set -euo pipefail
OUT="${1:?output dir}"
mkdir -p "$OUT"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

xcodegen generate --spec apps/RayNeoCompanion/project-source.yml
DERIVED="$OUT/../SimDerived"
xcodebuild build \
  -project apps/RayNeoCompanion/RayNeoCompanion.xcodeproj \
  -scheme RayNeoCompanion -configuration Debug \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY=- CODE_SIGNING_ALLOWED=YES \
  > "$OUT/../sim-build.log" 2>&1 || { grep -E "error:" "$OUT/../sim-build.log" | tail -40; exit 1; }
APP="$(find "$DERIVED/Build/Products" -maxdepth 2 -name 'RayNeoCompanion.app' -path '*iphonesimulator*' | head -1)"
[ -d "$APP" ] || { echo "simulator app not found"; exit 1; }

# Newest iPhone Pro simulator on the newest iOS runtime.
UDID="$(xcrun simctl list devices available -j | python3 -c '
import json,sys,re
d=json.load(sys.stdin)["devices"]
best=None
for rt,devs in d.items():
    m=re.search(r"iOS-(\d+)-(\d+)",rt)
    if not m: continue
    ver=(int(m.group(1)),int(m.group(2)))
    for x in devs:
        n=x["name"]
        if not n.startswith("iPhone"): continue
        score=(ver, "Pro" in n and "Max" not in n, n)
        if best is None or score>best[0]: best=(score,x["udid"],n,rt)
print(best[1]); print(best[2],best[3],file=sys.stderr)
')"
echo "Simulator: $UDID"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
# Clean status bar for consistent screenshots
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --wifiBars 3 --cellularBars 4 || true
xcrun simctl install "$UDID" "$APP"
BUNDLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")"

names=(device conversation archive tools)
for mode in light dark; do
  xcrun simctl ui "$UDID" appearance "$mode"
  for tab in 0 1 2 3; do
    xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
    xcrun simctl launch "$UDID" "$BUNDLE" --ui-demo --ui-tab "$tab" >/dev/null
    sleep 7
    shot="$OUT/$(printf '%d' "$tab")-${names[$tab]}-$mode.png"
    # A nearly blank frame (launch screen still showing) compresses to a tiny PNG: wait and retake.
    for attempt in 1 2 3 4; do
      xcrun simctl io "$UDID" screenshot "$shot"
      [ "$(stat -f %z "$shot")" -gt 150000 ] && break
      echo "retake $shot (attempt $attempt)"; sleep 5
    done
  done
done
xcrun simctl terminate "$UDID" "$BUNDLE" 2>/dev/null || true
ls -l "$OUT"
