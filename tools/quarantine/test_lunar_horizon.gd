extends SceneTree
# Geometry-only: --headless --path . --script res://tools/quarantine/test_lunar_horizon.gd
# Does not instantiate the mission or run native/GPU captures.
var Horizon: Script = preload("res://scripts/quarantine/lunar_horizon.gd")
var ridges: bool = false
var failures: int = 0
var checks: int = 0


func _initialize() -> void:
	call_deferred("run")


func check(id: String, ok: bool) -> void:
	checks += 1
	if not ok:
		failures += 1
	print("LUNAR HORIZON CHECK ", id, " ", ok)


func run() -> void:
	if DisplayServer.get_name() != "headless":
		push_error("This geometry test must be launched with --headless.")
		quit(1)
		return
	ridges = OS.get_environment("TEST_HORIZON_STYLE") == "ridges"
	if ridges:
		Horizon = preload("res://scripts/quarantine/lunar_ridges.gd")
	var started: int = Time.get_ticks_msec()
	var world: Node3D = Node3D.new()
	var terrain: MeshInstance3D = Horizon.build(world)
	check("named_single_mesh_child", world.get_child_count() == 1 and terrain.get_parent() == world and terrain.name == "ProceduralLunarHorizon")
	check("no_collision_or_other_children", terrain.get_child_count() == 0 and world.find_children("*", "CollisionObject3D", true, false).is_empty())
	check("identity_transform", terrain.transform == Transform3D.IDENTITY)
	var mesh: ArrayMesh = terrain.mesh
	check("single_triangle_surface", mesh.get_surface_count() == 1 and mesh.surface_get_primitive_type(0) == Mesh.PRIMITIVE_TRIANGLES)
	var data: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = data[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = data[Mesh.ARRAY_NORMAL]
	var tangents: PackedFloat32Array = data[Mesh.ARRAY_TANGENT]
	var uvs: PackedVector2Array = data[Mesh.ARRAY_TEX_UV]
	var indices: PackedInt32Array = data[Mesh.ARRAY_INDEX]
	var triangle_count: int = indices.size() / 3
	check("triangle_budget_and_expected_coverage", (triangle_count >= 452608 and triangle_count < 700000) if ridges else (triangle_count == 113152 and triangle_count < 160000))
	check("indexed_compact_grid", (vertices.size() >= 227392 if ridges else vertices.size() == 57120) and indices.size() > vertices.size() * 5)
	check("complete_vertex_attributes", normals.size() == vertices.size() and uvs.size() == vertices.size() and tangents.size() == vertices.size() * 4)
	check("grid_at_most_2_5m", Horizon.GRID_STEP <= 2.5 and is_equal_approx(Horizon.CELLS * Horizon.GRID_STEP, Horizon.SPAN))
	var noise: FastNoiseLite = Horizon.create_sampler()
	check("conservative_octave_sampling", noise.frequency * pow(noise.fractal_lacunarity, noise.fractal_octaves - 1) * Horizon.GRID_STEP <= 0.1)
	check("flat_facility_apron", Horizon.sample_height(0, 0) == -2.0 and Horizon.sample_height(40, 40) == -2.0 and Horizon.sample_height(-40, -40) == -2.0)
	var finite: bool = true
	var smooth_normals: bool = true
	var gradient_match: bool = true
	var tangent_frames: bool = true
	var heights_match: bool = true
	var uv_match: bool = true
	var unique: Dictionary = {}
	for i in vertices.size():
		var p: Vector3 = vertices[i]
		var n: Vector3 = normals[i]
		finite = finite and p.is_finite() and n.is_finite() and p.y >= -47.0 and p.y <= 57.0
		smooth_normals = smooth_normals and absf(n.length() - 1.0) < 0.001 and n.y > 0.0
		var t: Vector3 = Vector3(tangents[i * 4], tangents[i * 4 + 1], tangents[i * 4 + 2])
		tangent_frames = tangent_frames and t.is_finite() and absf(t.length() - 1.0) < 0.001 and absf(t.dot(n)) < 0.001 and tangents[i * 4 + 3] == -1.0 and (n.cross(t) * tangents[i * 4 + 3]).z > 0.0
		heights_match = heights_match and absf(p.y - Horizon.sample_height(p.x, p.z, noise)) < 0.00001
		uv_match = uv_match and uvs[i].distance_to(Vector2(p.x, p.z) / 8.0) < 0.00001
		unique[Vector2(p.x, p.z)] = true
		if i % 113 == 0:
			var step: float = Horizon.NORMAL_STEP if ridges else Horizon.GRID_STEP
			var dx: float = (Horizon.sample_height(p.x + step, p.z, noise) - Horizon.sample_height(p.x - step, p.z, noise)) / (2.0 * step)
			var dz: float = (Horizon.sample_height(p.x, p.z + step, noise) - Horizon.sample_height(p.x, p.z - step, noise)) / (2.0 * step)
			gradient_match = gradient_match and n.dot(Vector3(-dx, 1.0, -dz).normalized()) > 0.99999
	check("finite_bounded_vertices", finite)
	check("unit_upward_normals", smooth_normals)
	check("normals_match_cached_height_gradient", gradient_match)
	check("orthonormal_uv_tangent_frames", tangent_frames)
	check("mesh_matches_public_height_sampler", heights_match)
	check("baseline_8m_texture_scale", uv_match)
	check("shared_vertices_without_seam_duplicates", unique.size() == vertices.size())

	var valid_indices: bool = true
	for index in indices:
		valid_indices = valid_indices and index >= 0 and index < vertices.size()
	check("indices_in_range", valid_indices)
	if not valid_indices:
		world.free()
		quit(1)
		return
	var winding: bool = true
	var hole_clear: bool = true
	var spacing: bool = true
	var used: Dictionary = {}
	var edges: Dictionary = {}
	var min_normal_dot: float = 1.0
	var worst_face: Dictionary = {}
	var angle_failures: int = 0
	var projected_area: float = 0.0
	for i in range(0, indices.size(), 3):
		var a: Vector3 = vertices[indices[i]]
		var b: Vector3 = vertices[indices[i + 1]]
		var c: Vector3 = vertices[indices[i + 2]]
		var face: Vector3 = (c - a).cross(b - a)
		projected_area += face.y * .5
		winding = winding and face.y > 0.0 and face.length_squared() > 0.000000000001
		var min_x: float = minf(a.x, minf(b.x, c.x))
		var max_x: float = maxf(a.x, maxf(b.x, c.x))
		var min_z: float = minf(a.z, minf(b.z, c.z))
		var max_z: float = maxf(a.z, maxf(b.z, c.z))
		# No triangle's projected interior can enter the whole 80x80m opening.
		hole_clear = hole_clear and (max_x <= -40.0 or min_x >= 40.0 or max_z <= -40.0 or min_z >= 40.0)
		spacing = spacing and max_x - min_x <= Horizon.GRID_STEP and max_z - min_z <= Horizon.GRID_STEP
		for j in 3:
			var start: int = indices[i + j]
			var end: int = indices[i + (j + 1) % 3]
			used[start] = true
			var agreement: float = face.normalized().dot(normals[start])
			if agreement < .98: angle_failures += 1
			if agreement < min_normal_dot:
				min_normal_dot = agreement
				worst_face = {"a":a,"b":b,"c":c,"normal":normals[start],"face":face.normalized()}
			var edge: Vector2i = Vector2i(mini(start, end), maxi(start, end))
			edges[edge] = edges.get(edge, 0) + 1
	var manifold: bool = true
	var boundary_count: int = 0
	var boundary_location: bool = true
	for edge: Vector2i in edges:
		manifold = manifold and edges[edge] <= 2
		if edges[edge] == 1:
			boundary_count += 1
			var a: Vector3 = vertices[edge.x]
			var b: Vector3 = vertices[edge.y]
			var outer: bool = (absf(a.x) == 300.0 and a.x == b.x) or (absf(a.z) == 300.0 and a.z == b.z)
			var inner: bool = (absf(a.x) == 40.0 and a.x == b.x and maxf(absf(a.z), absf(b.z)) <= 40.0) or (absf(a.z) == 40.0 and a.z == b.z and maxf(absf(a.x), absf(b.x)) <= 40.0)
			boundary_location = boundary_location and (outer or inner)
	check("clockwise_nondegenerate_upward_faces", winding)
	print("NORMAL DIAGNOSTIC corners_below_0.98=",angle_failures," worst=",worst_face)
	check("face_and_smooth_normals_agree", min_normal_dot > 0.98)
	check("facility_and_clearance_hole_empty", hole_clear)
	check("projected_area_conserved",absf(projected_area-(600.0*600.0-80.0*80.0))<.001)
	check("every_triangle_uses_dense_grid", spacing)
	check("all_vertices_referenced", used.size() == vertices.size())
	check("manifold_no_internal_cracks", manifold and boundary_location and (boundary_count >= 2176 if ridges else boundary_count == 1088))
	var bounds: AABB = mesh.get_aabb()
	check("original_600m_span", is_equal_approx(bounds.position.x, -300.0) and is_equal_approx(bounds.position.z, -300.0) and is_equal_approx(bounds.size.x, 600.0) and is_equal_approx(bounds.size.z, 600.0))
	var repeat: Array = Horizon.build_mesh().surface_get_arrays(0)
	var deterministic: bool = true
	for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_TANGENT, Mesh.ARRAY_TEX_UV, Mesh.ARRAY_INDEX]:
		deterministic = deterministic and data[attribute] == repeat[attribute]
	check("repeat_build_identical_arrays", deterministic)
	check("independent_sampler_determinism", Horizon.sample_height(137.25, -210.75) == Horizon.sample_height(137.25, -210.75, noise))
	var material: StandardMaterial3D = mesh.surface_get_material(0)
	check("reuse_existing_regolith_textures", material.albedo_texture != null and material.normal_texture != null and material.albedo_texture.resource_path == Horizon.BASE_COLOR_PATH and material.normal_texture.resource_path == Horizon.NORMAL_PATH)
	check("baseline_material_settings", material.albedo_color == Color(0.34, 0.38, 0.42) and is_equal_approx(material.roughness, 0.96) and material.normal_enabled and is_equal_approx(material.normal_scale, 0.55) and material.cull_mode == BaseMaterial3D.CULL_BACK and material.texture_filter == BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC)
	if ridges:
		var cached: MeshInstance3D = Horizon.build(world)
		check("runtime_reuses_generated_mesh", cached.mesh == terrain.mesh)
	world.free()
	print("LUNAR HORIZON RESULT checks=", checks, " failures=", failures, " vertices=", vertices.size(), " triangles=", triangle_count, " min_face_normal_dot=", min_normal_dot, " bounds=", bounds, " elapsed_ms=", Time.get_ticks_msec() - started)
	print("Geometry-only headless result; native left/right culling, horizon silhouette, warm atmosphere and GPU cost remain unverified.")
	quit(0 if failures == 0 else 1)
