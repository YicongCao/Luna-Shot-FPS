from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "art_source/weapons/lc01/hunyuan-v1"
WORK = ROOT / "art_source/weapons/lc01/ml20-hunyuan-bake"
RUNTIME = ROOT / "assets/weapons/lc01/ml20"
REPORT = ROOT / "docs/validation/ml20-hunyuan-bake"
ML06_GLB = ROOT / "assets/weapons/lc01/lc01.glb"
ML06_TEXTURES = ROOT / "assets/weapons/lc01"
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"

MAGAZINE_BOX = {"y": [0.155, 0.405], "z_max": -0.006}
NORMAL_SIZE = 4096
ATLAS_SIZE = 2048
