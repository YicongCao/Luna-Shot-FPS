#!/bin/zsh
set -eu
cd "${0:A:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT=docs/validation/magnetic-pulse-v1
mkdir -p "$OUT"
"$GODOT" --headless --path . --editor --import --quit > "$OUT/import.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|ERROR:' "$OUT/import.log"; then exit 1; fi
for mode in headless native; do
  flags=()
  if [[ "$mode" == headless ]]; then flags+=(--headless); fi
  "$GODOT" "${flags[@]}" --path . --script tools/validate_magnetic_pulse.gd -- --fire-effect=a > "$OUT/$mode.log" 2>&1
  if rg 'SCRIPT ERROR|ERROR:|PULSE_QA FAIL' "$OUT/$mode.log"; then exit 1; fi
  rg 'PULSE_QA_COMPLETE failures=0' "$OUT/$mode.log"
done
