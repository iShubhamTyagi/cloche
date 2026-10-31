#!/usr/bin/env bash
# Builds the app for a simulator. Warnings are errors (set in the project and package).
# Usage: scripts/build.sh ["Simulator name"]
source "$(dirname "$0")/common.sh"

SIM="${1:-$DEFAULT_SIM}"
xcodebuild build \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "$(destination "$SIM")" \
  -derivedDataPath "$DERIVED" \
  -quiet
echo "✅ Build succeeded for $SIM"
