#!/bin/zsh
set -eu
cd "${0:A:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT=docs/validation/pulsed-arc-v1
mkdir -p "$OUT"
"$GODOT" --headless --log-file "$PWD/$OUT/import-engine.log" --path . --editor --import --quit > "$OUT/import.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|ERROR:' "$OUT/import.log"; then exit 1; fi
for mode in headless native; do
  flags=()
  if [[ "$mode" == headless ]]; then flags+=(--headless); fi
  "$GODOT" "${flags[@]}" --log-file "$PWD/$OUT/$mode-engine.log" --path . --script tools/validate_pulsed_arc.gd > "$OUT/$mode.log" 2>&1
  if rg 'SCRIPT ERROR|ERROR:|PULSE_QA FAIL' "$OUT/$mode.log"; then exit 1; fi
  rg 'PULSE_QA_COMPLETE failures=0' "$OUT/$mode.log"
done
