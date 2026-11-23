#!/bin/zsh
set -eu
cd "${0:A:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT=docs/validation/lighting-v1
mkdir -p "$OUT"
"$GODOT" --headless --path . --editor --import --quit > "$OUT/import.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|ERROR:' "$OUT/import.log"; then exit 1; fi
"$GODOT" --path . --rendering-method gl_compatibility --script tools/validate_lighting.gd > "$OUT/native.log" 2>&1
if rg 'SCRIPT ERROR|ERROR:|LIGHTING_FAIL' "$OUT/native.log"; then exit 1; fi
uv run --with numpy --with pillow python tools/compare_lighting.py > "$OUT/pixel-comparison.log"
