# Shared settings for the build scripts. Sourced, not executed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT="$ROOT/Cloche.xcodeproj"
SCHEME="Cloche"
BUNDLE_ID="com.shubhamtyagi.cloche"
# Outside the repo on purpose: Xcode 27 fails to load hostless test bundles from paths
# containing spaces ("My Dev"). See docs/DECISIONS.md.
DERIVED="$HOME/Library/Developer/Xcode/DerivedData/Cloche-cli"
DEFAULT_SIM="iPhone 17"
DUO_SIM="iPhone Duo"

destination() {
  echo "platform=iOS Simulator,name=$1"
}
