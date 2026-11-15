#!/bin/zsh
set -eu
cd "${0:A:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT="docs/validation/rifle-pipeline-v2"
mkdir -p "$OUT"
"$GODOT" --headless --path . --editor --import --quit > "$OUT/import.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|ERROR:' "$OUT/import.log"; then exit 1; fi
"$GODOT" --headless --path . --fixed-fps 60 -- --rifle-qa > "$OUT/headless.log" 2>&1
if rg 'SCRIPT ERROR|ERROR:|RIFLE_QA FAIL' "$OUT/headless.log"; then exit 1; fi
"$GODOT" --path . -- --rifle-qa > "$OUT/native.log" 2>&1
if rg 'SCRIPT ERROR|ERROR:|RIFLE_QA FAIL' "$OUT/native.log"; then exit 1; fi
"$GODOT" --path . res://scenes/weapon_lab.tscn -- --lab-qa > "$OUT/lab.log" 2>&1
if rg 'SCRIPT ERROR|ERROR:' "$OUT/lab.log"; then exit 1; fi
"$GODOT" --headless --path . --script tools/validate_scene_switch.gd > "$OUT/scene-switch.log" 2>&1
if rg 'SCRIPT ERROR|ERROR:' "$OUT/scene-switch.log"; then exit 1; fi
uv run --with numpy --with pillow python tools/weapon_pipeline/compare_renders.py
