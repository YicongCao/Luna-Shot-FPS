"""Hunyuan rifle Blender stages: registration points, Cycles high-to-low bake and runtime GLB export.

Usage: Blender --background --python-exit-code 1 --python tools/hunyuan_weapon/blender_stage.py -- points|bake
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
from paths import ATLAS_SIZE, FLATTEN_BOXES, HIGH_SMOOTH_ANGLE, MAGAZINE_BOX, ML06_GLB, NORMAL_SIZE, REVISION, RUNTIME, SOURCE, WORK  # noqa: E402

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
    low.name = f"{REVISION.upper()}_low"
    apply_matrix(low)
    return low


def load_high():
    before = set(bpy.context.scene.objects)
    bpy.ops.import_scene.gltf(filepath=str(SOURCE / "high.glb"))
    high = imported(before)[0]
    high.name = f"{REVISION.upper()}_high"
    apply_matrix(high)
    return high


def vertices(obj):
    data = np.empty(len(obj.data.vertices) * 3, dtype=np.float32)
    obj.data.vertices.foreach_get("co", data)
    return data.reshape(-1, 3)


def panel_planes(high):
    """Side-panel plane |x| = a + b*y + c*z around each etch box, least-squares fit to the outer ring.

    A tilted fit (not constant |x|) keeps the filled etch coplanar with the surrounding panel shading.
    """
    points = vertices(high)
    planes = {}
    for name, box in FLATTEN_BOXES.items():
        for side in (-1, 1):
            near = (points[:, 0] * side > 0.02)
            y, z = points[:, 1], points[:, 2]
            outer = near & (y > box["y"][0] - 0.006) & (y < box["y"][1] + 0.006) & (z > box["z"][0] - 0.005) & (z < box["z"][1] + 0.005)
            inner = (y > box["y"][0]) & (y < box["y"][1]) & (z > box["z"][0]) & (z < box["z"][1])
            ring = points[outer & ~inner]
            depth = np.abs(ring[:, 0])
            surface = ring[depth > np.median(depth[depth > depth.max() - 0.006]) - 0.0015]
            design = np.c_[np.ones(len(surface)), surface[:, 1], surface[:, 2]]
            coefficients = np.linalg.lstsq(design, np.abs(surface[:, 0]), rcond=None)[0]
            planes[f"{name}:{side}"] = [float(c) for c in coefficients]
    return planes


def plane_depth(plane, points):
    return plane[0] + plane[1] * points[:, 1] + plane[2] * points[:, 2]


def flatten_etches(obj, planes):
    """Project recessed (and slightly raised) etch vertices onto the panel plane; returns moved count.

    The plane is re-offset by the median residual of this mesh's own surrounding ring, so the sparse
    low mesh fills flush with its own panel instead of the high surface a fraction of a mm away.
    """
    points = vertices(obj)
    moved = 0
    for name, box in FLATTEN_BOXES.items():
        for side in (-1, 1):
            plane = plane_depth(planes[f"{name}:{side}"], points)
            x = points[:, 0] * side
            y, z = points[:, 1], points[:, 2]
            inner = (y > box["y"][0]) & (y < box["y"][1]) & (z > box["z"][0]) & (z < box["z"][1])
            outer = (y > box["y"][0] - 0.006) & (y < box["y"][1] + 0.006) & (z > box["z"][0] - 0.005) & (z < box["z"][1] + 0.005)
            residual = (x - plane)[outer & ~inner & (np.abs(x - plane) < 0.0015)]
            if len(residual):
                plane = plane + float(np.median(residual))
            mask = inner & (x > plane - 0.006) & (x < plane + 0.002)
            points[mask, 0] = side * plane[mask]
            moved += int(mask.sum())
    obj.data.vertices.foreach_set("co", points.ravel())
    obj.data.update()
    return moved, weld_flattened(obj)


def weld_flattened(obj):
    """Merge the floor/rim vertices that now coincide and drop the collapsed etch walls.

    Without this, zero-area walls keep the filled floor a hard-edged, folded island that shades as a
    visible patch after baking.
    """
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    region = []
    for vertex in mesh.verts:
        x, y, z = vertex.co
        for box in FLATTEN_BOXES.values():
            if abs(x) > 0.02 and box["y"][0] - 0.001 < y < box["y"][1] + 0.001 and box["z"][0] - 0.001 < z < box["z"][1] + 0.001:
                region.append(vertex)
                break
    before = len(mesh.verts)
    bmesh.ops.remove_doubles(mesh, verts=region, dist=0.00025)
    region_set = {v for v in region if v.is_valid}
    edges = [e for e in mesh.edges if e.verts[0] in region_set or e.verts[1] in region_set]
    bmesh.ops.dissolve_degenerate(mesh, edges=edges, dist=0.00002)
    merged = before - len(mesh.verts)
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    return merged


def in_flatten_region(co, margin):
    x, y, z = co
    return abs(x) > 0.02 and any(
        box["y"][0] - margin < y < box["y"][1] + margin and box["z"][0] - margin < z < box["z"][1] + margin
        for box in FLATTEN_BOXES.values()
    )


def drop_folded(obj):
    """Delete folded (inward-facing) or near-zero-area slivers left inside the flattened etches."""
    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    folded = [
        f for f in mesh.faces
        if all(in_flatten_region(v.co, 0.0005) for v in f.verts)
        and (f.normal.x * math.copysign(1, f.calc_center_median().x) < 0.5 or f.calc_area() < 2e-8)
    ]
    bmesh.ops.delete(mesh, geom=folded, context="FACES")
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    return len(folded)


def drop_stacked(obj):
    """Delete flattened faces fully covered by a larger coplanar face (former raised strokes now
    lying on the recess floor); the stacked layers z-fight as a dark patch otherwise."""
    from mathutils.geometry import intersect_point_tri_2d
    from mathutils import Vector

    mesh = bmesh.new()
    mesh.from_mesh(obj.data)
    mesh.normal_update()
    region = [
        f for f in mesh.faces
        if all(in_flatten_region(v.co, 0.0005) for v in f.verts)
        and f.normal.x * math.copysign(1, f.calc_center_median().x) > 0.95
    ]
    triangles = {f: [] for f in region}
    for loops in mesh.calc_loop_triangles():
        if loops[0].face in triangles:
            triangles[loops[0].face].append([Vector((l.vert.co.y, l.vert.co.z)) for l in loops])
    area = {f: f.calc_area() for f in region}
    stacked = []
    for face in region:
        side = face.calc_center_median().x > 0
        center = face.calc_center_median()
        samples = [Vector((center.y, center.z))] + [
            Vector((center.y + 0.7 * (v.co.y - center.y), center.z + 0.7 * (v.co.z - center.z))) for v in face.verts
        ]
        covers = [
            g for g in region
            if g is not face and area[g] > area[face] and (g.calc_center_median().x > 0) == side
        ]
        if all(any(intersect_point_tri_2d(p, *t) for g in covers for t in triangles[g]) for p in samples):
            stacked.append(face)
    bmesh.ops.delete(mesh, geom=stacked, context="FACES")
    bmesh.ops.delete(mesh, geom=[v for v in mesh.verts if not v.link_faces], context="VERTS")
    mesh.to_mesh(obj.data)
    mesh.free()
    obj.data.update()
    return len(stacked)


def flatten_shading(low):
    """Give the filled etch islands and the surrounding side panel one flat shading normal.

    The area-weighted pass tilts the panel corner normals; the filled letter islands stay exactly
    flat, so they read as patches. Sharing the panel-plane normal in the region removes the step.
    """
    mesh = low.data
    normals = [list(n.vector) for n in mesh.corner_normals]
    changed = 0
    for face in mesh.polygons:
        side = math.copysign(1, face.center.x)
        if face.normal.x * side < 0.95 or not in_flatten_region(face.center, 0.004):
            continue
        for loop in face.loop_indices:
            if in_flatten_region(mesh.vertices[mesh.loops[loop].vertex_index].co, 0.004):
                normals[loop] = list(face.normal)
                changed += 1
    mesh.normals_split_custom_set(normals)
    mesh.update()
    return changed


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
    print(f"{REVISION.upper()}_POINTS", len(low), len(high))


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
    print(f"{REVISION.upper()}_BAKED", name, size, round(time.time() - started, 1), flush=True)
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
    low.name = low.data.name = f"{REVISION.upper()}_Body"
    cell.name = cell.data.name = f"{REVISION.upper()}_Cell"
    return low, cell, count


def bake_and_export():
    alignment = json.loads((PREPARED / "alignment.json").read_text())
    game = np.array(alignment["high_to_game"])
    reset()
    low = load_low()
    apply_matrix(low, game @ np.array(alignment["low_to_high"]))
    high = load_high()
    apply_matrix(high, game)
    planes = panel_planes(high)
    flattened = {"high": flatten_etches(high, planes), "low": flatten_etches(low, planes)}
    folded = {"high": drop_folded(high), "low": drop_folded(low)}
    stacked_low = drop_stacked(low)
    bpy.ops.object.select_all(action="DESELECT")
    low.select_set(True)
    bpy.context.view_layer.objects.active = low
    hard_edges = rebuild_normals(low)
    flat_loops = flatten_shading(low)
    modifier = low.modifiers.new("Freeze triangles", "TRIANGULATE")
    if hasattr(modifier, "keep_custom_normals"):
        modifier.keep_custom_normals = True
    bpy.ops.object.modifier_apply(modifier=modifier.name)
    bpy.ops.object.select_all(action="DESELECT")
    high.select_set(True)
    bpy.context.view_layer.objects.active = high
    # Angle-limited smoothing keeps real creases hard in the projected normals (ML21 line clarity).
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(HIGH_SMOOTH_ANGLE))

    scene = setup_cycles()
    material = bpy.data.materials.new("HY_bake")
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
    bpy.ops.wm.save_as_mainfile(filepath=str(PREPARED / f"{REVISION}-low-game.blend"))
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
        "high_smoothing_angle_deg": HIGH_SMOOTH_ANGLE,
        "hard_edges": hard_edges,
        "flattened_vertices": flattened,
        "folded_faces_removed": folded,
        "stacked_low_faces_removed": stacked_low,
        "flat_shading_loops": flat_loops,
        "etch_panel_planes_m": planes,
        "triangles": {o.name: len(o.data.polygons) for o in (body, cell)},
        "cell_faces": cell_faces,
        "seconds": timings,
    }
    (BAKE / "bake-report.json").write_text(json.dumps(report, indent=2) + "\n")
    print(f"{REVISION.upper()}_EXPORTED", json.dumps(report))


if stage == "points":
    export_points()
elif stage == "bake":
    bake_and_export()
else:
    raise SystemExit(f"Unknown stage {stage}")
