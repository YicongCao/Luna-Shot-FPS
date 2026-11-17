#!/bin/zsh
# Rebuild the Hunyuan rifle revision in paths.py (currently ML21) from the archived Hunyuan high/low/UV files. No paid service calls.
set -eu
cd "${0:A:h:h:h}"
BLENDER="${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}"
PY=(uv run --with numpy --with scipy --with pillow --with openexr python)
mkdir -p art_source/weapons/lc01/ml21-hunyuan-refine
touch art_source/weapons/lc01/ml21-hunyuan-refine/.gdignore
"$BLENDER" --background --python-exit-code 1 --python tools/hunyuan_weapon/blender_stage.py -- points
(cd tools/hunyuan_weapon && "${PY[@]}" align.py)
"$BLENDER" --background --python-exit-code 1 --python tools/hunyuan_weapon/blender_stage.py -- bake
(cd tools/hunyuan_weapon && "${PY[@]}" textures.py && "${PY[@]}" write_imports.py)
