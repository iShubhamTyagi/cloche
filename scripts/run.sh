#!/usr/bin/env bash
# Builds, installs and launches the app in a booted simulator so progress is visible.
# Usage: scripts/run.sh ["Simulator name" | all] [launch args...]
# Installs and launches on every booted iPhone simulator, so they all run the same build.
source "$(dirname "$0")/common.sh"

SIM="${1:-$DEFAULT_SIM}"
shift || true

# Every booted iPhone simulator gets the same build, so the iPhone and the Duo never run
# different versions side by side. The named simulator is booted first if it isn't already.
udid_for() {
  xcrun simctl list devices available | grep "    $1 (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

if [[ "$SIM" == "all" ]]; then
  BUILD_SIM="$(xcrun simctl list devices booted | grep -E '^ +iPhone' | head -1 | sed -E 's/^ +(.*) \([0-9A-F-]{36}\).*/\1/')"
  BUILD_SIM="${BUILD_SIM:-$DEFAULT_SIM}"
else
  BUILD_SIM="$SIM"
fi

"$ROOT/scripts/build.sh" "$BUILD_SIM"

# Xcode 27 replaced Simulator.app with DeviceHub.app.
open -a "$(xcode-select -p)/../Applications/DeviceHub.app"

if [[ "$SIM" != "all" ]]; then
  UDID="$(udid_for "$SIM")"
  if [[ -z "$UDID" ]]; then
    echo "No simulator named '$SIM'. Run scripts/setup-simulators.sh" >&2
    exit 1
  fi
  xcrun simctl boot "$UDID" 2>/dev/null || true
  xcrun simctl bootstatus "$UDID" -b >/dev/null
fi

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Cloche.app"
xcrun simctl list devices booted | grep -E '^ +iPhone' | while read -r line; do
  NAME="$(echo "$line" | sed -E 's/^(.*) \([0-9A-F-]{36}\).*/\1/')"
  ID="$(echo "$line" | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
  xcrun simctl install "$ID" "$APP"
  xcrun simctl launch --terminate-running-process "$ID" "$BUNDLE_ID" "$@" >/dev/null
  echo "🚀 Launched on $NAME"
done
