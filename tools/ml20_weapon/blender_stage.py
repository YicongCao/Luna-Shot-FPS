"""ML20 Blender stages: registration points, Cycles high-to-low bake and runtime GLB export.

Usage: Blender --background --python-exit-code 1 --python tools/ml20_weapon/blender_stage.py -- points|bake
"""
import json
import math
import sys
import time
from pathlib import Path

import bmesh
import bpy
import numpy as np
from mathutils import Matrix

sys.path.insert(0, str(Path(__file__).resolve().parent))
from paths import ATLAS_SIZE, MAGAZINE_BOX, ML06_GLB, NORMAL_SIZE, RUNTIME, SOURCE, WORK  # noqa: E402

stage = sys.argv[sys.argv.index("--") + 1]
PREPARED = WORK / "01-prepared"
BAKE = WORK / "02-bake"
for folder in (PREPARED, BAKE, RUNTIME):
    folder.mkdir(parents=True, exist_ok=True)


def reset():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def imported(before):
    return [o for o in bpy.context.scene.objects if o not in before and o.type == "MESH"]


def apply_matrix(obj, matrix=None):
    bpy.ops.object.select_all(action="DESELECT")
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    if matrix is not None:
        obj.matrix_world = Matrix(matrix) @ obj.matrix_world
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)


def load_low():
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=str(SOURCE / "uv.fbx"))
    low = imported(before)[0]
    low.name = "ML20_low"
    apply_matrix(low)
    return low


def load_high():
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / "high.glb"))
    high = imported(before)[0]
    high.name = "ML20_high"
    apply_matrix(high)
    return high


def vertices(obj):
    data = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
    obj.data.vertices.foreach_get("co", data)
    return data.reshape(-1, 3)


def uv_seam(edge, uv):
    if len(edge.link_faces) != 2:
        return True
    first, second = edge.link_faces
    for vertex in edge.verts:
        a = next(loop[uv].uv for loop in vertex.link_loops if loop.face == first)
        b = next(loop[uv].uv for loop in vertex.link_loops if loop.face == second)
        if (a - b).length > 1e-5:
            return True
    return False


def rebuild_normals(low):
    """Replace the platform's pillowed custom normals before baking.

    Hard edges only where a >30 degree corner is already a UV seam; face-area weighted normals keep
    broad panels flat and leave the residual bend on narrow chamfers.
    """
    bpy.ops.mesh.customdata_custom_splitnormals_clear()
    bpy.ops.object.shade_smooth()
    mesh = bmesh.new()
    mesh.from_mesh(low.data)
    uv = mesh.loops.layers.uv.active
    hard = 0
    for edge in mesh.edges:
        sharp = uv_seam(edge, uv) and edge.calc_face_angle(math.pi) > math.radians(30)
        edge.smooth = not sharp
        hard += sharp
    mesh.to_mesh(low.data)
    modifier = low.modifiers.new("Area weighted normals", "WEIGHTED_NORMAL")
    modifier.mode = "FACE_AREA"
    modifier.weight = 50
    modifier.keep_sharp = True
    modifier.thresh = 0.01
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    return hard


def export_points():
    reset()
    low = vertices(load_low())
    high = vertices(load_high())[::7]
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(ML06_GLB))
    ml06 = []
    for obj in imported(before):
        apply_matrix(obj)
        ml06.append(vertices(obj))
    np.savez_compressed(PREPARED / "points.npz", low=low, high=high, ml06=np.concatenate(ml06))
    print("ML20_POINTS", len(low), len(high))


def setup_cycles():
    scene = bpy.context.scene
    scene.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    prefs.compute_device_type = "METAL"
    prefs.get_devices()
    for device in prefs.devices:
        device.use = device.type == "METAL"
    scene.cycles.device = "GPU"
    scene.world = bpy.data.worlds.new("BakeWorld")
    scene.world.light_settings.distance = 0.03
    return scene


def bake_image(scene, low, node, name, size, kind, samples, selected):
    image = bpy.data.images.new(name, size, size, alpha=False, float_buffer=True)
    image.colorspace_settings.name = "Non-Color"
    image.generated_color = (0.5, 0.5, 1, 1) if kind == "NORMAL" else (0, 0, 0, 1)
    node.image = image
    settings = scene.render.bake
    settings.use_selected_to_active = selected
    settings.margin = 32 if size >= 4096 else 16
    settings.margin_type = "EXTEND"
    settings.use_clear = True
    scene.cycles.samples = samples
    started = time.time()
    bpy.ops.object.bake(type=kind)
    image.filepath_raw = str(BAKE / f"{name}.exr")
    image.file_format = "OPEN_EXR"
    image.save()
    print("ML20_BAKED", name, size, round(time.time() - started, 1), flush=True)
    return round(time.time() - started, 1)


