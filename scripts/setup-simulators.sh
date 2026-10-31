#!/usr/bin/env bash
# Creates the simulators used by the test matrix if they don't exist yet.
source "$(dirname "$0")/common.sh"

latest_runtime() {
  xcrun simctl list runtimes available | grep "$1" | tail -1 | sed -E 's/.* - (com\.apple\.CoreSimulator\.SimRuntime\.[^ ]+).*/\1/'
}

ensure() {
  local name="$1" type_name="$2" runtime="$3"
  if xcrun simctl list devices available | grep -q "    $name ("; then
    echo "✓ $name exists"
    return
  fi
  local type_id
  type_id="$(xcrun simctl list devicetypes | grep -F "$type_name (" | head -1 | sed -E 's/.*\((com\.apple\.[^)]+)\).*/\1/')"
  if [[ -z "$type_id" ]]; then
    echo "⚠️  Device type '$type_name' not available in this Xcode"
    return
  fi
  xcrun simctl create "$name" "$type_id" "$runtime" >/dev/null
  echo "＋ Created $name"
}

IOS="$(latest_runtime 'iOS ')"
WATCH="$(latest_runtime 'watchOS ')"

ensure "iPhone 17" "iPhone 17" "$IOS"
ensure "iPhone 17e" "iPhone 17e" "$IOS"
ensure "iPhone Duo" "iPhone Duo" "$IOS"
if [[ -n "$WATCH" ]]; then
  ensure "Apple Watch Series 11 (46mm)" "Apple Watch Series 11 (46mm)" "$WATCH"
fi
