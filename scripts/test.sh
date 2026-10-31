#!/usr/bin/env bash
# Runs the package unit tests, then the app's UI smoke tests, on every simulator in the matrix.
# Usage: scripts/test.sh ["Simulator name" ...]   (defaults to iPhone 17 and iPhone Duo)
source "$(dirname "$0")/common.sh"

if [[ $# -gt 0 ]]; then SIMS=("$@"); else SIMS=("$DEFAULT_SIM" "$DUO_SIM"); fi

for SIM in "${SIMS[@]}"; do
  if ! xcrun simctl list devices available | grep -q "    $SIM ("; then
    echo "⚠️  Skipping '$SIM': no such simulator (run scripts/setup-simulators.sh)"
    continue
  fi

  echo "▶︎ Unit tests (PocketOvenKit) on $SIM"
  # Package tests run from the package directory; the app scheme can't host them.
  (cd "$ROOT/Packages/PocketOvenKit" && xcodebuild test \
    -scheme PocketOvenKit \
    -destination "$(destination "$SIM")" \
    -derivedDataPath "$DERIVED-kit" \
    -quiet)

  echo "▶︎ UI smoke tests on $SIM"
  xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$(destination "$SIM")" \
    -derivedDataPath "$DERIVED" \
    -quiet
  # Skipped UI tests (e.g. a folded Duo) are reported, never hidden.
  RESULT="$(ls -td "$DERIVED"/Logs/Test/*.xcresult | head -1)"
  SKIPPED="$(xcrun xcresulttool get test-results summary --path "$RESULT" 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin).get("skippedTests", 0))' 2>/dev/null || echo 0)"
  if [[ "$SKIPPED" != "0" ]]; then
    echo "⚠️  $SKIPPED UI test(s) skipped on $SIM (see the skip reason in the result bundle; a folded Duo is the usual cause)"
  fi
  # XCUITest installs a helper "PocketOvenUITests-Runner" app; remove it so only Pocket Oven is left.
  xcrun simctl uninstall "$SIM" "$BUNDLE_ID.uitests.xctrunner" 2>/dev/null || true
  echo "✅ All tests passed on $SIM"
done
