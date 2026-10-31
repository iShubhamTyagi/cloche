#!/usr/bin/env bash
# Builds, installs and launches the app in a booted simulator so progress is visible.
# Usage: scripts/run.sh ["Simulator name"] [launch args...]
source "$(dirname "$0")/common.sh"

SIM="${1:-$DEFAULT_SIM}"
shift || true

"$ROOT/scripts/build.sh" "$SIM"

UDID="$(xcrun simctl list devices available | grep "    $SIM (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
if [[ -z "$UDID" ]]; then
  echo "No simulator named '$SIM'. Run scripts/setup-simulators.sh" >&2
  exit 1
fi

xcrun simctl boot "$UDID" 2>/dev/null || true
# Xcode 27 replaced Simulator.app with DeviceHub.app.
open -a "$(xcode-select -p)/../Applications/DeviceHub.app"
xcrun simctl bootstatus "$UDID" -b >/dev/null

APP="$DERIVED/Build/Products/Debug-iphonesimulator/Cloche.app"
xcrun simctl install "$UDID" "$APP"
xcrun simctl launch --terminate-running-process "$UDID" "$BUNDLE_ID" "$@"
echo "🚀 Launched on $SIM"
