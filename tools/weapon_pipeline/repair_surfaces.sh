#!/bin/zsh
set -eu
cd "${0:A:h:h:h}"
export LC01_PIPELINE=pipeline-v2
BLENDER="${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}"
OUT="art_source/weapons/lc01/pipeline-v2"
mkdir -p "$OUT/logs"
for step in repair_orientation bake finalize_materials audit_sources ship; do
  "$BLENDER" --background --python-exit-code 1 --python "tools/weapon_pipeline/$step.py" > "$OUT/logs/$step.log" 2>&1
done
./tools/validate_rifle.sh
