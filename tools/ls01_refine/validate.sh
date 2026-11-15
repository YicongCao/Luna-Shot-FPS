#!/bin/zsh
set -eu
cd "${0:A:h:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT=docs/validation/ls01-refine-v1
export LS01_CANDIDATE=1
mkdir -p "$OUT/rifle"
"$GODOT" --headless --path . --editor --import --quit > "$OUT/import.log" 2>&1
python3 tools/ls01_refine/import_textures.py
"$GODOT" --headless --path . --editor --import --quit > "$OUT/import-mips.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|ERROR:' "$OUT/import.log" "$OUT/import-mips.log"; then exit 1; fi
uv run --with numpy --with scipy python tools/ls01_refine/audit_padding.py > "$OUT/padding-audit.log" 2>&1
uv run --with numpy --with pillow python tools/ls01_refine/audit_bake.py > "$OUT/bake-audit.log" 2>&1
uv run --with numpy python tools/ls01_refine/audit_runtime.py > "$OUT/runtime-audit.log" 2>&1
"$GODOT" --headless --path . --script tools/ls01_refine/ammo_qa.gd > "$OUT/ammo-qa.log" 2>&1
LUNA_QA_OUTPUT="$OUT/rifle" "$GODOT" --headless --path . -- --rifle-qa > "$OUT/rifle/headless.log" 2>&1
LUNA_QA_OUTPUT="$OUT/rifle" "$GODOT" --path . -- --rifle-qa > "$OUT/rifle/native.log" 2>&1
LUNA_QA_OUTPUT="$OUT/rifle" "$GODOT" --headless --path . --script tools/validate_scene_switch.gd > "$OUT/scene-switch.log" 2>&1
"$GODOT" --path . --script tools/ls01_refine/capture.gd > "$OUT/capture.log" 2>&1
"$GODOT" --path . --script tools/ls01_refine/capture_game.gd > "$OUT/game.log" 2>&1
"$GODOT" --path . --script tools/ls01_refine/lighting_qa.gd > "$OUT/lighting.log" 2>&1
LS01_PHASE=after "$GODOT" --path . --script tools/ls01_refine/performance.gd > "$OUT/performance-after.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|ERROR:|QA FAIL' "$OUT/ammo-qa.log" "$OUT/rifle/headless.log" "$OUT/rifle/native.log" "$OUT/scene-switch.log" "$OUT/capture.log" "$OUT/game.log" "$OUT/lighting.log"; then exit 1; fi
python3 tools/ls01_refine/review_html.py