def separate_magazine(low):
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    bpy.ops.object.mode_set(mode="EDIT")
    mesh = bmesh.from_edit_mesh(low.data)
    count = 0
    for face in mesh.faces:
        inside = all(
            MAGAZINE_BOX["y"][0] <= v.co.y <= MAGAZINE_BOX["y"][1] and v.co.z <= MAGAZINE_BOX["z_max"]
            for v in face.verts
        )
        face.select = inside
        count += inside
    bmesh.update_edit_mesh(low.data)
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    cell = [o for o in bpy.context.selected_objects if o != low][0]
    low.name = low.data.name = "ML20_Body"
    cell.name = cell.data.name = "ML20_Cell"
    return low, cell, count


def bake_and_export():
    alignment = json.loads((PREPARED / "alignment.json").read_text())
    game = np.array(alignment["high_to_game"])
    reset()
    low = load_low()
    apply_matrix(low, game @ np.array(alignment["low_to_high"]))
    hard_edges = rebuild_normals(low)
    modifier = low.modifiers.new("Freeze triangles", "TRIANGULATE")
    if hasattr(modifier, "keep_custom_normals"):
        modifier.keep_custom_normals = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    high = load_high()
    apply_matrix(high, game)
    bpy.ops.object.shade_smooth()

    scene = setup_cycles()
    material = bpy.data.materials.new("ML20_bake")
    material.use_nodes = True
    nodes = material.node_tree.nodes
    node = nodes.new("ShaderNodeTexImage")
    nodes.active = node
    low.data.materials.clear()
    low.data.materials.append(material)
    settings = scene.render.bake
    settings.cage_extrusion = 0.003
    settings.max_ray_distance = 0.009
    settings.normal_space = "TANGENT"

    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    timings = {
        "NormalGL": bake_image(scene, low, node, "NormalGL", NORMAL_SIZE, "NORMAL", 4, True),
        "AO": bake_image(scene, low, node, "AO", ATLAS_SIZE, "AO", 64, True),
    }

    links = material.node_tree.links
    geometry = nodes.new("ShaderNodeNewGeometry")
    emission = nodes.new("ShaderNodeEmission")
    output = nodes["Material Output"]
    links.new(emission.outputs[0], output.inputs["Surface"])
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    for name, socket in (("Position", "Position"), ("SurfaceNormal", "Normal")):
        link = links.new(geometry.outputs[socket], emission.inputs["Color"])
        timings[name] = bake_image(scene, low, node, name, ATLAS_SIZE, "EMIT", 1, False)
        links.remove(link)

    bpy.data.objects.remove(high, do_unlink=True)
    low.data.materials.clear()
    body, cell, cell_faces = separate_magazine(low)
    bpy.ops.wm.save_as_mainfile(filepath=str(PREPARED / "ml20-low-game.blend"))
    bpy.ops.object.select_all(action="DESELECT")
    body.select_set(True)
    cell.select_set(True)
    bpy.ops.export_scene.gltf(
        filepath=str(RUNTIME / "weapon.glb"),
        export_format="GLB",
        use_selection=True,
        export_materials="NONE",
        export_tangents=True,
        export_normals=True,
        export_yup=True,
    )
    report = {
        "renderer": "Blender Cycles Metal GPU, selected-to-active",
        "cage_extrusion_m": settings.cage_extrusion,
        "max_ray_distance_m": settings.max_ray_distance,
        "ao_distance_m": scene.world.light_settings.distance,
        "normal_space": "tangent, OpenGL +Y",
        "low_normals": "platform custom normals cleared; >30 degree UV-seam hard edges; face-area weighted normals",
        "hard_edges": hard_edges,
        "triangles": {o.name: len(o.data.polygons) for o in (body, cell)},
        "cell_faces": cell_faces,
        "seconds": timings,
    }
    (BAKE / "bake-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print("ML20_EXPORTED", json.dumps(report))


if stage == "points":
    export_points()
elif stage == "bake":
    bake_and_export()
else:
    raise SystemExit(f"Unknown stage {stage}")
