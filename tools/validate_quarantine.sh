#!/bin/zsh
set -eu
cd "${0:A:h:h}"
ENGINE="${GODOT_BIN:-}"
if [[ -z "$ENGINE" ]]; then
  for p in /Applications/Godot.app/Contents/MacOS/Godot "$HOME/Applications/Godot.app/Contents/MacOS/Godot"; do
    if [[ -x "$p" ]]; then ENGINE="$p"; break; fi
  done
fi
if [[ -z "$ENGINE" ]]; then ENGINE="$(command -v godot4 || command -v godot || true)"; fi
[[ -n "$ENGINE" ]] || { print -u2 'Godot 4.7.2 is required'; exit 1; }
OUT='docs/validation/quarantine-v1'
mkdir -p "$OUT" artifacts/quarantine
"$ENGINE" --headless --path . --editor --import --quit > artifacts/quarantine/import-final.log 2>&1
if rg 'SCRIPT ERROR|Parse Error|^ERROR:' artifacts/quarantine/import-final.log; then exit 1; fi
LUNA_QA_OUTPUT="$OUT/training-regression" python3 tools/test_energy_layout.py > "$OUT/layout-regression.log" 2>&1
"$ENGINE" --headless --path . --script res://tools/quarantine/test_mission.gd -- --quarantine-qa > "$OUT/gameplay-qa.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|^ERROR:|QA FAIL' "$OUT/gameplay-qa.log"; then exit 1; fi
# Preserve historical evidence: legacy QA output is redirected to the new milestone.
LUNA_QA_OUTPUT="$OUT/training-regression" "$ENGINE" --headless --path . --fixed-fps 60 -- --qa > "$OUT/training-regression.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|^ERROR:|QA FAIL' "$OUT/training-regression.log"; then exit 1; fi
if [[ "${1:-}" == '--native' || "${1:-}" == '--performance' ]]; then
  "$ENGINE" --path . --rendering-method forward_plus --resolution 1920x810 --script res://tools/quarantine/capture.gd -- --quarantine-qa > "$OUT/native.log" 2>&1
  if rg 'SCRIPT ERROR|Parse Error|^ERROR:' "$OUT/native.log"; then exit 1; fi
fi
if [[ "${1:-}" == '--performance' ]]; then
  "$ENGINE" --path . --rendering-method forward_plus --resolution 1920x810 --script res://tools/quarantine/performance.gd -- --quarantine-qa > "$OUT/performance.log" 2>&1
  if rg 'SCRIPT ERROR|Parse Error|^ERROR:' "$OUT/performance.log"; then exit 1; fi
fi
print 'Quarantine validation finished. See docs/validation/quarantine-v1; visual acceptance remains separate.'
