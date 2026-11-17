from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REVISION = "ml21"
SOURCE = ROOT / "art_source/weapons/lc01/hunyuan-v1"
WORK = ROOT / "art_source/weapons/lc01/ml21-hunyuan-refine"
RUNTIME = ROOT / f"assets/weapons/lc01/{REVISION}"
REPORT = ROOT / "docs/validation/ml21-hunyuan-refine"
ML06_GLB = ROOT / "assets/weapons/lc01/lc01.glb"
ML06_TEXTURES = ROOT / "assets/weapons/lc01"
BLENDER = "/Applications/Blender.app/Contents/MacOS/Blender"

MAGAZINE_BOX = {"y": [0.155, 0.405], "z_max": -0.006}
# Orange magazine shell between the dark end blocks and above the dark bottom rail (game frame, m).
MAGAZINE_SHELL = {"y": [0.197, 0.392], "z_min": -0.086}
# Decorative engraved text/slash etches to flatten on both sides (game frame, m; |x| side panels).
FLATTEN_BOXES = {
    "receiver_text_plate": {"y": [0.077, 0.130], "z": [0.067, 0.085]},
    "receiver_slash_etch": {"y": [0.000, 0.050], "z": [0.064, 0.080]},
    "shroud_small_etch": {"y": [0.460, 0.522], "z": [0.010, 0.034]},
}
NORMAL_SIZE = 4096
ATLAS_SIZE = 2048
# Projected-normal smoothing on the high mesh; creases sharper than this bake as hard lines.
HIGH_SMOOTH_ANGLE = 35
