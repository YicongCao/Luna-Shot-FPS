#!/bin/zsh
set -eu
cd "${0:A:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
export LUNA_QA_OUTPUT="${LUNA_QA_OUTPUT:-docs/validation/environment-pipeline-v1/map}"
mkdir -p artifacts/validation "$LUNA_QA_OUTPUT"
python3 tools/test_energy_layout.py
"$GODOT" --headless --path . --editor --import --quit > artifacts/validation/import.log 2>&1
if rg 'SCRIPT ERROR|Parse Error|ERROR:' artifacts/validation/import.log; then exit 1; fi
"$GODOT" --headless --path . --script tools/validate_energy_modules.gd > artifacts/validation/modules.log 2>&1
if rg 'SCRIPT ERROR|ERROR:' artifacts/validation/modules.log; then exit 1; fi
"$GODOT" --headless --path . --script tools/validate_b2_fans.gd > artifacts/validation/b2-fans.log 2>&1
if rg 'SCRIPT ERROR|ERROR:|FAN FAIL' artifacts/validation/b2-fans.log; then exit 1; fi
"$GODOT" --headless --path . --script tools/validate_weapon.gd > artifacts/validation/weapon.log 2>&1
if rg 'SCRIPT ERROR|ERROR:' artifacts/validation/weapon.log; then exit 1; fi
"$GODOT" --headless --path . --fixed-fps 60 -- --qa > artifacts/validation/headless.log 2>&1
if rg 'SCRIPT ERROR|ERROR:|QA FAIL' artifacts/validation/headless.log; then exit 1; fi
"$GODOT" --path . -- --qa > artifacts/validation/native.log 2>&1
if rg 'SCRIPT ERROR|ERROR:|QA FAIL' artifacts/validation/native.log; then exit 1; fi

mkdir -p docs/validation/knockdown-targets
"$GODOT" --headless --path . --fixed-fps 60 --script tools/validate_knockdown.gd > artifacts/validation/targets-headless.log 2>&1
"$GODOT" --path . --script tools/validate_knockdown.gd > artifacts/validation/targets-native.log 2>&1
if rg 'SCRIPT ERROR|ERROR:' artifacts/validation/targets-*.log; then exit 1; fi
