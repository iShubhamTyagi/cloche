#!/usr/bin/env bash
# Builds every decorating asset in order, skipping outputs that already exist (each script is
# resumable; pass --force through FORCE=1), then exports them into the app with a size check.
# Usage: scripts/build_assets.sh
set -euo pipefail
cd "$(dirname "$0")/.."
B=/Applications/Blender.app/Contents/MacOS/Blender
F=()
[[ "${FORCE:-0}" == "1" ]] && F=(--force)

run() { echo "▶︎ $1"; "$B" -b -P "scripts/blender/$1" -- "${@:2}" "${F[@]}" > "build/renders/$1.log" 2>&1 \
  || { echo "✘ $1 failed (build/renders/$1.log)"; exit 1; }; }

mkdir -p build/renders
"$B" -b -P scripts/verify_assets.py > build/renders/verify_assets.log 2>&1   # step 0: audit
run icing.py          # 1
run toppings.py       # 2
run tools.py          # 3
run cake_maps.py      # 4
run toppings3d.py     # 5
run station.py        # 6
# 7: transition.py is skipped: the app's tongs move (StationMoveView) already does it.
run focus.py          # 8
python3 scripts/blender/export_assets.py --budget-mb 150   # 9
echo "✅ Decorating assets built and exported"
