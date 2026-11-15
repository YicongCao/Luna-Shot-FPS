#!/bin/zsh
set -eu
cd "${0:A:h:h}"
GODOT="${GODOT_BIN:-/Applications/Godot.app/Contents/MacOS/Godot}"
mkdir -p artifacts/validation
"$GODOT" --headless --path . --editor --import --quit > artifacts/validation/import.log 2>&1
if rg 'SCRIPT ERROR|Parse Error|ERROR:' artifacts/validation/import.log; then exit 1; fi
"$GODOT" --headless --path . --script tools/validate_weapon.gd > artifacts/validation/weapon.log 2>&1
if rg 'SCRIPT ERROR|ERROR:' artifacts/validation/weapon.log; then exit 1; fi
"$GODOT" --headless --path . --fixed-fps 60 -- --qa --pbr-regression > artifacts/validation/headless.log 2>&1
if rg 'SCRIPT ERROR|ERROR:|QA FAIL' artifacts/validation/headless.log; then exit 1; fi
"$GODOT" --path . -- --qa --pbr-regression > artifacts/validation/native.log 2>&1
if rg 'SCRIPT ERROR|ERROR:|QA FAIL' artifacts/validation/native.log; then exit 1; fi
