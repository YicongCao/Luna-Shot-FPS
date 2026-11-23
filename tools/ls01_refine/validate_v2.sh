#!/bin/zsh
set -eu
cd "${0:A:h:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
OUT=docs/validation/ls01-refine-v2
export LS01_REPORT_DIR="res://$OUT"
mkdir -p "$OUT/rifle"
"$GODOT" --headless --path . --editor --import --quit > "$OUT/import.log" 2>&1
python3 tools/ls01_refine/import_textures.py --revision ml09
"$GODOT" --headless --path . --editor --import --quit > "$OUT/import-mips.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|ERROR:' "$OUT/import.log" "$OUT/import-mips.log"; then exit 1; fi
uv run --with numpy --with scipy python tools/ls01_refine/audit_padding.py --revision ml09 > "$OUT/padding-audit.log" 2>&1
uv run --with numpy --with pillow python tools/ls01_refine/audit_bake.py --revision ml09 > "$OUT/bake-audit.log" 2>&1
uv run --with numpy python tools/ls01_refine/audit_runtime.py --revision ml09 > "$OUT/runtime-audit.log" 2>&1
"$GODOT" --headless --path . --script tools/ls01_refine/ammo_qa.gd -- --weapon-revision=ml09 > "$OUT/ammo-qa.log" 2>&1
LUNA_QA_OUTPUT="$OUT/rifle" "$GODOT" --headless --path . --rendering-method gl_compatibility res://scenes/training.tscn -- --rifle-qa --weapon-revision=ml09 > "$OUT/rifle/headless.log" 2>&1
LUNA_QA_OUTPUT="$OUT/rifle" "$GODOT" --path . --rendering-method gl_compatibility res://scenes/training.tscn -- --rifle-qa --weapon-revision=ml09 > "$OUT/rifle/native.log" 2>&1
LUNA_QA_OUTPUT="$OUT/rifle" "$GODOT" --headless --path . --script tools/validate_scene_switch.gd -- --weapon-revision=ml09 > "$OUT/scene-switch.log" 2>&1
"$GODOT" --path . --script tools/ls01_refine/capture_game.gd -- --weapon-revision=ml09 > "$OUT/game.log" 2>&1
"$GODOT" --path . --script tools/ls01_refine/spill_capture.gd -- --weapon-revision=ml09 > "$OUT/spill.log" 2>&1
uv run --with numpy --with pillow python tools/ls01_refine/audit_spill.py > "$OUT/spill-pixels.log" 2>&1
"$GODOT" --path . --script tools/ls01_refine/lighting_qa.gd -- --weapon-revision=ml09 > "$OUT/lighting.log" 2>&1
"$GODOT" --path . --script tools/ls01_refine/metrics.gd -- --weapon-revision=ml09 > "$OUT/metrics.log" 2>&1
if rg 'SCRIPT ERROR|Parse Error|ERROR:|QA FAIL' "$OUT/ammo-qa.log" "$OUT/rifle/headless.log" "$OUT/rifle/native.log" "$OUT/scene-switch.log" "$OUT/game.log" "$OUT/spill.log" "$OUT/lighting.log"; then exit 1; fi
