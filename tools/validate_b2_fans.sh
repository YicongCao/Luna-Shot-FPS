#!/bin/zsh
set -eu
cd "${0:A:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="$PWD/docs/validation/b2-cooling-fans"
mkdir -p "$OUT"
"$GODOT" --headless --path . --log-file "$OUT/import-engine.log" --editor --import --quit > "$OUT/import.log" 2>&1
"$GODOT" --headless --path . --log-file "$OUT/headless-engine.log" --script tools/validate_b2_fans.gd > "$OUT/headless.log" 2>&1
"$GODOT" --path . --log-file "$OUT/native-engine.log" --script tools/validate_b2_fans.gd > "$OUT/native.log" 2>&1
if rg 'SCRIPT ERROR|ERROR:|FAN FAIL' "$OUT"/*.log; then exit 1; fi
