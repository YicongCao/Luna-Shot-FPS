"""ML20 material IDs and PBR maps from actual high-to-low bakes.

Material zones are transferred from the user-selected ML06 surface by nearest-surface voting in the
shared game frame, quantized to the concept palette, then cleaned in UV space. No paid generation.
"""
import json
import struct

import numpy as np
import OpenEXR
from PIL import Image
from scipy import ndimage
from scipy.sparse import coo_matrix
from scipy.sparse.csgraph import connected_components
from scipy.spatial import cKDTree

from paths import ATLAS_SIZE, ML06_GLB, ML06_TEXTURES, NORMAL_SIZE, RUNTIME, WORK

BAKE = WORK / "02-bake"
MATERIAL = WORK / "03-material"
MATERIAL.mkdir(parents=True, exist_ok=True)
rng = np.random.default_rng(20261117)

# name, sRGB base, roughness, metallic. Palette follows the two supplied concept views.
ZONES = [
    ("ceramic_white", (214, 209, 199), 0.40, 0.0),
    ("charcoal_frame", (74, 79, 86), 0.50, 0.0),
    ("safety_orange", (226, 94, 36), 0.43, 0.0),
    ("black_polymer", (33, 34, 37), 0.72, 0.0),
    ("coil_gunmetal", (132, 137, 143), 0.36, 0.85),
    ("energy_teal", (40, 206, 214), 0.25, 0.0),
]
ML06_COLORS = np.array([(207, 203, 193), (96, 110, 124), (230, 94, 35), (31, 36, 43), (35, 195, 220), (149, 149, 149)], float)
ML06_TO_ZONE = np.array([0, 1, 2, 3, 5, -1])


def read_exr(name):
    with OpenEXR.File(str(BAKE / f"{name}.exr")) as handle:
        return np.array(handle.channels()["RGB"].pixels, dtype=np.float32)


def compact_exr(name, pixels):
    header = {"compression": OpenEXR.ZIP_COMPRESSION, "type": OpenEXR.scanlineimage}
    OpenEXR.File(header, {"RGB": pixels.astype(np.float16)}).write(str(BAKE / f"{name}.exr"))


