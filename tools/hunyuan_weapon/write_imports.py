"""Godot import contracts for Hunyuan rifle runtime resources: VRAM compression, mipmaps, normal-map mode."""
from paths import REVISION, RUNTIME

TEXTURE = """[remap]

importer="texture"
type="CompressedTexture2D"

[deps]

source_file="res://assets/weapons/lc01/{revision}/{name}.png"

[params]

compress/mode=2
compress/high_quality={high_quality}
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map={normal}
compress/channel_pack=0
mipmaps/generate=true
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=0
"""

SCENE = """[remap]

importer="scene"
importer_version=1
type="PackedScene"

[deps]

source_file="res://assets/weapons/lc01/{revision}/weapon.glb"

[params]

nodes/apply_root_scale=true
nodes/root_scale=1.0
meshes/ensure_tangents=true
meshes/generate_lods=false
meshes/create_shadow_meshes=true
meshes/light_baking=1
meshes/force_disable_compression=true
materials/extract=0
gltf/naming_version=2
gltf/embedded_image_handling=1
"""

for name in ("BaseColor", "ORM", "Emission", "NormalGL"):
    path = RUNTIME / f"{name}.png.import"
    if not path.exists():
        path.write_text(TEXTURE.format(revision=REVISION, name=name, high_quality="true", normal=1 if name == "NormalGL" else 0))
if not (RUNTIME / "weapon.glb.import").exists():
    (RUNTIME / "weapon.glb.import").write_text(SCENE.format(revision=REVISION))
print(f"{REVISION.upper()}_IMPORT_CONTRACTS", sorted(p.name for p in RUNTIME.glob("*.import")))