def glb(path):
    blob = path.read_bytes()
    length = struct.unpack_from("<I", blob, 12)[0]
    gltf = json.loads(blob[20 : 20 + length])
    offset = 20 + length
    binary = blob[offset + 8 : offset + 8 + struct.unpack_from("<I", blob, offset)[0]]

    def accessor(index):
        info = gltf["accessors"][index]
        view = gltf["bufferViews"][info["bufferView"]]
        width = {"SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4}[info["type"]]
        dtype = {5126: np.float32, 5125: np.uint32, 5123: np.uint16}[info["componentType"]]
        data = np.frombuffer(binary, dtype, info["count"] * width, view.get("byteOffset", 0) + info.get("byteOffset", 0))
        return data.reshape(-1, width) if width > 1 else data

    parts = []
    for mesh in gltf["meshes"]:
        for primitive in mesh["primitives"]:
            attributes = primitive["attributes"]
            parts.append(
                (
                    accessor(attributes["POSITION"]).astype(np.float64),
                    accessor(attributes["TEXCOORD_0"]).astype(np.float64),
                    accessor(primitive["indices"]).reshape(-1, 3).astype(np.int64),
                )
            )
    return parts


def to_blender(points):
    return np.c_[points[:, 0], -points[:, 2], points[:, 1]]


def sample_image(image, uv):
    height, width = image.shape[:2]
    x = np.clip((uv[:, 0] % 1) * width, 0, width - 1).astype(int)
    y = np.clip((uv[:, 1] % 1) * height, 0, height - 1).astype(int)
    return image[y, x]


def ml06_samples(count=3_000_000):
    base = np.asarray(Image.open(ML06_TEXTURES / "BaseColor.png").convert("RGB"), float)
    emission = np.asarray(Image.open(ML06_TEXTURES / "Emission.png").convert("RGB"), float)
    points, uvs = [], []
    meshes = glb(ML06_GLB)
    areas = [np.linalg.norm(np.cross(p[f[:, 1]] - p[f[:, 0]], p[f[:, 2]] - p[f[:, 0]]), axis=1) / 2 for p, _, f in meshes]
    total = sum(a.sum() for a in areas)
    for (position, uv, faces), area in zip(meshes, areas):
        per = rng.poisson(area / total * count)
        tri = np.repeat(np.arange(len(faces)), per)
        a, b = rng.random((2, len(tri)))
        flip = a + b > 1
        a[flip], b[flip] = 1 - a[flip], 1 - b[flip]
        corners = faces[tri]
        weights = np.c_[1 - a - b, a, b][:, :, None]
        points.append((position[corners] * weights).sum(1))
        uvs.append((uv[corners] * weights).sum(1))
    points, uvs = to_blender(np.concatenate(points)), np.concatenate(uvs)
    color = sample_image(base, uvs)
    zone = ML06_TO_ZONE[np.argmin(((color[:, None] - ML06_COLORS[None]) ** 2).sum(-1), 1)]
    glowing = sample_image(emission, uvs).max(1) > 40
    zone[glowing] = 5
    keep = zone >= 0
    return points[keep], zone[keep]


def rasterize(size):
    """Triangle coverage and UV island ids from the exported runtime GLB."""
    island_map = np.full((size, size), -1, np.int32)
    next_id = 0
    for _, uv, faces in glb(RUNTIME / "weapon.glb"):
        rows = np.r_[faces[:, 0], faces[:, 1], faces[:, 2]]
        cols = np.r_[faces[:, 1], faces[:, 2], faces[:, 0]]
        _, labels = connected_components(coo_matrix((np.ones(len(rows)), (rows, cols)), shape=(len(uv), len(uv))), directed=False)
        pixels = uv * size - 0.5
        for face, label in zip(faces, labels[faces[:, 0]]):
            tri = pixels[face]
            x0, y0 = np.floor(tri.min(0)).astype(int)
            x1, y1 = np.ceil(tri.max(0)).astype(int)
            x0, y0, x1, y1 = max(x0, 0), max(y0, 0), min(x1, size - 1), min(y1, size - 1)
            if x1 < x0 or y1 < y0:
                continue
            gx, gy = np.meshgrid(np.arange(x0, x1 + 1), np.arange(y0, y1 + 1))
            (ax, ay), (bx, by), (cx, cy) = tri
            det = (by - cy) * (ax - cx) + (cx - bx) * (ay - cy)
            if abs(det) < 1e-12:
                continue
            l1 = ((by - cy) * (gx - cx) + (cx - bx) * (gy - cy)) / det
            l2 = ((cy - ay) * (gx - cx) + (ax - cx) * (gy - cy)) / det
            inside = (l1 >= -0.02) & (l2 >= -0.02) & (1 - l1 - l2 >= -0.02)
            island_map[gy[inside], gx[inside]] = next_id + label
        next_id += labels.max() + 1
    return island_map


def value_noise(position, cell, seed):
    grid = np.random.default_rng(seed).random((64, 64, 64))
    scaled = position / cell
    base = np.floor(scaled).astype(int)
    frac = scaled - base
    frac = frac * frac * (3 - 2 * frac)
    result = 0
    for dx in (0, 1):
        for dy in (0, 1):
            for dz in (0, 1):
                weight = (frac[..., 0] if dx else 1 - frac[..., 0]) * (frac[..., 1] if dy else 1 - frac[..., 1]) * (frac[..., 2] if dz else 1 - frac[..., 2])
                result = result + weight * grid[(base[..., 0] + dx) % 64, (base[..., 1] + dy) % 64, (base[..., 2] + dz) % 64]
    return result


def smoothstep(value, low, high):
    t = np.clip((value - low) / (high - low), 0, 1)
    return t * t * (3 - 2 * t)


def srgb_to_linear(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def linear_to_srgb(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def save(name, pixels, folder=RUNTIME):
    Image.fromarray(np.clip(np.rint(pixels * 255), 0, 255).astype(np.uint8)).save(folder / f"{name}.png", optimize=True)


position = read_exr("Position")
surface_normal = read_exr("SurfaceNormal")
ao_raw = read_exr("AO")[..., 0]
normal = read_exr("NormalGL")

islands = rasterize(ATLAS_SIZE)
covered = islands >= 0

sample_points, sample_zone = ml06_samples()
tree = cKDTree(sample_points)
query = position[covered]
distance, index = tree.query(query, k=12)
votes = np.zeros((len(query), len(ZONES)))
weight = 1 / (distance + 0.0015)
for k in range(index.shape[1]):
    np.add.at(votes, (np.arange(len(query)), sample_zone[index[:, k]]), weight[:, k])
zone = np.full(covered.shape, 0, np.int32)
zone[covered] = votes.argmax(1)
transfer_distance = np.zeros(covered.shape, np.float32)
transfer_distance[covered] = distance[:, 0]

# The coil stack is a separate ML20 concept read: gunmetal discs with thin teal rims.
radial = np.hypot(position[..., 0], position[..., 2] - 0.055)
coil = covered & (radial < 0.043) & (position[..., 1] > 0.285) & (position[..., 1] < 0.525)
zone[coil & np.isin(zone, [1, 3])] = 4
zone[~coil & (zone == 5)] = 1


def box(y0, y1, z0, z1, x_max=1.0):
    return covered & (position[..., 1] > y0) & (position[..., 1] < y1) & (position[..., 2] > z0) & (position[..., 2] < z1) & (np.abs(position[..., 0]) < x_max)


# Concept corrections to the ML06 transfer: no receiver hazard decal, black only on the grip,
# charcoal stock/butt hardware, orange trigger blade.
hazard_decal = box(0.12, 0.255, 0.072, 0.108) & np.isin(zone, [2, 3])
zone[hazard_decal] = 0
grip = box(-0.07, 0.14, -0.2, 0.005, 0.035)
zone[(zone == 3) & ~grip] = 1
trigger = box(0.05, 0.13, -0.035, 0.05, 0.012) & np.isin(zone, [1, 3])
zone[trigger] = 2

one_hot = np.stack([(zone == z) & covered for z in range(len(ZONES))]).astype(np.float32)
filtered = np.stack([ndimage.uniform_filter(layer, 5) for layer in one_hot])
zone = np.where(covered, filtered.argmax(0), zone)

# Signed curvature from the actual baked tangent-space normal (OpenGL: +V is image up).
nx = ndimage.gaussian_filter(normal[..., 0] * 2 - 1, 1.4)
ny = ndimage.gaussian_filter(normal[..., 1] * 2 - 1, 1.4)
curvature_4k = np.gradient(nx, axis=1) - np.gradient(ny, axis=0)
factor = NORMAL_SIZE // ATLAS_SIZE
curvature = curvature_4k.reshape(ATLAS_SIZE, factor, ATLAS_SIZE, factor).mean((1, 3)) * NORMAL_SIZE / 1024
inner = ndimage.binary_erosion(covered, iterations=2)
curvature = np.where(inner, curvature, 0)
convex = smoothstep(curvature, 0.10, 0.45)
concave = smoothstep(-curvature, 0.10, 0.55)

ao = np.where(covered, np.clip(ao_raw, 0, 1), 1)
ao = 0.30 + 0.70 * ao ** 0.8
broad = value_noise(position, 0.035, 11)
fine = value_noise(position, 0.004, 12)
speck = value_noise(position, 0.0012, 13)

palette = np.array([srgb_to_linear(np.array(z[1]) / 255) for z in ZONES])
rough_table = np.array([z[2] for z in ZONES])
metal_table = np.array([z[3] for z in ZONES])
base = palette[zone] * (0.965 + 0.07 * broad)[..., None]
rough = rough_table[zone] + 0.06 * (fine - 0.5)
metal = metal_table[zone].copy()

painted = np.isin(zone, [0, 1, 2])
chip = painted & (convex * smoothstep(fine * 0.6 + speck * 0.4, 0.62, 0.76) > 0.55)
scuff = painted & ~chip & (convex > 0.3)
bare = srgb_to_linear(np.array([152, 154, 156]) / 255)
base = np.where(scuff[..., None], base * (1 - 0.06 * convex[..., None]), base)
base = np.where(chip[..., None], bare, base)
metal = np.where(chip, 0.9, metal)
rough = np.where(chip, 0.30, rough - 0.05 * scuff)
grime = np.clip((1 - ao) * 1.2 + concave * 0.5, 0, 1) * smoothstep(broad, 0.25, 0.75)
grime *= np.where(surface_normal[..., 2] > 0.4, 1.0, 0.65)
base *= 1 - 0.16 * grime[..., None]
rough = np.clip(rough + 0.12 * grime, 0.08, 0.95)

emission = np.zeros_like(base)
glow = zone == 5
emission[glow] = srgb_to_linear(np.array([40, 225, 255]) / 255)

edge_fill = ~covered
if edge_fill.any():
    _, (iy, ix) = ndimage.distance_transform_edt(edge_fill, return_indices=True)
    for array in (base, emission):
        array[edge_fill] = array[iy[edge_fill], ix[edge_fill]]
    for array in (rough, metal, ao):
        array[edge_fill] = array[iy[edge_fill], ix[edge_fill]]

save("BaseColor", linear_to_srgb(base))
save("ORM", np.dstack([ao, rough, metal]))
save("Emission", linear_to_srgb(emission))
length = np.linalg.norm(normal * 2 - 1, axis=-1, keepdims=True)
normal_unit = np.where(length > 1e-4, (normal * 2 - 1) / np.maximum(length, 1e-4), [0, 0, 1])
save("NormalGL", normal_unit * 0.5 + 0.5 + rng.uniform(-0.5, 0.5, normal.shape) / 255)

zone_colors = np.array([z[1] for z in ZONES], float) / 255
save("MaterialID", np.where(covered[..., None], zone_colors[zone], 0), MATERIAL)
save("Curvature", np.clip(curvature * 0.5 + 0.5, 0, 1), MATERIAL)
save("Wear", np.dstack([chip, scuff, grime]).astype(float), MATERIAL)
save("TransferDistance", np.clip(transfer_distance / 0.01, 0, 1), MATERIAL)
for name, pixels in (("Position", position), ("SurfaceNormal", surface_normal), ("AO", read_exr("AO")), ("NormalGL", normal)):
    compact_exr(name, pixels)

report = {
    "source": "Cycles bakes in 02-bake; zones voted from ML06 nearest surface samples in game frame",
    "zones": {name: float(((zone == i) & covered).sum() / covered.sum()) for i, (name, *_rest) in enumerate(ZONES)},
    "uv_coverage": float(covered.mean()),
    "uv_islands": int(islands.max() + 1),
    "transfer_distance_mm": {
        "p50": float(np.percentile(transfer_distance[covered], 50) * 1000),
        "p95": float(np.percentile(transfer_distance[covered], 95) * 1000),
        "over_6mm_fraction": float((transfer_distance[covered] > 0.006).mean()),
    },
    "wear_fraction": {"chip": float(chip[covered].mean()), "scuff": float(scuff[covered].mean())},
    "concept_overrides_texels": {
        "receiver_hazard_decal_removed": int(hazard_decal.sum()),
        "trigger_orange": int(trigger.sum()),
    },
    "sizes": {"NormalGL": NORMAL_SIZE, "BaseColor": ATLAS_SIZE, "ORM": ATLAS_SIZE, "Emission": ATLAS_SIZE},
    "orm": "R ambient occlusion (0.30 floor), G roughness, B metallic",
}
(MATERIAL / "material-report.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps(report, indent=2))
